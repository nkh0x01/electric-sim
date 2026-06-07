//
//  LevelEditorView.swift
//  ElectricSim
//
//  დონის რედაქტორი (Phase 4) — მომხმარებელი ქმნის საკუთარ დონეს,
//  ინახება ლოკალურად (GameState.customLevels).
//

import SwiftUI

struct LevelEditorView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var brief = ""
    @State private var hint = ""
    @State private var phase: Phase = .single
    @State private var maxCounts: [String: Int] = [:]
    @State private var lamps = 1
    @State private var sockets = 0
    @State private var motors = 0
    @State private var validationMessage: String?

    /// ფაზისთვის შესაბამისი შაბლონები (motor მხოლოდ 3 ფაზაზე).
    private var availableTemplates: [ComponentTemplate] {
        game.templates.values
            .filter { $0.kind != .supply }
            .filter { phase == .three || $0.kind != .motor }
            .sorted { $0.id < $1.id }
    }

    var body: some View {
        Form {
            Section("აღწერა") {
                TextField("დასახელება", text: $title)
                TextField("დავალება", text: $brief, axis: .vertical).lineLimit(2...4)
                TextField("მინიშნება", text: $hint, axis: .vertical).lineLimit(1...3)
                Picker("ფაზა", selection: $phase) {
                    Text("1 ფაზა").tag(Phase.single)
                    Text("3 ფაზა").tag(Phase.three)
                }
                .pickerStyle(.segmented)
            }

            Section("ხელმისაწვდომი კომპონენტები (პალიტრა)") {
                ForEach(availableTemplates) { t in
                    Stepper(value: binding(for: t.id), in: 0...6) {
                        HStack {
                            Image(systemName: t.kind.sfSymbol).foregroundStyle(.secondary)
                            Text(t.name).font(.subheadline)
                            Spacer()
                            Text("\(maxCounts[t.id] ?? 0)").foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("მიზანი — რა უნდა აანთდეს") {
                Stepper("ნათურა: \(lamps)", value: $lamps, in: 0...6)
                Stepper("როზეტი: \(sockets)", value: $sockets, in: 0...6)
                if phase == .three {
                    Stepper("მოტორი: \(motors)", value: $motors, in: 0...3)
                }
            }

            if let msg = validationMessage {
                Section { Text(msg).foregroundStyle(.red).font(.callout) }
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("დონის შენახვა", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("ახალი დონე")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for id: String) -> Binding<Int> {
        Binding(get: { maxCounts[id] ?? 0 }, set: { maxCounts[id] = $0 })
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { validationMessage = "შეავსე დასახელება."; return }

        let palette = maxCounts
            .filter { $0.value > 0 }
            .map { tid, max -> PaletteEntry in
                let isBreaker = game.templates[tid]?.kind == .mcb || game.templates[tid]?.kind == .rcbo
                return PaletteEntry(templateId: tid, max: max,
                                    csaOptions: isBreaker ? [1.5, 2.5, 4, 6, 10] : nil)
            }
            .sorted { $0.templateId < $1.templateId }

        guard !palette.isEmpty else {
            validationMessage = "დაამატე მინიმუმ ერთი კომპონენტი პალიტრაში."
            return
        }

        var powered: [String: Int] = [:]
        if lamps > 0 { powered["lamp"] = lamps }
        if sockets > 0 { powered["socket"] = sockets }
        if phase == .three && motors > 0 { powered["motor"] = motors }
        guard !powered.isEmpty else {
            validationMessage = "მიუთითე მინიმუმ ერთი დატვირთვა, რომელიც უნდა აანთდეს."
            return
        }

        let level = Level(
            id: "custom_\(UUID().uuidString.prefix(8))",
            index: 1000 + game.customLevels.count,
            title: trimmed,
            brief: brief.isEmpty ? "ააწყვე და ჩართე ძაბვა." : brief,
            hint: hint.isEmpty ? "გამოიყენე სწორი ფერები და კაბელის კვეთა." : hint,
            phase: phase,
            palette: palette,
            goal: LevelGoal(poweredLoads: powered,
                            description: "ყველა დატვირთვა უნდა აანთდეს შეცდომების გარეშე.",
                            requireBalanced: nil),
            mode: .build,
            prebuilt: nil
        )
        game.addCustomLevel(level)
        dismiss()
    }
}
