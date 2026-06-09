//
//  CareerBoardView.swift
//  ElectricSim
//
//  Career Mode — სამუშაოების დაფა + HUD (წოდება / ფული / XP).
//

import SwiftUI

struct CareerBoardView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    @Binding var path: [String]
    @State private var showPaywall = false

    /// სამუშაოებში წარმოდგენილი კატეგორიები (რიგით) — tuple-keypath-ის თავიდან ასაცილებლად.
    private var presentCategories: [JobCategory] {
        var seen: [JobCategory] = []
        for j in game.jobs where !seen.contains(j.category) { seen.append(j.category) }
        return seen.sorted { $0.rawValue < $1.rawValue }
    }
    private func jobs(in category: JobCategory) -> [Job] {
        game.jobs.filter { $0.category == category }.sorted { $0.difficulty < $1.difficulty }
    }

    var body: some View {
        List {
            Section { hud }

            ForEach(presentCategories, id: \.self) { category in
                Section(category.georgian) {
                    ForEach(jobs(in: category)) { job in
                        jobRow(job)
                    }
                }
            }
        }
        .navigationTitle("კარიერა")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }

    // MARK: HUD

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

    // MARK: Job row

    @ViewBuilder
    private func jobRow(_ job: Job) -> some View {
        let locked = game.career.isProLocked(job, isPro: store.isPro)
        let done = game.isJobCompleted(job.id)
        Button {
            if locked { showPaywall = true } else { path.append("job:\(job.id)") }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done ? Color.green.opacity(0.2) : Color.orange.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: locked ? "lock.fill" : (done ? "checkmark" : "briefcase.fill"))
                        .foregroundStyle(done ? Color.green : (locked ? Color.secondary : Color.orange))
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(job.georgianTitle).font(.headline)
                        if locked { badge("PRO", .yellow, .black) }
                        if done { badge("შესრულდა", Color.green.opacity(0.2), .green) }
                    }
                    Text("\(job.customerName) · \(job.location)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 10) {
                        difficultyDots(job.resolvedDifficulty)
                        Label("\(job.xpReward) XP", systemImage: "star").font(.caption2).foregroundStyle(.orange)
                        Label("\(job.cashReward) ₾", systemImage: "banknote").font(.caption2).foregroundStyle(.green)
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
