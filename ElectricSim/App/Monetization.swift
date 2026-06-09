//
//  Monetization.swift
//  ElectricSim
//
//  მონეტიზაცია: freemium მოდელი.
//    • უფასო: Phase 1–2 (გაკვეთილები + დეფექტის ძებნა) + სარეკლამო ბანერი.
//    • Pro (ერთჯერადი შესყიდვა, StoreKit 2): Phase 3 (3 ფაზა + მოტორი) + რეკლამის გარეშე.
//
//  რეკლამა აბსტრაჰირებულია `AdManager`-ით — ამჟამად „house ads" (gadget.ge /
//  Tsili.Ge), მაგრამ ადვილად ჩანაცვლებადია AdMob-ით (იხ. docs/PUBLISHING.md).
//

import Foundation
import StoreKit

// MARK: - EntitlementStore (StoreKit 2)

@MainActor
final class EntitlementStore: ObservableObject {
    /// Pro-განბლოკვის პროდუქტის იდენტიფიკატორი (App Store Connect-ში იგივე უნდა იყოს).
    static let proProductID = "pro_unlock"

    @Published private(set) var proProduct: Product?
    @Published private(set) var isPro: Bool
    @Published private(set) var purchaseInFlight = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let proKey = "entitlement.pro.v1"        // რეალური (StoreKit) entitlement-ის ქეში
    private let demoKey = "entitlement.demoPro.v1"   // QA/დემო override (Release-ზეც)

    /// რეალური StoreKit entitlement (override-ის გარეშე).
    private var realPro = false

    init() {
        // ლოკალური ქეში — ოფლაინ გამოცდილებისთვის; დადასტურდება StoreKit-ით.
        realPro = UserDefaults.standard.bool(forKey: proKey)
        isPro = realPro || UserDefaults.standard.bool(forKey: demoKey)
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            lastError = "პროდუქტების ჩატვირთვა ვერ მოხერხდა: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        setPro(owned)
    }

    func purchasePro() async {
        if proProduct == nil { await loadProducts() }
        guard let product = proProduct else {
            lastError = "პროდუქტი მიუწვდომელია. სცადე მოგვიანებით."
            return
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    setPro(true)
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "შესყიდვა ვერ შესრულდა: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            lastError = "შესყიდვების აღდგენა ვერ მოხერხდა: \(error.localizedDescription)"
        }
    }

    /// ფასი ჩვენებისთვის (storefront-ის მიხედვით) ან სარეზერვო.
    var displayPrice: String { proProduct?.displayPrice ?? "—" }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self?.refreshEntitlements()
                    await transaction.finish()
                }
            }
        }
    }

    /// რეალური entitlement-ის დაყენება (StoreKit-იდან) + isPro-ს გადათვლა.
    private func setPro(_ value: Bool) {
        realPro = value
        UserDefaults.standard.set(value, forKey: proKey)
        recomputeIsPro()
    }

    private func recomputeIsPro() {
        isPro = realPro || UserDefaults.standard.bool(forKey: demoKey)
    }

    // MARK: - QA / დემო override (მუშაობს Release/TestFlight-ზეც)

    /// დემო-Pro ჩართულია თუ არა (ლოკალური override).
    var demoProEnabled: Bool { UserDefaults.standard.bool(forKey: demoKey) }

    /// QA/დემო: ლოკალური Pro-ს გადართვა. **არ** ცვლის რეალურ StoreKit შესყიდვას —
    /// მხოლოდ ლოკალურ `isPro` დროშას QA/ჩვენებისთვის. შენახულია (სესია რჩება Pro).
    /// დამალულია ჟესტის უკან (7-ჯერ შეხება ვერსიაზე) — ხილული ღილაკი არ არსებობს.
    @discardableResult
    func toggleDemoPro() -> Bool {
        let newValue = !UserDefaults.standard.bool(forKey: demoKey)
        UserDefaults.standard.set(newValue, forKey: demoKey)
        recomputeIsPro()
        return isPro
    }

    #if DEBUG
    /// QA-სთვის: Pro-ს იძულებითი ჩართვა/გამორთვა (მხოლოდ DEBUG ბილდში).
    func debugSetPro(_ value: Bool) { setPro(value) }
    #endif
}

// MARK: - House ad model

public struct HouseAd: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let cta: String
    public let symbol: String
    public let url: URL?
}

// MARK: - AdManager

/// რეკლამის მართვა. ამჟამად house-ads; AdMob-ის ჩასართავად ჩაანაცვლე
/// `current`-ის წყარო ბანერის SDK-ით (იხ. docs/PUBLISHING.md).
@MainActor
final class AdManager: ObservableObject {
    @Published private(set) var current: HouseAd?

    private let inventory: [HouseAd]
    private var index = 0

    init() {
        // ბანერი = სპონსორის კრედიტი (Tsili.ge), არა მაღაზიის რეკლამა.
        inventory = [
            HouseAd(
                title: "სპონსორი: Tsili.ge",
                subtitle: "მხარდაჭერე პროექტი — შენი წვლილი ქმნის ახალ დონეებს",
                cta: "მხარდაჭერა",
                symbol: "heart.fill",
                url: URL(string: "https://tsili.ge")
            )
        ]
        current = inventory.first
    }

    /// შემდეგ რეკლამაზე გადასვლა (მაგ. დონის გავლის შემდეგ).
    func rotate() {
        guard !inventory.isEmpty else { return }
        index = (index + 1) % inventory.count
        current = inventory[index]
    }
}
