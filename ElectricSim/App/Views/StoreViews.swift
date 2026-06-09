//
//  StoreViews.swift
//  ElectricSim
//
//  მონეტიზაციის ინტერფეისი: სარეკლამო ბანერი, Pro-ს paywall, „შესახებ" ეკრანი.
//  მთლიანად ქართულად. ბრენდი: gadget.ge. დაფინანსება: Tsili.Ge.
//

import SwiftUI

// MARK: - Ad banner (house ad; AdMob-ით ჩანაცვლებადი)

struct AdBannerView: View {
    @EnvironmentObject var store: EntitlementStore
    @EnvironmentObject var ads: AdManager

    var body: some View {
        if store.isPro {
            EmptyView() // Pro მომხმარებლებს რეკლამა არ ეჩვენებათ
        } else if let ad = ads.current {
            Link(destination: ad.url ?? URL(string: "https://gadget.ge")!) {
                HStack(spacing: 12) {
                    Image(systemName: ad.symbol)
                        .font(.title3)
                        .foregroundStyle(.yellow)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ad.title).font(.caption.bold()).foregroundStyle(.primary)
                        Text(ad.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(ad.cta)
                        .font(.caption2.bold())
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.yellow, in: Capsule())
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
                .overlay(alignment: .topLeading) {
                    Text("სპონსორი")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .padding(2)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Paywall

struct PaywallView: View {
    @EnvironmentObject var store: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @State private var restoreMessage: String?

    /// ფასის სტრიქონი ღილაკზე — StoreKit Product.displayPrice (ფასი არსად არ არის hardcoded).
    private var buyTitle: String {
        String(format: String(localized: "paywall_buy"), store.displayPrice)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.brand)
                        .padding(.top, 12)

                    Text("paywall_title").font(.title.bold())
                    Text("paywall_subtitle")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: 14) {
                        bullet("rectangle.3.group.fill", "paywall_b1")
                        bullet("bolt.fill", "paywall_b2")
                        bullet("magnifyingglass", "paywall_b3")
                        bullet("hammer.fill", "paywall_b4")
                        bullet("square.grid.3x3.fill", "paywall_b5")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    Button {
                        Task { await store.purchasePro() }
                    } label: {
                        HStack {
                            if store.purchaseInFlight { ProgressView().tint(.white) }
                            Text(buyTitle).bold()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brand)
                    .disabled(store.isPro || store.purchaseInFlight)

                    Button {
                        Task {
                            await store.restorePurchases()
                            restoreMessage = store.isPro
                                ? String(localized: "paywall_restore_ok")
                                : String(localized: "paywall_restore_none")
                        }
                    } label: {
                        Text("paywall_restore").font(.footnote)
                    }

                    if let restoreMessage {
                        Text(restoreMessage)
                            .font(.caption2)
                            .foregroundStyle(store.isPro ? .green : .secondary)
                    }
                    if let err = store.lastError {
                        Text(err).font(.caption2).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    Text("paywall_footer")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding()
            }
            .navigationTitle("paywall_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { pro in if pro { dismiss() } }
        }
    }

    private func bullet(_ symbol: String, _ key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.brand).frame(width: 26)
            Text(key).font(.subheadline)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Settings (პარამეტრები)

/// მთავარი პარამეტრების ეკრანი: ხმა, შესყიდვების აღდგენა, „შესახებ", ვერსია
/// (დამალული დემო-Pro ჟესტით) და პროგრესის განულება. იხსნება მთავარი მენიუს
/// ⚙️ ღილაკიდან.
struct SettingsView: View {
    @EnvironmentObject var store: EntitlementStore
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss

    // ხმის პარამეტრი (placeholder — შენახული პრეფერენცია; ხმის ძრავა მოგვიანებით).
    @AppStorage("pref.soundEnabled") private var soundEnabled = true

    @State private var showPaywall = false
    @State private var restoreMessage: String?
    // დამალული QA/დემო Pro-გადართვა: ვერსიაზე 7-ჯერ შეხება (Release-ზეც მუშაობს).
    @State private var versionTaps = 0
    @State private var demoMessage: String?

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("ხმა") {
                    Toggle(isOn: $soundEnabled) {
                        Label("ხმოვანი ეფექტები",
                              systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    }
                    .accessibilityIdentifier("settings-sound")
                }

                Section("Pro") {
                    if store.isPro {
                        Label("Pro გააქტიურებულია — გმადლობთ!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("განბლოკე ელექტრიკი Pro", systemImage: "bolt.shield.fill")
                        }
                    }
                    Button {
                        Task {
                            await store.restorePurchases()
                            restoreMessage = store.isPro
                                ? "შესყიდვა აღდგენილია."
                                : "აღსადგენი შესყიდვა ვერ მოიძებნა."
                        }
                    } label: {
                        Label("შესყიდვების აღდგენა", systemImage: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("settings-restore")
                    if let restoreMessage {
                        Text(restoreMessage).font(.caption)
                            .foregroundStyle(store.isPro ? .green : .secondary)
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("შესახებ", systemImage: "info.circle")
                    }
                    .accessibilityIdentifier("settings-about")
                }

                Section {
                    Button(role: .destructive) {
                        game.resetProgress()
                    } label: {
                        Label("პროგრესის განულება", systemImage: "arrow.counterclockwise")
                    }
                }

                #if DEBUG
                Section("QA (DEBUG)") {
                    Toggle("Pro იძულებით ჩართვა", isOn: Binding(
                        get: { store.isPro },
                        set: { store.debugSetPro($0) }
                    ))
                }
                #endif

                Section {
                    Text("ვერსია \(appVersion)")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .onTapGesture { registerVersionTap() }   // 7× → დემო Pro
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("settings-version")
                }
            }
            .navigationTitle("პარამეტრები")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("დახურვა") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
            .alert(demoMessage ?? "", isPresented: Binding(
                get: { demoMessage != nil },
                set: { if !$0 { demoMessage = nil } }
            )) {
                Button("კარგი", role: .cancel) { demoMessage = nil }
            }
        }
    }

    /// ვერსიაზე 7-ჯერ შეხება → ლოკალური (დემო) Pro-ს გადართვა. დამალულია,
    /// ხილული ღილაკი არ არსებობს; რეალურ IAP-ს არ ცვლის.
    private func registerVersionTap() {
        versionTaps += 1
        guard versionTaps >= 7 else { return }
        versionTaps = 0
        store.toggleDemoPro()
        demoMessage = store.demoProEnabled ? "Pro ჩართულია (დემო)" : "Pro გამორთულია"
    }
}

// MARK: - About (ბრენდი + ლოგოები + ბმულები)

/// „შესახებ" ეკრანი — აპის სახელი/აღწერა, შემქმნელი (Gadget) და სპონსორი
/// (Tsili) ლოგოებითა და ბმულებით, კონფიდენციალურობის პოლიტიკა. Content-only:
/// ნავიგაცია მშობელი stack-იდან (Settings-ის NavigationLink ან sheet wrapper).
struct AboutView: View {
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 44)).foregroundStyle(.yellow)
                        .frame(width: 72, height: 72)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    Text("ელექტრიკოსის სიმულატორი").font(.title3.bold())
                    Text("ისწავლე ელექტრომონტაჟი (IEC / TN-C-S) — ფარის აწყობა, შემოწმება და დეფექტის ძებნა, მთლიანად ქართულად.")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("შემქმნელი") {
                HStack(spacing: 12) {
                    brandLogo("GadgetLogo", fallback: "wrench.and.screwdriver.fill", tint: .brand)
                    Text("შექმნილია Gadget-ის მიერ").font(.callout)
                }
                Link(destination: URL(string: "https://gadget.ge")!) {
                    Label("gadget.ge", systemImage: "globe")
                }
                Link(destination: URL(string: "mailto:info@gadget.ge")!) {
                    Label("info@gadget.ge", systemImage: "envelope")
                }
            }

            Section("მხარდაჭერა") {
                HStack(spacing: 12) {
                    brandLogo("TsiliLogo", fallback: "heart.fill", tint: .pink)
                    Text("Tsili.ge — იყიდე ქართული წარმოება").font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Link(destination: URL(string: "https://tsili.ge")!) {
                    Label("tsili.ge", systemImage: "globe")
                }
            }

            Section("სამართლებრივი") {
                Link(destination: URL(string: "https://gadget.ge/privacy")!) {
                    Label("კონფიდენციალურობის პოლიტიკა", systemImage: "hand.raised.fill")
                }
            }

            Section {
                Text("ვერსია \(appVersion)")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("შესახებ")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// ბრენდის ლოგო asset-იდან. სანამ რეალურ PNG-ს ჩასვამ, asset ცარიელია →
    /// ზედა Image არაფერს ხატავs და ქვედა SF-სიმბოლო ჩანს (build არ ფუჭდება).
    private func brandLogo(_ name: String, fallback: String, tint: Color) -> some View {
        ZStack {
            Image(systemName: fallback).resizable().scaledToFit()
                .foregroundStyle(tint).padding(9)
            Image(name).resizable().scaledToFit()   // ცარიელ asset-ზე უხილავია
        }
        .frame(width: 44, height: 44)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
