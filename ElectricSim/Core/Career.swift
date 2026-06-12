//
//  Career.swift
//  ElectricSim — Core
//
//  Career Mode — Phase 1: data model + persistence only (no UI).
//  იყენებს არსებულ პატერნებს: JSON ჩატვირთვა GameData-ით (იგივე, რაც levels.json),
//  ფასიანობა LevelTier-ით (free/pro) + EntitlementStore.isPro (gating არ იფორკება),
//  ბაზისური კომპონენტების ნაკრები ComponentGating-იდან.
//

import Foundation

// MARK: - Job category

/// სამუშაოს კატეგორია (ka labels — UI-სთვის).
public enum JobCategory: String, Codable, Sendable, CaseIterable {
    case tutorial
    case residential
    case commercial
    case industrial
    case faultfinding
    case renewable
    case inspection

    public var georgian: String {
        switch self {
        case .tutorial:     return "შესავალი"
        case .residential:  return "საცხოვრებელი"
        case .commercial:   return "კომერციული"
        case .industrial:   return "სამრეწველო"
        case .faultfinding: return "დეფექტის ძებნა"
        case .renewable:    return "განახლებადი ენერგია"
        case .inspection:   return "ინსპექცია"
        }
    }
}

// MARK: - Career rank (thresholds centralized here)

/// კარიერული წოდება. XP-ის ზღვრები ერთ ადგილას — ადვილად რეგულირებადი.
public enum CareerRank: String, Codable, Sendable, CaseIterable {
    case apprentice
    case residential
    case commercial
    case industrial
    case renewable
    case master

    /// XP ზღვარი, რომლის მიღწევაც ხსნის ამ წოდებას.
    public var xpThreshold: Int {
        switch self {
        case .apprentice:  return 0
        case .residential: return 300
        case .commercial:  return 900
        case .industrial:  return 1800
        case .renewable:   return 3000
        case .master:      return 5000
        }
    }

    /// ქართული იარლიყი (UI).
    public var georgian: String {
        switch self {
        case .apprentice:  return "შეგირდი"
        case .residential: return "საცხოვრებელი ობიექტების ელექტრიკოსი"
        case .commercial:  return "კომერციული ობიექტების ელექტრიკოსი"
        case .industrial:  return "სამრეწველო ელექტრიკოსი"
        case .renewable:   return "განახლებადი ენერგიის სპეციალისტი"
        case .master:      return "ოსტატი ელექტრიკოსი"
        }
    }

    /// დალაგების რიგი (დაბალი → მაღალი).
    public var order: Int {
        switch self {
        case .apprentice:  return 0
        case .residential: return 1
        case .commercial:  return 2
        case .industrial:  return 3
        case .renewable:   return 4
        case .master:      return 5
        }
    }

    /// მოცემული XP-ისთვის უმაღლესი მიღწეული წოდება.
    public static func rank(forXP xp: Int) -> CareerRank {
        allCases.filter { xp >= $0.xpThreshold }.max(by: { $0.order < $1.order }) ?? .apprentice
    }
}

// MARK: - Job (jobs.json)

/// სამუშაოს ფაზურობა jobs.json-ში ("singlePhase"/"threePhase"). ცალკე ენუმი,
/// რომ JSON-მნიშვნელობები სქემის სპეციფიკაციას ემთხვეოდეს (და არა Core-ის Phase-ს).
public enum JobPhase: String, Codable, Sendable {
    case singlePhase
    case threePhase

    /// შესაბამისი ძრავის (solver) ფაზა.
    public var enginePhase: Phase { self == .threePhase ? .three : .single }
}

public struct Job: Codable, Identifiable, Sendable {
    public let id: String
    public let georgianTitle: String
    public let customerName: String
    public let location: String
    public let category: JobCategory
    public let difficulty: Int            // 1...5
    public let tier: LevelTier            // free / pro — არსებული gating-ის გასაღები
    public let jobBrief: String           // ka
    public let componentsAvailable: [String]  // templateId-ები (პალიტრა)
    public let requiredComponents: [String]   // templateId-ები (გადასაჭრელად საჭირო)
    public let xpReward: Int
    public let cashReward: Int
    public let unlocks: [String]          // რას ხსნის (კომპონენტი/ხელსაწყო id)
    public let goal: LevelGoal            // წარმატების კრიტერიუმი — იგივე, რაც დონეებში
    // გაფართოებული (advanced) სამუშაოების ველები — არასავალდებულო, ძველი jobs.json
    // უცვლელად იშიფრება (nil → ნაგულისხმევები ქვემოთ).
    public var phase: JobPhase? = nil          // nil → singlePhase
    public var csaOptions: [Double]? = nil     // nil → [1.5, 2.5, 4]

    public var resolvedDifficulty: Int { min(5, max(1, difficulty)) }

    /// სამუშაოს ფაზა — ნაგულისხმევად ერთფაზიანი.
    public var resolvedPhase: Phase { (phase ?? .singlePhase).enginePhase }
    /// კაბელის დასაშვები კვეთები — 6/10მმ² მხოლოდ მაშინ, თუ job-ი ცხადად უშვებს.
    public var resolvedCsaOptions: [Double] { csaOptions ?? [1.5, 2.5, 4] }

