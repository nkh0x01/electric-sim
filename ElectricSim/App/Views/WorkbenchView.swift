//
//  WorkbenchView.swift
//  ElectricSim
//
//  მთავარი სამუშაო ეკრანი: DIN rail ფარი, კომპონენტების პალიტრა,
//  სადენების დახაზვა (terminal → terminal), ხელსაწყოები და „ჩართე ძაბვა".
//

import SwiftUI

// MARK: - Tools

enum Tool: String, CaseIterable, Identifiable {
    case wire, multimeter, voltageTester, stripper, screwdriver
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wire:          return "სადენი"
        case .multimeter:    return "მულტიმეტრი"
        case .voltageTester: return "ფაზის ინდიკატორი"
        case .stripper:      return "გამცლელი"
        case .screwdriver:   return "სახრახნისი"
        }
    }
    var symbol: String {
        switch self {
        case .wire:          return "cable.connector"
        case .multimeter:    return "gauge.with.dots.needle.bottom.50percent"
        case .voltageTester: return "bolt.badge.checkmark"
        case .stripper:      return "scissors"
        case .screwdriver:   return "screwdriver"
        }
    }
    var hint: String {
        switch self {
        case .wire:          return "შეეხე ორ ფეხს — დაიხაზება სადენი (ფერი ავტომატურად)."
        case .multimeter:    return "შეეხე ორ წერტილს — გაზომავს ძაბვას."
        case .voltageTester: return "შეეხე ფეხს — შეამოწმებს ფაზას."
        case .stripper:      return "სადენის იზოლაციის გაცლა (მონტაჟამდე)."
        case .screwdriver:   return "ფეხის (terminal) მოჭერა."
        }
    }
}

// MARK: - Model

@MainActor
final class WorkbenchModel: ObservableObject {
    let level: Level
    @Published var templates: [String: ComponentTemplate]
    private let solver = CircuitSolver()

    @Published var board: Board
    @Published var placedCounts: [String: Int] = [:]
    @Published var tool: Tool = .wire
    @Published var selectedPort: String?
    @Published var selectedCSA: Double
    @Published var selectedCable: CableType = .copper
    @Published var selectedConductorType: ConductorType = .solid
    @Published var selectedLengthM: Double = 10
    @Published var selection: Set<String> = []       // მონიშნული კომპონენტები (group move)
    @Published var selectMode = false
    @Published var result: SimulationResult?
    @Published var showResult = false
    @Published var levelPassed = false
    @Published var measurement: String?
    @Published var liveAnalysis: NetAnalysis?
    @Published var showWires = false
    @Published var careerOutcome: CareerOutcome?   // career-job: ჯილდო შედეგისთვის
    let careerJob: Job?                              // nil → ჩვეულებრივი Learn დონე
    private var didConfigure = false

    init(level: Level, templates: [String: ComponentTemplate], careerJob: Job? = nil) {
        self.level = level
        self.templates = templates
        self.careerJob = careerJob
        var b = Board(phase: level.phase)
        b.add(ComponentFactory.supply(id: "supply", phase: level.phase))
        self.board = b
        self.selectedCSA = level.palette.compactMap { $0.csaOptions?.first }.first ?? 1.5
    }

    /// დონის რეალურ კომპონენტებთან კონფიგურაცია (templates ხელმისაწვდომია onAppear-ზე).
    /// faultFind დონეებზე აშენებს წინასწარ აწყობილ, დეფექტიან ფარს.
    private var startedAt = Date()
    private(set) var mistakes = 0

    func configure(_ t: [String: ComponentTemplate]) {
        templates = t
        guard !didConfigure else { return }
        didConfigure = true
        board = level.initialBoard(templates: t)
        startedAt = Date()
        mistakes = 0
        resetResult()
    }

    func deleteWire(_ id: String) {
        board.wires.removeAll { $0.id == id }
        resetResult()
    }

    func placed(_ tid: String) -> Int { placedCounts[tid] ?? 0 }
    func canAdd(_ e: PaletteEntry) -> Bool { placed(e.templateId) < e.max }

    func add(_ e: PaletteEntry) {
        guard let t = templates[e.templateId], canAdd(e) else { return }
        let n = placed(e.templateId)
        let inst = t.makeComponent(instanceID: "\(e.templateId)_\(n + 1)", phase: board.phase)
        board.add(inst)
        placedCounts[e.templateId] = n + 1
        resetResult()
    }

