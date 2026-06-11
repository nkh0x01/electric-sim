//
//  ElectricSimApp.swift
//  ElectricSim
//
//  ელექტრიკის სიმულატორი — საგანმანათლებლო თამაში (TN-C-S / IEC).
//  iOS 16+, iPhone + iPad, portrait + landscape.
//

import SwiftUI

@main
struct ElectricSimApp: App {
    @StateObject private var game = GameState()
    @StateObject private var store = EntitlementStore()
    @StateObject private var ads = AdManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .environmentObject(store)
                .environmentObject(ads)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var game: GameState
    @State private var path: [String] = []   // ნავიგაცია route-სტრიქონებით

    var body: some View {
        NavigationStack(path: $path) {
            MainMenuView(path: $path)
                .navigationDestination(for: String.self) { route in
                    destination(for: route)
                }
        }
        .tint(.brand)
        .onAppear { GameCenterManager.shared.authenticate() }   // არ-მბლოკავი
    }

    /// route-სტრიქონი → ეკრანი. პრეფიქსები: "job:" ბრიფინგი, "jobwork:" career workbench;
    /// "learn"/"career"/"sandbox" რეჟიმები; სხვა → დონის id (Learn/Sandbox workbench).
    /// .id(route) აუცილებელია: ერთიდაიგივე სიღრმეზე route-ის შეცვლისას (მაგ.
    /// „შემდეგი დონე") SwiftUI იმავე ტიპის view-ს იდენტურად თვლის და ძველ
    /// @StateObject-ს იტოვებს — ძველი დონე რჩებოდა ეკრანზე. route-იდენტობა
    /// აიძულებს ახალი ეკრანის შექმნას.
    @ViewBuilder
    private func destination(for route: String) -> some View {
        Group {
            switch route {
            case "learn":   LevelListView(path: $path)
            case "career":  CareerBoardView(path: $path)
            case "panels":  PanelListView(path: $path)
            case "sandbox": SandboxListView(path: $path)
            case "faults":  FaultListView(path: $path)
            default:
                if route.hasPrefix("job:") {
                    JobBriefingView(jobID: String(route.dropFirst("job:".count)), path: $path)
                } else if route.hasPrefix("jobwork:") {
                    if let job = game.job(byID: String(route.dropFirst("jobwork:".count))) {
                        WorkbenchView(job: job, path: $path)
                    }
                } else if route.hasPrefix("fault:") {
                    FaultMissionView(missionID: String(route.dropFirst("fault:".count)), path: $path)
                } else if let level = game.level(byID: route) {
                    WorkbenchView(level: level, path: $path)
                }
            }
        }
        .id(route)
    }
}
