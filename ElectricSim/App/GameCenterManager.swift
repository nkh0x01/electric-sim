//
//  GameCenterManager.swift
//  ElectricSim
//
//  Game Center (GameKit): ავტორიზაცია, ლიდერბორდები, მიღწევები.
//  ავტორიზაცია არ-მბლოკავია (გაშვებისას). ASC-ის გამართვა იხ. README.
//

import Foundation
import GameKit
import SwiftUI
import UIKit

@MainActor
final class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()
    private init() {}

    @Published private(set) var isAuthenticated = false

    // App Store Connect-ში იგივე იდენტიფიკატორებით უნდა შეიქმნას.
    enum Leaderboard {
        static let fastestWiring = "lb_fastest_wiring"     // სწრაფი სწორი დაკაბელება (წმ)
        static let fewestMistakes = "lb_fewest_mistakes"   // ყველაზე ცოტა შეცდომა
    }
    enum Achievement {
        static let phase1 = "ach_phase1"          // Phase 1 დასრულება
        static let phase2 = "ach_phase2"          // Phase 2 (fault-finding)
        static let phase3 = "ach_phase3"          // Phase 3 (3 ფაზა)
        static let phase4 = "ach_phase4"          // Phase 4 (sandbox)
        static let perfectWiring = "ach_perfect_wiring"   // უნაკლო (0 შეცდომა)
        static let faultFinderFast = "ach_faultfinder_fast" // დეფექტი დროზე ადრე
    }

    /// არ-მბლოკავი ავტორიზაცია — გამოიძახე გაშვებისას.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            if let viewController {
                self?.present(viewController)
            } else {
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    /// დონის წარმატებით დასრულებისას — ქულები + მიღწევები.
    func recordCompletion(level: Level, seconds: Int, mistakes: Int) {
        guard isAuthenticated else { return }
        submitScores(seconds: seconds, mistakes: mistakes)
        reportAchievements(level: level, seconds: seconds, mistakes: mistakes)
    }

    private func submitScores(seconds: Int, mistakes: Int) {
        Task {
            try? await GKLeaderboard.submitScore(max(seconds, 0), context: 0,
                player: GKLocalPlayer.local, leaderboardIDs: [Leaderboard.fastestWiring])
            try? await GKLeaderboard.submitScore(max(mistakes, 0), context: 0,
                player: GKLocalPlayer.local, leaderboardIDs: [Leaderboard.fewestMistakes])
        }
    }

    private func reportAchievements(level: Level, seconds: Int, mistakes: Int) {
        var ids: [String] = []
        if level.resolvedMode == .sandbox {
            ids.append(Achievement.phase4)
        } else if level.phase == .three {
            ids.append(Achievement.phase3)
        } else if level.resolvedMode == .faultFind {
            ids.append(Achievement.phase2)
            if seconds <= 120 { ids.append(Achievement.faultFinderFast) }
        } else {
            ids.append(Achievement.phase1)
        }
        if mistakes == 0 { ids.append(Achievement.perfectWiring) }
        report(ids)
    }

    private func report(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let achievements = ids.map { id -> GKAchievement in
            let a = GKAchievement(identifier: id)
            a.percentComplete = 100
            a.showsCompletionBanner = true
            return a
        }
        Task { try? await GKAchievement.report(achievements) }
    }

    private func present(_ viewController: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.keyWindow != nil }),
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(viewController, animated: true)
    }
}
