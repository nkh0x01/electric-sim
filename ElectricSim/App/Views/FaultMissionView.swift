//
//  FaultMissionView.swift
//  ElectricSim
//
//  Fault-finding gameplay loop (Phase 2): briefing → inspect → diagnose →
//  repair → verify → complete. დიაგნოზი multiple-choice; შესწორება data-driven
//  (mission.fix). სიმართლის წყარო: FaultEngine. UI ქართულად.
//

import SwiftUI

struct FaultMissionView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    let missionID: String
    @Binding var path: [String]

    private enum Step { case briefing, inspect, diagnose, repair, done }
    @State private var step: Step = .briefing
    @State private var attempts = 0
    @State private var feedback: String?
    @State private var outcome: CareerOutcome?

    private var mission: FaultMission? { game.fault(byID: missionID) }

    var body: some View {
        Group {
            if let m = mission {
                switch step {
                case .briefing: briefing(m)
                case .inspect:  inspect(m)
                case .diagnose: diagnosis(m)
                case .repair:   repairStep(m)
                case .done:     doneView(m)
                }
            } else {
                Text("მისია ვერ მოიძებნა.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(mission?.georgianTitle ?? "დიაგნოსტიკა")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: helpers
    private func faultedBoard(_ m: FaultMission) -> Board { m.faultedBoard(templates: game.templates) }
    private func faultResult(_ m: FaultMission) -> SimulationResult {
        CircuitSolver().solve(faultedBoard(m), energize: true)
    }

    // MARK: a) briefing
    private func briefing(_ m: FaultMission) -> some View {
        List {
            Section("გამოძახება") {
                labeled("კლიენტი", m.customerName)
                labeled("ლოკაცია", m.location)
            }
            Section("საჩივარი") {
                Text(m.customerComplaint).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            Section("სიმპტომები") {
                ForEach(m.symptoms, id: \.self) { s in
                    Label(s, systemImage: "exclamationmark.bubble").font(.callout)
                }
            }
            Section {
                primaryButton("დაიწყე დიაგნოსტიკა", "stethoscope") { step = .inspect }
                    .accessibilityIdentifier("fault-start")
            }
        }
    }

    // MARK: b) inspection (read-only board + symptom hints)
    private func inspect(_ m: FaultMission) -> some View {
        let r = faultResult(m)
        return VStack(spacing: 10) {
            if !symptomBadges(r).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(symptomBadges(r), id: \.self) { b in
                            Text(b).font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.orange.opacity(0.18), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }.padding(.horizontal)
                }
                .padding(.top, 8)
            }
            FaultBoardView(board: faultedBoard(m), result: r)
            Divider()
            primaryButton("დიაგნოზზე გადასვლა →", "list.bullet.clipboard") { step = .diagnose }
                .padding(.horizontal).padding(.bottom, 8)
        }
    }

    private func symptomBadges(_ r: SimulationResult) -> [String] {
        var s: [String] = []
        if r.anyTrip { s.append("⚡️ დამცავი იგდება") }
        if r.contains(.breakerExceedsCable) { s.append("🔥 კაბელი გადახურდება") }
        if r.contains(.missingPE) { s.append("⚠️ PE აკლია") }
        if r.anyShockRisk { s.append("⚡️ შოკის რისკი") }
        if r.contains(.socketWithoutRCD) { s.append("⚠️ RCD დაცვა აკლია") }
        if r.contains(.openCircuit) { s.append("○ წრედი წყვეტილია") }
        return s
    }

    // MARK: c) diagnosis (multiple choice — FaultEngine is source of truth)
    private func diagnosis(_ m: FaultMission) -> some View {
        let correct = FaultEngine.diagnose(faultedBoard(m)) ?? m.faultType
        return List {
            Section("რა არის გაუმართაობა?") {
                ForEach(candidates(for: correct), id: \.self) { ft in
                    Button {
                        if ft == correct {
                            feedback = nil; step = .repair
                        } else {
                            attempts += 1
                            feedback = "არასწორი დიაგნოზი — დააკვირდი სიმპტომებს და სცადე ისევ."
                        }
                    } label: {
                        Label(ft.georgian, systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.plain)
                }
            }
            if let feedback {
                Section { Text(feedback).font(.caption).foregroundStyle(.red) }
            }
        }
    }

    private func candidates(for correct: FaultType) -> [FaultType] {
        let pool: [FaultType]
        switch correct {
        case .wrongBreakerSize: pool = [.overloadedCable, .wrongCableSize, .shortCircuitLN]
        case .missingPE:        pool = [.earthLeakage, .reversedPolarity, .missingRCD]
        case .earthLeakage:     pool = [.missingRCD, .missingPE, .nuisanceRCDTrip]
        default:                pool = [.missingPE, .earthLeakage, .wrongBreakerSize]
        }
        var set = [correct] + pool.filter { $0 != correct }.prefix(3)
        set = Array(Set(set))
        return set.sorted { $0.georgian < $1.georgian }
    }

    // MARK: d) repair (data-driven from mission.fix; FaultEngine.fixResolves verifies)
    private func repairStep(_ m: FaultMission) -> some View {
        let faulted = faultedBoard(m)
        let opts = repairOptions(m)
        return List {
            Section("აირჩიე შესწორება") {
                ForEach(opts.indices, id: \.self) { i in
                    let opt = opts[i]
                    Button {
                        if FaultEngine.fixResolves(faulted: faulted, fix: opt.edit) {
                            feedback = nil
                            outcome = game.completeFault(m)
                            step = .done
                        } else {
                            feedback = "ამ ქმედებამ დეფექტი ვერ გადაჭრა — სცადე სხვა."
                        }
                    } label: {
                        Label(opt.label, systemImage: "wrench.adjustable")
                    }
                    .buttonStyle(.plain)
                }
            }
            if let feedback {
                Section { Text(feedback).font(.caption).foregroundStyle(.red) }
            }
        }
    }

    private func repairOptions(_ m: FaultMission) -> [(label: String, edit: BoardEdit)] {
        let brk = faultedBoard(m).components.first { $0.kind == .mcb }?.id
        var opts: [(String, BoardEdit)] = [(describeFix(m.fix), m.fix)]
        switch m.faultType {
        case .wrongBreakerSize:
            if let brk { opts.append(("ავტომატის შეცვლა 25A-ით", BoardEdit(setRatingA: [brk: 25]))) }
            opts.append(("მხოლოდ კაბელის დათვალიერება", BoardEdit()))
        case .missingPE:
            opts.append(("ნულის ხელახლა მიერთება", BoardEdit()))
            if let brk { opts.append(("ავტომატის გაზრდა 40A-მდე", BoardEdit(setRatingA: [brk: 40]))) }
        case .earthLeakage:
            if let brk { opts.append(("ავტომატის გაზრდა 40A-მდე", BoardEdit(setRatingA: [brk: 40]))) }
            opts.append(("მხოლოდ RCD-ის ხელახლა ჩართვა", BoardEdit()))
        default:
            opts.append(("სხვა ქმედება", BoardEdit()))
        }
        return opts
    }

    private func describeFix(_ fix: BoardEdit) -> String {
        if let r = fix.setRatingA?.values.first { return "ავტომატის შეცვლა \(Int(r))A-ით" }
        if fix.addWires != nil { return "დამცავი მიწის (PE) სადენის დამატება" }
        if let l = fix.setLeakageMa, l.values.contains(0) { return "გაუმართავი მოწყობილობის გამოცვლა" }
        return "შესწორების გამოყენება"
    }

    // MARK: e/f) verify + complete
    private func doneView(_ m: FaultMission) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(.green)
                    VStack(alignment: .leading) {
                        Text("დეფექტი აღმოფხვრილია! 🎉").font(.headline)
                        Text("ფარი გადამოწმდა — დენი აღდგა, დაცვა მუშაობს, PE მართებულია.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let o = outcome {
                Section("ჯილდო") {
                    Label("+\(o.xp) XP", systemImage: "star.fill").foregroundStyle(.orange)
                    Label("+\(o.cash) ₾", systemImage: "banknote").foregroundStyle(.green)
                    if o.rankedUp {
                        Label("ახალი წოდება: \(o.rankAfter.georgian)", systemImage: "rosette").foregroundStyle(.brand)
                    }
                    if !o.awarded {
                        Text("ეს მისია უკვე დასრულებული იყო — ჯილდო აღარ მეორდება.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                primaryButton("მისიების სია →", "list.bullet") {
                    if !path.isEmpty { path.removeLast() }
                }
            }
        }
    }

    // MARK: building blocks
    private func labeled(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v) }.font(.callout)
    }
    private func primaryButton(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).frame(maxWidth: .infinity).font(.headline)
        }
        .buttonStyle(.borderedProminent).tint(.brand)
        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
    }
}