    /// სამუშაოდან workbench-ის დონის აგება (იყენებს არსებულ Level/solver-ს — არ იფორკება).
    public func makeLevel() -> Level {
        let palette = componentsAvailable.map {
            PaletteEntry(templateId: $0, max: 4, csaOptions: resolvedCsaOptions)
        }
        return Level(id: "career_\(id)", index: 0, title: georgianTitle,
                     brief: jobBrief, hint: "", phase: resolvedPhase,
                     palette: palette, goal: goal, mode: .build,
                     category: .tutorial, difficulty: difficulty, tier: tier)
    }
}

/// სამუშაოს დასრულების შედეგი (UI-ს ჯილდოს საჩვენებლად).
public struct CareerOutcome: Sendable {
    public let awarded: Bool        // პირველად დასრულდა (ჯილდო გაიცა)?
    public let xp: Int
    public let cash: Int
    public let rankBefore: CareerRank
    public let rankAfter: CareerRank
    public var rankedUp: Bool { rankAfter != rankBefore }

    public init(awarded: Bool, xp: Int, cash: Int, rankBefore: CareerRank, rankAfter: CareerRank) {
        self.awarded = awarded; self.xp = xp; self.cash = cash
        self.rankBefore = rankBefore; self.rankAfter = rankAfter
    }
}

// MARK: - Career state (persistent, UserDefaults — იგივე პატერნი, რაც GameState)

/// კარიერის მდგომარეობა. Foundation-only და ტესტირებადი (UserDefaults ინჟექტირებადია).
public final class CareerState {

    public static let startingCash = 0
    public static let progressKey = "career.v1"

    private let defaults: UserDefaults

    public private(set) var totalXP: Int
    public private(set) var cash: Int
    public private(set) var completedJobs: Set<String>
    public private(set) var ownedTools: Set<String>
    public private(set) var ownedComponents: Set<String>

    /// მიმდინარე წოდება — გამოითვლება totalXP-დან (ცალკე შესანახი არ სჭირდება).
    public var currentRank: CareerRank { CareerRank.rank(forXP: totalXP) }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.progressKey),
           let s = try? JSONDecoder().decode(Persisted.self, from: data) {
            totalXP = s.totalXP
            cash = s.cash
            completedJobs = Set(s.completedJobs)
            ownedTools = Set(s.ownedTools)
            ownedComponents = Set(s.ownedComponents)
        } else {
            // default ახალი კარიერა
            totalXP = 0
            cash = Self.startingCash
            completedJobs = []
            ownedTools = []
            ownedComponents = []
        }
    }

    public func isCompleted(_ jobID: String) -> Bool { completedJobs.contains(jobID) }

    /// სამუშაოს დასრულება. ჯილდო ერთხელ — ხელახლა გავლა XP/cash-ს არ ადუბლირებს.
    /// აბრუნებს true-ს, თუ ეს იყო პირველი დასრულება (ჯილდო გაიცა).
    @discardableResult
    public func completeJob(_ job: Job) -> Bool {
        guard !completedJobs.contains(job.id) else { return false }
        completedJobs.insert(job.id)
        totalXP += job.xpReward
        cash += job.cashReward
        for u in job.unlocks { ownedComponents.insert(u) }  // unlocks → ხელმისაწვდომი კომპონენტები
        save()
        return true
    }

    /// gating — არსებული isPro-ით (არ იფორკება). Pro-სამუშაო ჩაკეტილია უფასო მომხმარებლისთვის.
    public func isProLocked(_ job: Job, isPro: Bool) -> Bool {
        if isPro { return false }
        return job.tier == .pro
    }

    /// Fault-finding მისიის დასრულება. ჯილდო ერთხელ (იზიარებს completedJobs-ს id-ით).
    @discardableResult
    public func completeFault(_ mission: FaultMission) -> Bool {
        guard !completedJobs.contains(mission.id) else { return false }
        completedJobs.insert(mission.id)
        totalXP += mission.xpReward
        cash += mission.cashReward
        save()
        return true
    }

    /// Live-wire შოკის ჯარიმა — აკლებს cash-ს (floor 0). აბრუნებს რეალურად
    /// ჩამოჭრილ თანხას (cash 0-ზე ქვემოთ არ ჩამოდის).
    @discardableResult
    public func penalizeShock(_ amount: Int) -> Int {
        let deducted = max(0, min(cash, amount))
        guard deducted > 0 else { return 0 }
        cash -= deducted
        save()
        return deducted
    }

    public func resetProgress() {
        totalXP = 0; cash = Self.startingCash
        completedJobs = []; ownedTools = []; ownedComponents = []
        defaults.removeObject(forKey: Self.progressKey)
    }

    private func save() {
        let s = Persisted(totalXP: totalXP, cash: cash,
                          completedJobs: Array(completedJobs),
                          ownedTools: Array(ownedTools),
                          ownedComponents: Array(ownedComponents))
        if let data = try? JSONEncoder().encode(s) {
            defaults.set(data, forKey: Self.progressKey)
        }
    }

    private struct Persisted: Codable {
        let totalXP: Int
        let cash: Int
        let completedJobs: [String]
        let ownedTools: [String]
        let ownedComponents: [String]
    }
}
