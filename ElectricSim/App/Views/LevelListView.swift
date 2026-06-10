//
//  LevelListView.swift
//  ElectricSim
//
//  დონეების სია + მონეტიზაცია (Pro) + Phase 4 (sandbox, რედაქტორი, მიღწევები).
//

import SwiftUI

struct LevelListView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    @EnvironmentObject var ads: AdManager
    @Binding var path: [String]
    @State private var showPaywall = false
    @State private var showAbout = false

    var body: some View {
        List {
            if let err = game.loadError {
                Section { Label(err, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            }

            if !store.isPro {
                Section {
                    Button { showPaywall = true } label: {
                        HStack {
                            Image(systemName: "bolt.shield.fill").foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("განბლოკე ელექტრიკი Pro").font(.subheadline.bold())
                                Text("ყველა დონე, 3 ფაზა, დეფექტის ძებნა, sandbox — რეკლამის გარეშე")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            ForEach(game.groupedCampaign) { group in
                Section {
                    ForEach(group.levels) { levelRow($0) }
                } header: {
                    Text(group.category.georgian)
                }
            }

            if !game.customLevels.isEmpty {
                Section("ჩემი დონეები") {
                    ForEach(game.customLevels) { level in
                        Button { path.append(level.id) } label: {
                            LevelRowContent(level: level, completed: game.isCompleted(level),
                                            unlocked: true, proLocked: false)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { idx in
                        idx.map { game.customLevels[$0].id }.forEach(game.deleteCustomLevel)
                    }
                }
            }

            Section("ხელსაწყოები") {
                // Sandbox გადავიდა მთავარ მენიუში (ცალკე რეჟიმად).

                // Level editor — Pro
                if store.isPro {
                    NavigationLink { LevelEditorView() } label: { editorLabel(pro: false) }
                } else {
                    Button { showPaywall = true } label: { editorLabel(pro: true) }
                }

                NavigationLink { AchievementsView() } label: {
                    Label {
                        let n = Achievement.all.filter { game.isUnlocked($0) }.count
                        Text("მიღწევები — \(n)/\(Achievement.all.count)")
                    } icon: {
                        Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                    }
                }
            }

            Section {
                Link(destination: URL(string: "https://tsili.ge")!) {
                    HStack {
                        Image(systemName: "heart.fill").foregroundStyle(.pink)
                        Text("სპონსორი: Tsili.ge").font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("შექმნილია gadget.ge-ს მიერ")
            }
        }
        .navigationTitle("ელექტრიკოსის სიმულატორი")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAbout = true } label: { Image(systemName: "gearshape") }
                    .accessibilityIdentifier("about")
            }
        }
        .safeAreaInset(edge: .bottom) { AdBannerView() }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AboutView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("დახურვა") { showAbout = false }
                        }
                    }
            }
        }
    }

    private func editorLabel(pro: Bool) -> some View {
        HStack {
            Label("დონის რედაქტორი", systemImage: "square.and.pencil")
            if pro {
                Spacer()
                Text("PRO")
                    .font(.system(size: 9, weight: .heavy))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Color.yellow, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
    }

    @ViewBuilder
    private func levelRow(_ level: Level) -> some View {
        let unlocked = game.isUnlocked(level)
        let locked = game.isProLocked(level, isPro: store.isPro)

        Button {
            if locked { showPaywall = true } else { path.append(level.id) }
        } label: {
            LevelRowContent(level: level, completed: game.isCompleted(level),
                            unlocked: unlocked, proLocked: locked)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

struct LevelRowContent: View {
    let level: Level
    let completed: Bool
    let unlocked: Bool
    let proLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(completed ? Color.green.opacity(0.2) : Color.yellow.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(level.title).font(.headline)
                    if proLocked {
                        Text("PRO")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.yellow, in: Capsule())
                            .foregroundStyle(.black)
                    } else if level.resolvedMode == .sandbox {
                        Text("SANDBOX")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                Text(level.brief).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if level.resolvedMode != .sandbox {
                    difficultyView
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// სირთულე — შევსებული/ცარიელი წერტილებით (1...5).
    private var difficultyView: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= level.resolvedDifficulty ? Color.orange : Color.gray.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var iconName: String {
        if proLocked { return "lock.fill" }
        if level.resolvedMode == .sandbox { return "hammer.fill" }
        if completed { return "checkmark" }
        return unlocked ? "bolt.fill" : "lock.fill"
    }
    private var iconColor: Color {
        if completed { return .green }
        return unlocked && !proLocked ? .yellow : .secondary
    }
}

// MARK: - Panel Assembly mode (ფარის აწყობა) — own top-level list

/// „ფარის აწყობა" რეჟიმის სია — გამანაწილებელი ფარის აწყობის დონეები რიგით,
/// პროგრესიითა და free/Pro გeyთვალისწინებით (პირველი ორი უფასოა).
struct PanelListView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    @Binding var path: [String]
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                Label("ააწყვე სრული ფარი სწორი თანმიმდევრობით: მთავარი → SPD → RCD → ავტომატები (სავარცხელი ზოლით). ნული და მიწა გაანაწილე N-bus/PE-bus სალტეებზე.",
                      systemImage: "square.grid.3x3.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if !store.isPro {
                Section {
                    Button { showPaywall = true } label: {
                        HStack {
                            Image(systemName: "bolt.shield.fill").foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("განბლოკე ელექტრიკი Pro").font(.subheadline.bold())
                                Text("ფარის აწყობის ყველა დონე — პირველი ორი უფასოა")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("ფარის აწყობა") {
                ForEach(game.panelLevels) { level in
                    let unlocked = game.isUnlocked(level)
                    let locked = game.isProLocked(level, isPro: store.isPro)
                    Button {
                        if locked { showPaywall = true } else { path.append(level.id) }
                    } label: {
                        LevelRowContent(level: level, completed: game.isCompleted(level),
                                        unlocked: unlocked, proLocked: locked)
                    }
                    .buttonStyle(.plain)
                    .disabled(!unlocked)
                    .accessibilityIdentifier("panel-\(level.id)")
                }
            }
        }
        .navigationTitle("ფარის აწყობა")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { AdBannerView() }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }
}