    func removeComponent(_ id: String) {
        guard id != "supply" else { return }
        if let comp = board.components.first(where: { $0.id == id }) {
            let portIDs = Set(comp.ports.map { $0.id })
            board.wires.removeAll { portIDs.contains($0.fromPortID) || portIDs.contains($0.toPortID) }
        }
        board.components.removeAll { $0.id == id }
        if let tid = templates.keys.first(where: { id.hasPrefix($0 + "_") }) {
            placedCounts[tid] = max(0, (placedCounts[tid] ?? 1) - 1)
        }
        resetResult()
    }

    func removeLastWire() { if !board.wires.isEmpty { board.wires.removeLast(); resetResult() } }
    func clearWires() { board.wires.removeAll(); resetResult() }

    func resetResult() { result = nil; showResult = false; liveAnalysis = nil }

    func tapPort(_ id: String) {
        measurement = nil
        switch tool {
        case .wire, .stripper, .screwdriver:
            if let sel = selectedPort {
                if sel == id { selectedPort = nil }
                else { addWire(from: sel, to: id); selectedPort = nil }
            } else {
                selectedPort = id
            }
        case .multimeter:
            if let sel = selectedPort {
                let v = solver.measureVoltage(board, sel, id)
                measurement = "მულტიმეტრი: \(Int(v)) V"
                selectedPort = nil
            } else {
                selectedPort = id
                measurement = "აირჩიე მეორე წერტილი…"
            }
        case .voltageTester:
            measurement = solver.isLive(board, id) ? "⚡️ ფაზაა (ცხელი)" : "ფაზა არ არის"
            selectedPort = nil
        }
    }

    /// საჯარო — drag-ით ხაზვისთვის (terminal → terminal).
    func connectPorts(_ from: String, _ to: String) { addWire(from: from, to: to) }

    private func addWire(from: String, to: String) {
        guard from != to else { return }
        if board.wires.contains(where: {
            ($0.fromPortID == from && $0.toPortID == to) ||
            ($0.fromPortID == to && $0.toPortID == from)
        }) { return }
        let conductor = board.port(from)?.conductor ?? board.port(to)?.conductor ?? .L
        board.connect(from, to, csaMm2: selectedCSA, color: WireColor.standard(for: conductor),
                      cableType: selectedCable, conductorType: selectedConductorType,
                      lengthM: selectedLengthM)
        resetResult()
    }

    // MARK: კომპონენტების მონიშვნა და გადაადგილება (DIN rail reorder)

    func toggleSelect(_ id: String) {
        guard id != "supply" else { return }
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        selectMode = !selection.isEmpty
    }

    func clearSelection() { selection.removeAll(); selectMode = false }

    /// გადააადგილებს კომპონენტ(ებ)-ს რიგში `shift` პოზიციით (busbar-ის ვიზუალური რიგი).
    func moveComponents(_ ids: Set<String>, by shift: Int) {
        guard shift != 0, !ids.isEmpty else { return }
        var comps = board.components
        let moving = comps.filter { ids.contains($0.id) }
        guard !moving.isEmpty,
              let firstIdx = comps.firstIndex(where: { ids.contains($0.id) }) else { return }
        comps.removeAll { ids.contains($0.id) }
        let target = max(0, min(comps.count, firstIdx + shift))
        comps.insert(contentsOf: moving, at: target)
        board.components = comps
        resetResult()
    }

    /// ერთი კომპონენტის გადატანა სხვა პოზიციაზე/რიგზე — მოთავსდება `anchorID`-ის
    /// წინ/შემდეგ board.components-ში (რიგები ამ რიგიდან გამოითვლება wrapping-ით).
    func moveComponent(_ id: String, relativeTo anchorID: String, after: Bool) {
        guard id != anchorID,
              let comp = board.components.first(where: { $0.id == id }) else { return }
        var comps = board.components
        comps.removeAll { $0.id == id }
        guard let aIdx = comps.firstIndex(where: { $0.id == anchorID }) else { return }
        let target = max(0, min(comps.count, after ? aIdx + 1 : aIdx))
        comps.insert(comp, at: target)
        board.components = comps
        resetResult()
    }

    func check() {
        var r = solver.solve(board, energize: false)
        if level.isPanelAssembly { r.issues.append(contentsOf: PanelAssembly.validate(board)) }
        if !r.passed { mistakes += 1 }
        result = r
        liveAnalysis = nil
        showResult = true
    }

