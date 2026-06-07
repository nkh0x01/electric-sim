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
    @State private var path: [String] = []   // ნავიგაცია დონის id-ებით

    var body: some View {
        NavigationStack(path: $path) {
            LevelListView(path: $path)
                .navigationDestination(for: String.self) { id in
                    if let level = game.level(byID: id) {
                        WorkbenchView(level: level, path: $path)
                    }
                }
        }
        .tint(.brand)
        .onAppear { GameCenterManager.shared.authenticate() }   // არ-მბლოკავი
    }
}
