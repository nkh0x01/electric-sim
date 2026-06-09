//
//  SandboxListView.swift
//  ElectricSim
//
//  Sandbox რეჟიმი — არსებული sandbox დონეები (Pro). იგივე gating (isProLocked).
//

import SwiftUI

struct SandboxListView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    @Binding var path: [String]
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                ForEach(game.sandboxLevels) { level in
                    let locked = game.isProLocked(level, isPro: store.isPro)
                    Button {
                        if locked { showPaywall = true } else { path.append(level.id) }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: locked ? "lock.fill" : "hammer.fill")
                                .foregroundStyle(locked ? Color.secondary : Color.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(level.title).font(.headline)
                                    if locked {
                                        Text("PRO").font(.system(size: 9, weight: .heavy))
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(Color.yellow, in: Capsule())
                                            .foregroundStyle(.black)
                                    }
                                }
                                Text(level.brief).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("თავისუფალი აწყობა მიზნისა და შეზღუდვის გარეშე.")
            }
        }
        .navigationTitle("Sandbox")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }
}