    func powerOn(game: GameState) {
        var r = solver.solve(board, energize: true)
        if level.isPanelAssembly { r.issues.append(contentsOf: PanelAssembly.validate(board)) }
        result = r
        liveAnalysis = solver.analyze(board)
        showResult = true
        game.noteSimulation(level: level, result: r)
        if level.resolvedMode != .sandbox && goalMet(r) {
            levelPassed = true
            if let job = careerJob {
                // Career: ჯილდო ერთხელ (CareerState იცავს დუბლირებას) — markCompleted/GameCenter არა.
                careerOutcome = game.completeJob(job)
            } else {
                game.markCompleted(level)
                let seconds = Int(Date().timeIntervalSince(startedAt))
                GameCenterManager.shared.recordCompletion(level: level, seconds: seconds, mistakes: mistakes)
            }
        } else if !r.passed {
            mistakes += 1
        }
    }

    func goalMet(_ r: SimulationResult) -> Bool {
        guard r.passed else { return false }
        if level.goal.requireBalanced == true,
           r.issues.contains(where: { $0.code == .phaseImbalance }) {
            return false
        }
        for (kindStr, count) in level.goal.poweredLoads {
            guard let kind = ComponentKind(rawValue: kindStr) else { return false }
            let lit = board.components
                .filter { $0.kind == kind }
                .filter { r.state(for: $0.id)?.isPowered == true }
                .count
            if lit < count { return false }
        }
        return true
    }

    func isLive(_ portID: String) -> Bool {
        (liveAnalysis?.portConductors[portID] ?? []).contains { $0.isHot }
    }

    var csaOptions: [Double] {
        let all = level.palette.compactMap { $0.csaOptions }.flatMap { $0 }
        return all.isEmpty ? [1.5, 2.5, 4, 6, 10] : Array(Set(all)).sorted()
    }
}

// MARK: - Port frame preference (ფეხების კოორდინატები "board" სივრცეში)

struct PortFrameKey: PreferenceKey {
    static let defaultValue: [String: CGPoint] = [:]
    static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
        value.merge(nextValue()) { $1 }
    }
}

/// კომპონენტის ბარათის ჩარჩო "board" სივრცეში — გადაადგილების hit-test-ისთვის.
struct CardFrameKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// "board" — საერთო კოორდინატთა სივრცე drag-ისა და ფეხების პოზიციებისთვის.
let kBoardSpace = "board"

/// ფარზე ერთიანი drag-ის რეჟიმი.
enum BoardDragMode { case none, wire, move, pan }

// MARK: - Workbench view

