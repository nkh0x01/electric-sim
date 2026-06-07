//
//  Achievements.swift
//  ElectricSim
//
//  მიღწევები (Phase 4) — ლოკალურად ინახება GameState-ში.
//

import SwiftUI

struct Achievement: Identifiable, Sendable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
}

extension Achievement {
    static let firstLight = Achievement(
        id: "first_light", title: "პირველი ნათება",
        detail: "გაიარე პირველი გაკვეთილი", symbol: "lightbulb.fill")
    static let faultHunter = Achievement(
        id: "fault_hunter", title: "დეფექტის მონადირე",
        detail: "იპოვე და გაასწორე დეფექტი", symbol: "magnifyingglass")
    static let balanced = Achievement(
        id: "balanced", title: "ბალანსის ოსტატი",
        detail: "დააბალანსე სამფაზიანი დატვირთვა", symbol: "scalemass.fill")
    static let motorMaster = Achievement(
        id: "motor_master", title: "მოტორის ოსტატი",
        detail: "ამუშავე 3-ფაზიანი მოტორი", symbol: "fanblades.fill")
    static let perfectionist = Achievement(
        id: "perfectionist", title: "უნაკლო მონტაჟი",
        detail: "ჩართე ძაბვა შეცდომებისა და გაფრთხილებების გარეშე", symbol: "checkmark.seal.fill")
    static let sandboxBuilder = Achievement(
        id: "sandbox_builder", title: "თავისუფალი მშენებელი",
        detail: "ააწყვე მომუშავე წრედი sandbox-ში", symbol: "hammer.fill")
    static let creator = Achievement(
        id: "creator", title: "შემოქმედი",
        detail: "შექმენი საკუთარი დონე", symbol: "square.and.pencil")
    static let masterElectrician = Achievement(
        id: "master_electrician", title: "მთავარი ელექტრიკოსი",
        detail: "გაიარე ყველა ჩაშენებული დონე", symbol: "crown.fill")

    static let all: [Achievement] = [
        firstLight, faultHunter, balanced, motorMaster,
        perfectionist, sandboxBuilder, creator, masterElectrician
    ]
}

struct AchievementsView: View {
    @EnvironmentObject var game: GameState

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ScrollView {
            let unlocked = Achievement.all.filter { game.isUnlocked($0) }.count
            VStack(spacing: 16) {
                Text("\(unlocked) / \(Achievement.all.count) გახსნილი")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Achievement.all) { ach in
                        AchievementCard(achievement: ach, unlocked: game.isUnlocked(ach))
                    }
                }
            }
            .padding()
        }
        .navigationTitle("მიღწევები")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

private struct AchievementCard: View {
    let achievement: Achievement
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: unlocked ? achievement.symbol : "lock.fill")
                .font(.system(size: 30))
                .foregroundStyle(unlocked ? .yellow : .secondary)
                .frame(height: 36)
            Text(achievement.title)
                .font(.subheadline.bold())
                .multilineTextAlignment(.center)
            Text(achievement.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .opacity(unlocked ? 1 : 0.55)
    }
}
