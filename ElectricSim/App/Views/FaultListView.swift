//
//  FaultListView.swift
//  ElectricSim
//
//  დიაგნოსტიკის რეჟიმი — fault-finding მისიების სია. Pro gating არსებული isPro-ით.
//

import SwiftUI

struct FaultListView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    @Binding var path: [String]
    @State private var showPaywall = false

    var body: some View {
        List {
            Section { hud }

            Section("მისიები") {
                ForEach(game.faults) { mission in
                    missionRow(mission)
                }
            }
        }
        .navigationTitle("დიაგნოსტიკა")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }

    private var hud: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("წოდება").font(.caption2).foregroundStyle(.secondary)
                Text(game.career.currentRank.georgian)
                    .font(.subheadline.bold()).foregroundStyle(.brand)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Label("\(game.career.totalXP) XP", systemImage: "star.fill")
                    .font(.caption.bold()).foregroundStyle(.orange)
                Label("\(game.career.cash) ₾", systemImage: "banknote")
                    .font(.caption.bold()).foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func missionRow(_ m: FaultMission) -> some View {
        let locked = !store.isPro && m.tier == .pro
        let done = game.career.isCompleted(m.id)
        Button {
            if locked { showPaywall = true } else { path.append("fault:\(m.id)") }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: locked ? "lock.fill" : (done ? "checkmark" : "magnifyingglass"))
                        .foregroundStyle(done ? Color.green : (locked ? Color.secondary : Color.orange))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(m.georgianTitle).font(.headline)
                        if locked { badge("PRO", .yellow, .black) }
                        if done { badge("გადაჭრილი", Color.green.opacity(0.2), .green) }
                    }
                    Text("\(m.customerName) · \(m.location)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 10) {
                        difficultyDots(m.resolvedDifficulty)
                        Label("\(m.xpReward) XP", systemImage: "star").font(.caption2).foregroundStyle(.orange)
                        Label("\(m.cashReward) ₾", systemImage: "banknote").font(.caption2).foregroundStyle(.green)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String, _ bg: Color, _ fg: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .heavy))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(bg, in: Capsule())
            .foregroundStyle(fg)
    }

    private func difficultyDots(_ n: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle().fill(i <= n ? Color.orange : Color.gray.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