struct WorkbenchView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    @StateObject private var model: WorkbenchModel
    @Binding var path: [String]
    @State private var showHint = false
    @State private var showReports = false
    @State private var showPaywall = false
    // ფარის ჟესტები (board სივრცე)
    @State private var portPoints: [String: CGPoint] = [:]
    @State private var componentFrames: [String: CGRect] = [:]
    @State private var dragMode: BoardDragMode = .none
    @State private var dragFrom: String?
    @State private var moveID: String?
    @State private var dragCurrent: CGPoint = .zero
    @State private var isZooming = false
    @State private var railWidth: CGFloat = 0   // ეკრანის სიგანე — რიგზე ბარათების რაოდენობისთვის

    // MARK: მრავალრიგიანი DIN რელსი
    /// რამდენი ბარათი ეტევა ერთ რიგზე (ადაპტირდება სიგანეზე; ცარიელ ფარზე 4).
    private var cardsPerRow: Int {
        let cellW: CGFloat = 132
        guard railWidth > 0 else { return 4 }
        return max(3, min(8, Int((railWidth - 80) / cellW)))
    }
    /// board.components დაყოფილი რიგებად (wrapping).
    private var rows: [[Component]] {
        let comps = model.board.components
        let n = max(1, cardsPerRow)
        return stride(from: 0, to: comps.count, by: n).map {
            Array(comps[$0 ..< min($0 + n, comps.count)])
        }
    }
    /// drop წერტილთან უახლოესი (სხვა) ბარათი + მისი წინ/შემდეგ — რიგზე/რიგებს შორის გადასატანად.
    private func dropAnchor(for id: String, at p: CGPoint) -> (anchor: String, after: Bool)? {
        var best: String?; var bestD = CGFloat.greatestFiniteMagnitude; var bestMidX: CGFloat = 0
        for (cid, f) in componentFrames where cid != id {
            let d = hypot(f.midX - p.x, f.midY - p.y)
            if d < bestD { bestD = d; best = cid; bestMidX = f.midX }
        }
        guard let anchor = best else { return nil }
        return (anchor, p.x > bestMidX)
    }

    /// პალიტრის ელემენტი ჩაკეტილია თუ არა. ფასიანობა იმართება დონის tier-ით —
    /// გახსნილი დონის მთელი პალიტრა ხელმისაწვდომია (იხ. ComponentGating).
    private func isPaletteLocked(_ e: PaletteEntry) -> Bool {
        guard !store.isPro else { return false }
        return !ComponentGating.isPaletteEntryAvailableForFree(e, templates: model.templates)
    }

    // MARK: პალიტრის დაჯგუფება კატეგორიებად
    private func paletteCategory(_ e: PaletteEntry) -> ComponentCategory {
        model.templates[e.templateId]?.resolvedCategory ?? .auxiliary
    }
    /// დონის პალიტრაში წარმოდგენილი კატეგორიები, რიგით.
    private var paletteCategories: [ComponentCategory] {
        var seen: [ComponentCategory] = []
        for e in model.level.palette {
            let c = paletteCategory(e)
            if !seen.contains(c) { seen.append(c) }
        }
        return seen.sorted { $0.order < $1.order }
    }
    private func paletteEntries(in category: ComponentCategory) -> [PaletteEntry] {
        model.level.palette.filter { paletteCategory($0) == category }
    }

    @ViewBuilder
    private func paletteCard(_ e: PaletteEntry) -> some View {
        let t = model.templates[e.templateId]
        let locked = isPaletteLocked(e)
        Button {
            if locked { showPaywall = true } else { model.add(e) }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: locked ? "lock.fill" : (t?.kind ?? .mcb).sfSymbol)
                Text(t?.name ?? e.templateId).font(.caption2).lineLimit(1)
                if locked {
                    Text("paywall_locked_badge")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.brand, in: Capsule())
                        .foregroundStyle(.white)
                } else {
                    Text("\(model.placed(e.templateId))/\(e.max)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .frame(width: 96)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(!locked && !model.canAdd(e))
        .opacity(locked ? 0.85 : (model.canAdd(e) ? 1 : 0.4))
    }

    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinch: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @GestureState private var panLive: CGSize = .zero

    init(level: Level, path: Binding<[String]>) {
        _path = path
        _model = StateObject(wrappedValue: WorkbenchModel(level: level, templates: [:]))
    }

    /// Career-სამუშაო: workbench იხსნება job-ის დონით (componentsAvailable + goal).
    init(job: Job, path: Binding<[String]>) {
        _path = path
        _model = StateObject(wrappedValue: WorkbenchModel(level: job.makeLevel(),
                                                          templates: [:], careerJob: job))
    }

    // MARK: კოორდინატები (screen/container → board, scale/offset-ის გათვალისწინებით)
    private func toBoard(_ p: CGPoint) -> CGPoint {
        let z = max(zoom, 0.01)
        return CGPoint(x: (p.x - pan.width) / z, y: (p.y - pan.height) / z)
    }
    private func nearestPort(to p: CGPoint, excluding: String?) -> String? {
        var best: String?; var bestD = CGFloat.greatestFiniteMagnitude
        for (pid, pt) in portPoints where pid != excluding {
            let d = hypot(pt.x - p.x, pt.y - p.y)
            if d < bestD { bestD = d; best = pid }
        }
        return bestD <= 36 ? best : nil   // snap threshold (board units)
    }
    private func componentAt(_ p: CGPoint) -> String? {
        // 1) ზუსტი ბარათის ჩარჩო (CardFrameKey), თუ preference უკვე გავრცელდა.
        if let hit = componentFrames.first(where: { $0.value.contains(p) })?.key {
            return hit
        }
        // 2) Fallback — ფეხების პოზიციებიდან აგებული რეგიონი. portPoints სანდოა
        //    (იმავე "board" სივრცეშია, რასაც სადენის დახაზვა იყენებს — და ის მუშაობს).
        return componentByPortBounds(p)
    }

    /// კომპონენტის სხეულის რეგიონი მისი ფეხების bounding-box-იდან, ზევით გაფართოებული
    /// (header/სურათი ფეხებზე მაღლაა). ეს არ არის დამოკიდებული CardFrameKey-ზე.
    private func componentByPortBounds(_ p: CGPoint) -> String? {
        var bestID: String?
        var bestDist = CGFloat.greatestFiniteMagnitude
        for comp in model.board.components {
            let pts = comp.ports.compactMap { portPoints[$0.id] }
            guard !pts.isEmpty else { continue }
            let xs = pts.map(\.x), ys = pts.map(\.y)
            let minX = xs.min()!, maxX = xs.max()!
            let minY = ys.min()!, maxY = ys.max()!
            // header/სხეული ფეხებზე ზემოთ → ზევით მეტი მარჟა.
            let region = CGRect(x: minX - 28, y: minY - 92,
                                width: (maxX - minX) + 56, height: (maxY - minY) + 120)
            if region.contains(p) {
                let d = hypot(region.midX - p.x, region.midY - p.y)
                if d < bestDist { bestDist = d; bestID = comp.id }
            }
        }
        return bestID
    }

    // MARK: ფარის ერთიანი drag — wire / move / pan (mode იწყობა საწყისი წერტილით).
    private var boardDrag: some Gesture {
        DragGesture(minimumDistance: 6)
            .updating($panLive) { v, st, _ in if dragMode == .pan { st = v.translation } }
            .onChanged { v in
                if dragMode == .none {
                    if isZooming { return }   // pinch-ის დროს pan არ ვიწყოთ
                    let b = toBoard(v.startLocation)
                    if model.tool == .wire, let p = nearestPort(to: b, excluding: nil) {
                        dragMode = .wire; dragFrom = p              // ფეხზე → სადენი
                    } else if let cid = componentAt(b) {
                        dragMode = .move; moveID = cid              // კომპონენტის სხეულზე → გადატანა
                    } else {
                        dragMode = .pan                            // ცარიელზე → პანი
                    }
                    #if DEBUG
                    print("[boardDrag] mode=\(dragMode) start(board)=\(b) "
                        + "cardFrames=\(componentFrames.count) ports=\(portPoints.count) "
                        + "moveID=\(moveID ?? "-")")
                    #endif
                }
                if dragMode == .wire { dragCurrent = toBoard(v.location) }
            }
            .onEnded { v in
                switch dragMode {
                case .wire:
                    if let from = dragFrom,
                       let t = nearestPort(to: toBoard(v.location), excluding: from) {
                        model.connectPorts(from, t)                // snap target / არადა cancel
                    }
                case .move:
                    if let id = moveID {
                        if model.selection.contains(id) && model.selection.count > 1 {
                            // ჯგუფი — ჰორიზონტალური shift (არსებული ქცევა)
                            let shift = Int((v.translation.width / (140 * max(zoom, 0.01))).rounded())
                            model.moveComponents(model.selection, by: shift)
                        } else if let drop = dropAnchor(for: id, at: toBoard(v.location)) {
                            // ერთი კომპონენტი — ნებისმიერ რიგზე/პოზიციაზე (drop-თან უახლოეს ბარათთან).
                            model.moveComponent(id, relativeTo: drop.anchor, after: drop.after)
                        }
                    }
                case .pan:
                    pan.width += v.translation.width; pan.height += v.translation.height
                case .none: break
                }
                dragMode = .none; dragFrom = nil; moveID = nil
            }
    }

    // MARK: pinch zoom (2 თითი) — drag-თან simultaneous
    private var boardZoom: some Gesture {
        MagnificationGesture()
            .updating($pinch) { v, st, _ in st = v }
            .onChanged { _ in isZooming = true }
            .onEnded { v in zoom = min(max(zoom * v, 0.3), 3.0); isZooming = false }
    }

    // MARK: next destination (Learn დონე ან Career სამუშაო) + Pro gating
    private var nextLevelID: String? {
        let camp = game.campaignLevels
        guard let idx = camp.firstIndex(where: { $0.id == model.level.id }) else { return nil }
        let n = idx + 1
        return n < camp.count ? camp[n].id : nil
    }
    /// (route, locked) — route ემატება/ანაცვლებს path-ის ბოლოს.
    private func nextDestination() -> (route: String, locked: Bool)? {
        if let job = model.careerJob {
            let jobs = game.jobs
            guard let idx = jobs.firstIndex(where: { $0.id == job.id }), idx + 1 < jobs.count else { return nil }
            let nj = jobs[idx + 1]
            return ("jobwork:\(nj.id)", game.career.isProLocked(nj, isPro: store.isPro))
        } else {
            guard let nid = nextLevelID, let next = game.level(byID: nid) else { return nil }
            return (nid, game.isProLocked(next, isPro: store.isPro))
        }
    }
    private var hasNext: Bool { nextDestination() != nil }

    private func goNext() {
        model.showResult = false
        guard let dest = nextDestination() else { backToMenu(); return }
        if dest.locked { showPaywall = true; return }
        if path.isEmpty { path = [dest.route] } else { path[path.count - 1] = dest.route }
    }
    /// უკან სიაში/ბორდზე დაბრუნება (workbench-ის pop). მენიუ ახლა root-ია.
    private func backToMenu() {
        // Learn: პროგრესის უსაფრთხო შენახვა (career-ს markCompleted არ სჭირდება).
        if model.careerJob == nil, model.levelPassed { game.markCompleted(model.level) }
        model.showResult = false
        if !path.isEmpty { path.removeLast() }
    }

    var body: some View {
        VStack(spacing: 0) {
            briefBar
            railView
            if let m = model.measurement {
                Text(m)
                    .font(.callout.bold())
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.2))
            }
            Divider()
            controls
        }
        .navigationTitle(model.level.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showReports = true } label: { Image(systemName: "chart.bar.doc.horizontal") }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showHint = true } label: { Image(systemName: "questionmark.circle") }
            }
        }
        .sheet(isPresented: $showReports) {
            NavigationStack {
                ReportsView(board: model.board)
                    .environmentObject(store)
                    .environmentObject(game)
            }
        }
        .onAppear { model.configure(game.templates) }
        .sheet(isPresented: $model.showResult) {
            if let r = model.result {
                ResultPanelView(result: r, passed: model.levelPassed, level: model.level,
                                hasNext: hasNext,
                                onNext: { goNext() },
                                onBackToMenu: { backToMenu() },
                                careerReward: model.careerOutcome)
            }
        }
        .sheet(isPresented: $model.showWires) {
            WiresListView(model: model)
        }
        .alert("მინიშნება", isPresented: $showHint) {
            Button("გასაგებია", role: .cancel) {}
        } message: { Text(model.level.hint) }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }

    private var briefBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.level.resolvedMode == .faultFind {
                Label("დეფექტის ძებნა — იპოვე და გაასწორე ხარვეზი", systemImage: "magnifyingglass")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            if model.level.isPanelAssembly {
                Label("ფარის აწყობა — დაიცავი თანმიმდევრობა: მთავარი → SPD → RCD → ავტომატები (ზოლით)",
                      systemImage: "rectangle.3.group")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
            Text(model.level.brief)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private var railView: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
            boardContent
                .scaleEffect(zoom * pinch, anchor: .topLeading)
                .offset(x: pan.width + panLive.width, y: pan.height + panLive.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { railWidth = g.size.width }
                .onChange(of: g.size.width) { railWidth = $0 }
        })
        .contentShape(Rectangle())
        .clipped()
        // ერთიანი drag (wire/move/pan) + pinch zoom — ორივე simultaneous, არ ეჯახება.
        .simultaneousGesture(boardDrag)
        .simultaneousGesture(boardZoom)
        .overlay(alignment: .bottomTrailing) { zoomControls }
    }

    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            let layout = rows
            ForEach(layout.indices, id: \.self) { r in
                HStack(alignment: .top, spacing: 28) {
                    ForEach(layout[r]) { comp in
                        ComponentCardView(
                            component: comp,
                            selectedPort: model.selectedPort,
                            loadState: model.result?.state(for: comp.id),
                            isSelected: model.selection.contains(comp.id),
                            isLive: { model.isLive($0) },
                            onTapPort: { model.tapPort($0) },
                            onLongPress: { model.toggleSelect(comp.id) },
                            onDelete: comp.id == "supply" ? nil : { model.removeComponent(comp.id) }
                        )
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 12)
                .background(dinRailBackground)
            }
        }
        .padding(40)
        .coordinateSpace(name: kBoardSpace)
        .overlay { wireOverlay }
        .onPreferenceChange(PortFrameKey.self) { portPoints = $0 }
        .onPreferenceChange(CardFrameKey.self) { componentFrames = $0 }
    }

    /// DIN რელსის ვიზუალი (თითო რიგის ფონი + ცენტრალური ლითონის ზოლი).
    private var dinRailBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.10))
            .overlay(alignment: .center) {
                Rectangle().fill(Color.gray.opacity(0.28)).frame(height: 3)
            }
    }

    private var wireOverlay: some View {
        ZStack {
            ForEach(model.board.wires) { wire in
                if let a = portPoints[wire.fromPortID], let b = portPoints[wire.toPortID] {
                    Path { p in p.move(to: a); p.addLine(to: b) }
                        .stroke(wire.color.swiftUIColor, style: wireStroke(wire.conductorType))
                }
            }
            if let from = dragFrom, let a = portPoints[from] {
                Path { p in p.move(to: a); p.addLine(to: dragCurrent) }
                    .stroke(Color.gray.opacity(0.7),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 4]))
            }
        }
        .allowsHitTesting(false)   // არ ბლოკავს ფეხების/ბარათების ჟესტებს
    }

    /// ხისტი = მუდმივი ხაზი; მრავალწვერა = ოდნავ სქელი + ზოლიანი (striped).
    private func wireStroke(_ c: ConductorType) -> StrokeStyle {
        c == .stranded
        ? StrokeStyle(lineWidth: 5, lineCap: .round, dash: [5, 3])
        : StrokeStyle(lineWidth: 4, lineCap: .round)
    }

    private var zoomControls: some View {
        VStack(spacing: 6) {
            Button { zoom = min(zoom + 0.2, 3.0) } label: { zoomIcon("plus.magnifyingglass") }
            Button { zoom = max(zoom - 0.2, 0.3) } label: { zoomIcon("minus.magnifyingglass") }
            Button { zoom = 1.0; pan = .zero } label: { zoomIcon("scope") }
        }
        .padding(8)
    }

    private func zoomIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.title3)
            .frame(width: 38, height: 38)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.25)))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            // ხელსაწყოები
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Tool.allCases) { t in
                        Button { model.tool = t; model.selectedPort = nil } label: {
                            Label(t.title, systemImage: t.symbol)
                                .font(.caption2)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(model.tool == t ? Color.yellow.opacity(0.3) : Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }.padding(.horizontal)
            }

            Text(model.tool.hint).font(.caption2).foregroundStyle(.secondary)

            // კომპონენტების პალიტრა — დაჯგუფებული კატეგორიებად (data-driven)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(paletteCategories, id: \.self) { cat in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cat.georgian)
                                .font(.caption2.bold()).foregroundStyle(.secondary)
                                .padding(.leading, 2)
                            HStack(spacing: 8) {
                                ForEach(paletteEntries(in: cat)) { e in paletteCard(e) }
                            }
                        }
                        if cat != paletteCategories.last {
                            Divider().frame(height: 78)
                        }
                    }
                }.padding(.horizontal)
            }

            // კაბელის კვეთა
            HStack {
                Text("cable_section_label").font(.caption)
                Picker("cable_section_label", selection: $model.selectedCSA) {
                    ForEach(model.csaOptions, id: \.self) { csa in
                        Text("\(csa, specifier: "%.1f")mm²").tag(csa)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                Button { model.showWires = true } label: {
                    Label("\(model.board.wires.count)", systemImage: "list.bullet")
                }
                Button { model.removeLastWire() } label: { Image(systemName: "arrow.uturn.backward") }
                Button(role: .destructive) { model.clearWires() } label: { Image(systemName: "trash") }
            }.padding(.horizontal)

            // კაბელის მასალა (Cu/Al) + ძარღვის ტიპი (ხისტი/მრავალწვერა)
            HStack(spacing: 10) {
                Picker("მასალა", selection: $model.selectedCable) {
                    Text("Cu").tag(CableType.copper)
                    Text("Al").tag(CableType.aluminum)
                }
                .pickerStyle(.segmented)
                .frame(width: 88)
                Picker("ძარღვი", selection: $model.selectedConductorType) {
                    Text("cable_type_solid").tag(ConductorType.solid)
                    Text("cable_type_stranded").tag(ConductorType.stranded)
                }
                .pickerStyle(.segmented)
            }.padding(.horizontal)

            // სიგრძე (ΔU%-სთვის)
            Stepper("სიგრძე: \(Int(model.selectedLengthM))მ",
                    value: $model.selectedLengthM, in: 0...100, step: 5)
                .font(.caption)
                .padding(.horizontal)

            // მოქმედებები
            HStack(spacing: 12) {
                Button { model.check() } label: {
                    Label("შემოწმება", systemImage: "checkmark.seal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("check")

                Button { model.powerOn(game: game) } label: {
                    Label("ჩართე ძაბვა", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .accessibilityIdentifier("power-on")
            }.padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }
}

// MARK: - Component card

struct ComponentCardView: View {
    let component: Component
    let selectedPort: String?
    let loadState: LoadState?
    let isSelected: Bool
    let isLive: (String) -> Bool
    let onTapPort: (String) -> Void
    let onLongPress: () -> Void
    let onDelete: (() -> Void)?

    private var inputs: [Port] { component.ports.filter { $0.side == .input } }
    private var outputs: [Port] { component.ports.filter { $0.side == .output } }
    private var singles: [Port] { component.ports.filter { $0.side == .single } }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(headerColor)
                    .frame(width: 92, height: 54)
                VStack(spacing: 2) {
                    if component.kind.hasArtwork {
                        Image(component.kind.assetName)
                            .resizable().scaledToFit().frame(height: 24)
                    } else {
                        Image(systemName: component.kind.sfSymbol)
                            .font(.title3)
                            .foregroundStyle(iconColor)
                    }
                    Text(component.name).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                }.padding(2)
            }
            .overlay(alignment: .topTrailing) {
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red).background(Circle().fill(.white))
                    }
                    .offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: .topLeading) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.brand).background(Circle().fill(.white))
                        .offset(x: -6, y: -6)
                }
            }

            HStack(alignment: .top, spacing: 14) {
                if !inputs.isEmpty { portColumn(inputs, label: "IN") }
                if !outputs.isEmpty { portColumn(outputs, label: "OUT") }
                if !singles.isEmpty { portColumn(singles, label: nil) }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemBackground)))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(isSelected ? Color.brand : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1))
        // ბარათის ჩარჩო board-სივრცეში (გადაადგილების hit-test).
        .background(GeometryReader { g in
            Color.clear.preference(key: CardFrameKey.self,
                                   value: [component.id: g.frame(in: .named(kBoardSpace))])
        })
        // გრძელი დაჭერა — მონიშვნა (group move). გადათრევას ამუშავებს ფარის ერთიანი ჟესტი.
        .onLongPressGesture(minimumDuration: 0.4) { onLongPress() }
    }

    private func portColumn(_ ports: [Port], label: String?) -> some View {
        VStack(spacing: 6) {
            if let label { Text(label).font(.system(size: 8)).foregroundStyle(.secondary) }
            ForEach(ports) { port in
                HStack(spacing: 4) {
                    portDot(port)
                    Text(port.name).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { onTapPort(port.id) }
            }
        }
    }

    private func portDot(_ port: Port) -> some View {
        let selected = selectedPort == port.id
        let live = isLive(port.id)
        return Circle()
            .fill(port.conductor.swiftUIColor)
            .frame(width: 16, height: 16)
            .overlay(Circle().stroke(selected ? Color.yellow : Color.white,
                                     lineWidth: selected ? 3 : 1))
            .overlay {
                if live {
                    Circle().stroke(Color.yellow, lineWidth: 2).blur(radius: 2)
                }
            }
            .background(GeometryReader { g in
                Color.clear.preference(
                    key: PortFrameKey.self,
                    value: [port.id: CGPoint(x: g.frame(in: .named(kBoardSpace)).midX,
                                             y: g.frame(in: .named(kBoardSpace)).midY)])
            })
    }

    private var headerColor: Color {
        if let st = loadState {
            if st.trip != nil { return Color.red.opacity(0.25) }
            if st.isPowered { return Color.yellow.opacity(0.45) }
        }
        return Color(.secondarySystemBackground)
    }

    private var iconColor: Color {
        if let st = loadState {
            if st.trip != nil { return .red }
            if st.isPowered { return .orange }
        }
        return component.kind == .supply ? .yellow : .primary
    }
}

// MARK: - Wires list (targeted deletion for fault-finding)

struct WiresListView: View {
    @ObservedObject var model: WorkbenchModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if model.board.wires.isEmpty {
                    Text("სადენები ჯერ არ არის.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.board.wires) { wire in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(wire.color.swiftUIColor)
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.gray.opacity(0.4)))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(label(wire.fromPortID))  →  \(label(wire.toPortID))")
                                    .font(.caption)
                                Text("\(wire.color.georgianName) · \(wire.csaMm2, specifier: "%.1f")mm² · \(wire.conductorType.georgianName)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                model.deleteWire(wire.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("სადენები")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("დახურვა") { dismiss() }
                }
            }
        }
    }

    private func label(_ portID: String) -> String {
        let comp = model.board.component(withPort: portID)
        let port = model.board.port(portID)
        return "\(comp?.name ?? "?") · \(port?.name ?? portID)"
    }
}
