//
//  GameState.swift
//  ElectricSim
//
//  გლობალური მდგომარეობა: დონეები, პროგრესი, კომპონენტების ბიბლიოთეკა,
//  მომხმარებლის შექმნილი დონეები (level editor) და მიღწევები (achievements).
//  ყველაფერი ინახება ლოკალურად (UserDefaults).
//

import Foundation
import SwiftUI

@MainActor
final class GameState: ObservableObject {
    @Published var levels: [Level] = []                 // ჩაშენებული დონეები (JSON)
    @Published var customLevels: [Level] = []           // მომხმარებლის შექმნილი
    @Published var templates: [String: ComponentTemplate] = [:]
    @Published var completedLevelIDs: Set<String> = []
    @Published var unlockedAchievements: Set<String> = []
    @Published var loadError: String?

    @Published var sldExportCount: Int = 0

    private let progressKey = "completedLevelIDs.v1"
    private let customKey = "customLevels.v1"
    private let achKey = "achievements.v1"
    private let sldKey = "sldExportCount.v1"

    /// უფასო ვერსიაში — 1 ცალხაზოვანი ნახაზის ექსპორტი; Pro-ში ულიმიტო.
    static let freeSLDExports = 1
    func canExportSLD(isPro: Bool) -> Bool { isPro || sldExportCount < Self.freeSLDExports }
    func recordSLDExport() {
        sldExportCount += 1
        UserDefaults.standard.set(sldExportCount, forKey: sldKey)
    }

    init() {
        load()
    }

    func load() {
        do {
            templates = try GameData.loadTemplates()
            levels = try GameData.loadLevels()
        } catch {
            loadError = "მონაცემების ჩატვირთვა ვერ მოხერხდა: \(error)"
        }
        if let saved = UserDefaults.standard.array(forKey: progressKey) as? [String] {
            completedLevelIDs = Set(saved)
        }
        if let saved = UserDefaults.standard.array(forKey: achKey) as? [String] {
            unlockedAchievements = Set(saved)
        }
        if let data = UserDefaults.standard.data(forKey: customKey),
           let decoded = try? JSONDecoder().decode([Level].self, from: data) {
            customLevels = decoded
        }
        sldExportCount = UserDefaults.standard.integer(forKey: sldKey)
    }

    func template(_ id: String) -> ComponentTemplate? { templates[id] }

    /// დონის პოვნა id-ით (ჩაშენებული + custom) — ნავიგაციისთვის.
    func level(byID id: String) -> Level? {
        levels.first { $0.id == id } ?? customLevels.first { $0.id == id }
    }

    /// Pro-ჩაკეტილია? უფასო = პირველი 3 დონე (1 ფაზა). custom = თავისუფალი.
    func isProLocked(_ level: Level, isPro: Bool) -> Bool {
        if isPro { return false }
        if level.resolvedMode == .sandbox { return true }
        if customLevels.contains(where: { $0.id == level.id }) { return false }
        let free = level.resolvedMode == .build && level.phase == .single && level.index <= 3
        return !free
    }

    // MARK: - პროგრესია

    /// პროგრესიის (numbered) დონეები — sandbox-ის გარეშე.
    var campaignLevels: [Level] { levels.filter { $0.resolvedMode != .sandbox } }
    var sandboxLevels: [Level] { levels.filter { $0.resolvedMode == .sandbox } }

    func isCompleted(_ level: Level) -> Bool { completedLevelIDs.contains(level.id) }

    func isUnlocked(_ level: Level) -> Bool {
        // sandbox და custom დონეები ყოველთვის ღიაა.
        if level.resolvedMode == .sandbox { return true }
        guard let idx = campaignLevels.firstIndex(where: { $0.id == level.id }) else { return true }
        if idx == 0 { return true }
        return completedLevelIDs.contains(campaignLevels[idx - 1].id)
    }

    func markCompleted(_ level: Level) {
        let isNew = completedLevelIDs.insert(level.id).inserted
        // ყოველთვის ვწერთ — პროგრესი შენახული უნდა იყოს „შემდეგი დონე"-ზეც და მენიუში დაბრუნებაზეც.
        UserDefaults.standard.set(Array(completedLevelIDs), forKey: progressKey)
        if isNew { evaluateCompletionAchievements(level) }
    }

    func resetProgress() {
        completedLevelIDs.removeAll()
        UserDefaults.standard.removeObject(forKey: progressKey)
    }

    // MARK: - Level editor (custom დონეები)

    func addCustomLevel(_ level: Level) {
        customLevels.append(level)
        saveCustomLevels()
        unlock(.creator)
    }

    func deleteCustomLevel(_ id: String) {
        customLevels.removeAll { $0.id == id }
        completedLevelIDs.remove(id)
        saveCustomLevels()
    }

    private func saveCustomLevels() {
        if let data = try? JSONEncoder().encode(customLevels) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
    }

    // MARK: - Achievements

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedAchievements.contains(achievement.id)
    }

    func unlock(_ achievement: Achievement) {
        guard !unlockedAchievements.contains(achievement.id) else { return }
        unlockedAchievements.insert(achievement.id)
        UserDefaults.standard.set(Array(unlockedAchievements), forKey: achKey)
    }

    /// გამოიძახება დონის წარმატებით დასრულებისას.
    private func evaluateCompletionAchievements(_ level: Level) {
        if level.id == "lvl_tutorial" { unlock(.firstLight) }
        if level.resolvedMode == .faultFind { unlock(.faultHunter) }
        if level.goal.requireBalanced == true { unlock(.balanced) }
        if level.id == "lvl_motor" { unlock(.motorMaster) }
        // ყველა ჩაშენებული campaign დონე გავლილია?
        if campaignLevels.allSatisfy({ completedLevelIDs.contains($0.id) }) {
            unlock(.masterElectrician)
        }
    }

    /// გამოიძახება ყოველ „ჩართე ძაბვა"-ზე (sandbox/perfect-run მიღწევებისთვის).
    func noteSimulation(level: Level, result: SimulationResult) {
        let anyPowered = result.loadStates.contains { $0.isPowered }
        if level.resolvedMode == .sandbox && anyPowered {
            unlock(.sandboxBuilder)
        }
        if result.energized, result.passed, result.warnings.isEmpty, anyPowered {
            unlock(.perfectionist)
        }
    }
}
