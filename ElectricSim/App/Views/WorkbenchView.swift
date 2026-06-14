//
//  WorkbenchView.swift
//  ElectricSim
//
//  მთავარი სამუშაო ეკრანი: DIN rail ფარი, კომპონენტების პალიტრა,
//  სადენების დახაზვა (terminal → terminal), ხელსაწყოები და „ჩართე ძაბვა".
//

import SwiftUI
import AudioToolbox
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Haptics + sound feedback (ჩაჭდობა / მოჭერა)

/// მსუბუქი ფიზიკური უკუკავშირი: ჩაჭდობის „კლიკი" და მოჭერის „რაჭეტი".
/// ხმა ემორჩილება პარამეტრების pref.soundEnabled-ს (default ჩართული).
enum GameFeedback {
    private static var soundOn: Bool {
        UserDefaults.standard.object(forKey: "pref.soundEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "pref.soundEnabled")
    }
    /// DIN-რელსზე ჩაჭდობა — მყარი დარტყმა + მოკლე კლიკი.
    static func snap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
        if soundOn { AudioServicesPlaySystemSound(1104) }   // keyboard tock
    }
    /// კლემის მოჭერა — ორმაგი მსუბუქი იმპულსი (რაჭეტის შეგრძნება) + წკრიალი.
    static func ratchet() {
        #if canImport(UIKit)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { gen.impactOccurred(intensity: 0.7) }
        #endif
        if soundOn { AudioServicesPlaySystemSound(1103) }   // tink
    }
    /// ცემის (knockout) გახსნა — მკვეთრი პოპი + მოკლე კლიკი.
    static func tick() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        if soundOn { AudioServicesPlaySystemSound(1105) }   // tock pop
    }
}

// MARK: - DIN-მოდულის სტილი (Stage 2 — სტატიკური გრადიენტები, იაფი ხატვა)

/// რეალისტური მოდულის ფერები/გრადიენტები — ერთხელ შექმნილი სტატიკური მნიშვნელობები,
/// რომ დეტალური ხატვა pan/zoom-ზე იაფი დარჩეს (ანიმაცია მხოლოდ ბერკეტზე/ხრახნზე).
enum ModuleStyle {
    static let casing = LinearGradient(colors: [Color(white: 0.97), Color(white: 0.88)],
                                       startPoint: .top, endPoint: .bottom)
    static let body = LinearGradient(colors: [Color(red: 0.99, green: 0.98, blue: 0.95),
                                              Color(white: 0.87)],
                                     startPoint: .top, endPoint: .bottom)
    static let brass = LinearGradient(colors: [Color(red: 0.84, green: 0.71, blue: 0.38),
                                               Color(red: 0.60, green: 0.47, blue: 0.20)],
                                      startPoint: .top, endPoint: .bottom)
    static let screw = LinearGradient(colors: [Color(red: 0.92, green: 0.81, blue: 0.50),
                                               Color(red: 0.68, green: 0.54, blue: 0.25)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
    static let lever = LinearGradient(colors: [Color(white: 0.32), Color(white: 0.08)],
                                      startPoint: .top, endPoint: .bottom)
    static let rail = LinearGradient(colors: [Color(white: 0.88), Color(white: 0.58)],
                                     startPoint: .top, endPoint: .bottom)
    static let ferrule = LinearGradient(colors: [Color(white: 0.88), Color(white: 0.58)],
                                        startPoint: .leading, endPoint: .trailing)
}

/// კლემაში შესული სადენის ვიზუალური ინფო: იზოლაციის ფერი + ბუნიკი (sleeve).
struct TerminalWireInfo {
    let color: Color
    let ferruled: Bool
    let stranded: Bool
}

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
    // MARK: Live-wire safety
    @Published var energized = false               // ფარის კვება — სამუშაო სესიის ნაგულისხმევი OFF
    @Published var shockCount = 0                  // ამ სესიის შოკების რაოდენობა
    @Published var shockFlash = false              // წითელი ფლეში (transient)
    @Published var inspectNotice: String?          // „ჩართე კვება…" შეტყობინება (alert)
    private weak var gameRef: GameState?           // ჯარიმისთვის (Career cash)
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

    func configure(_ t: [String: ComponentTemplate], game: GameState) {
        templates = t
        gameRef = game
        guard !didConfigure else { return }
        didConfigure = true
        board = level.initialBoard(templates: t)
        enclosure = level.resolvedEnclosure
        assignDefaultRails()
        startedAt = Date()
        mistakes = 0
        resetResult()
    }

    // MARK: - Live-wire safety (de-energize before working)

    /// კვების გადართვა (მთავარი ამომრთველი / HUD toggle). ჩართვისას ფარი ცოცხალია
    /// და ჩუმი solve ანათებს მუშა წრედებს (ნათურები, როზეტები) — ფორმალური
    /// ინსპექციის (შედეგის ფურცლის) გარეშე. გამორთვა → ნეიტრალური ჩვენება.
    func togglePower() {
        energized.toggle()
        selectedPort = nil
        resetResult()   // ჩართულზე ჩუმი solve, გამორთულზე ნეიტრალური (იხ. resetResult)
    }

    /// ცოცხალი ფეხების ანალიზი — მხოლოდ ჩართულ ფარზე (გამორთულზე nil → არაფერი ცოცხალია).
    private func recomputeLive() {
        liveAnalysis = energized ? solver.analyze(board) : nil
    }

    /// ბერკეტის გადართვა — ავტომატი/RCD/მთავარი ჩაირთვება/გამოირთვება. გამორთული
    /// ღია კონტაქტია (დენი არ გადის). ცოცხალ ფარზეც დაშვებულია — ეს უსაფრთხო
    /// კომუტაციაა (ბერკეტი სწორედ რომ რთავს/თიშავს).
    func toggleDevice(_ id: String) {
        guard let idx = board.components.firstIndex(where: { $0.id == id }),
              board.components[idx].kind.isToggleable else { return }
        board.components[idx].isOpen.toggle()
        GameFeedback.snap()       // მექანიკური კლიკი
        resetResult()             // ჩართულზე ხელახლა solve → ნათება მაშინვე განახლდება
    }

    /// ცოცხალ ნაწილზე რედაქტირების მცველი. true → ქმედება დაბლოკილია (და დარეგისტრირდა შოკი).
    private func blockedByLiveEdit(_ ports: [String]) -> Bool {
        guard energized else { return false }
        let analysis = solver.analyze(board)
        guard LiveWire.isEditBlocked(energized: true, analysis: analysis, touchingPorts: ports) else { return false }
        registerShock()
        return true
    }

    /// შოკის მოვლენა — count++, წითელი ფლეში, გაფრთხილება და (Career/Fault) cash-ჯარიმა.
    private func registerShock() {
        shockCount += 1
        shockFlash = true
        if let job = careerJob {
            gameRef?.penalizeShock(LiveWire.shockPenalty(reward: job.cashReward))
        }
        let token = shockCount
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.shockCount == token else { return }
            self.shockFlash = false
        }
    }

    func deleteWire(_ id: String) {
        guard let w = board.wires.first(where: { $0.id == id }) else { return }
        if blockedByLiveEdit([w.fromPortID, w.toPortID]) { return }
        board.wires.removeAll { $0.id == id }
        resetResult()
    }

    /// სადენზე ბუნიკის (ferrule) დადება/მოხსნა — მრავალწვერა კაბელისთვის ხრახნიან კლემაში.
    func setFerrule(_ id: String, _ on: Bool) {
        guard let idx = board.wires.firstIndex(where: { $0.id == id }) else { return }
        board.wires[idx].ferruled = on
        resetResult()
    }

    func placed(_ tid: String) -> Int { placedCounts[tid] ?? 0 }
    func canAdd(_ e: PaletteEntry) -> Bool { placed(e.templateId) < e.max }

    /// აბრუნებს ახალი კომპონენტის id-ს (ჩაჭდობის პულსისთვის); ვერ-დამატებაზე nil.
    @discardableResult
    func add(_ e: PaletteEntry) -> String? {
        guard let t = templates[e.templateId], canAdd(e) else { return nil }
        // უნიკალური id ფარის მიხედვით (max+1) — count+1 წაშლის შემდეგ კოლიზიას იძლეოდა.
        let newID = board.nextInstanceID(forTemplate: e.templateId)
        let inst = t.makeComponent(instanceID: newID, phase: board.phase)
        board.add(inst)
        if inst.kind == .comb {
            // სავარცხელი — დაუყოვნებლივ ჯდება ავტომატების რანზე; ვერ ჩაჯდა → უკან.
            guard seatComb(newID) else {
                board.components.removeAll { $0.id == newID }
                inspectNotice = "სავარცხელს სჭირდება მინ. 2 მომიჯნავე ავტომატი ერთ რელსზე"
                return nil
            }
        } else if Self.isRailMounted(inst) {
            // ახალი მოდული — პირველი რელსი, რომელზეც სიგანის სლოტები თავისუფალია.
            let w = widthUnits(of: inst)
            guard let target = (0..<railCount).first(where: { railHasRoom($0, width: w) }) else {
                board.components.removeAll { $0.id == newID }
                inspectNotice = "რიგზე ადგილი აღარ არის"
                return nil
            }
            railOf[newID] = target
            // ახალი ავტომატი არსებული სავარცხელის რანის გვერდით → ხელახლა გადაჯდომა,
            // რომ comb ახალ მომიჯნავე ავტომატსაც მოედოს (დამატების რიგი აღარ აზიანებს).
            if inst.kind.isBreaker { reseatCombs() }
        }
        placedCounts[e.templateId] = placed(e.templateId) + 1
        resetResult()
        return newID
    }

    func removeComponent(_ id: String) {
        guard id != "supply" else { return }
        guard let comp = board.components.first(where: { $0.id == id }) else { return }
        if blockedByLiveEdit(comp.ports.map { $0.id }) { return }
        let portIDs = Set(comp.ports.map { $0.id })
        board.wires.removeAll { portIDs.contains($0.fromPortID) || portIDs.contains($0.toPortID) }
        board.components.removeAll { $0.id == id }
        railOf[id] = nil
        if let tid = templates.keys.first(where: { id.hasPrefix($0 + "_") }) {
            placedCounts[tid] = max(0, (placedCounts[tid] ?? 1) - 1)
        }
        reseatCombs()
        resetResult()
    }

    func removeLastWire() {
        // ბოლო მომხმარებლის სადენი — comb-ის ავტო-კბილებს არ ვეხებით.
        guard let w = userWires.last else { return }
        if blockedByLiveEdit([w.fromPortID, w.toPortID]) { return }
        board.wires.removeAll { $0.id == w.id }
        resetResult()
    }
    func clearWires() {
        let mine = userWires
        if blockedByLiveEdit(mine.flatMap { [$0.fromPortID, $0.toPortID] }) { return }
        let mineIDs = Set(mine.map(\.id))
        board.wires.removeAll { mineIDs.contains($0.id) }
        resetResult()
    }

    /// რედაქტირების შემდეგ ფორმალური შედეგი უქმდება. ჩართულ ფარზე ჩუმი solve
    /// განაახლებს ვიზუალს (ნათება/ბერკეტები რეალობას მიჰყვება); გამორთულზე — ნეიტრალური.
    func resetResult() {
        showResult = false
        if energized {
            var r = solver.solve(board, energize: true)
            if level.isPanelAssembly { r.issues.append(contentsOf: PanelAssembly.validate(board)) }
            result = r          // მხოლოდ ვიზუალისთვის — დასრულება/ჯილდო inspect()-შია
        } else {
            result = nil
        }
        recomputeLive()
    }

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
        if blockedByLiveEdit([from, to]) { return }
        let conductor = board.port(from)?.conductor ?? board.port(to)?.conductor ?? .L
        // ახალი ინტერაქტიული შეერთება მოუჭერელია — მოთამაშემ უნდა „დაშურუპოს".
        board.connect(from, to, csaMm2: selectedCSA, color: WireColor.standard(for: conductor),
                      cableType: selectedCable, conductorType: selectedConductorType,
                      lengthM: selectedLengthM, tightened: false)
        resetResult()
    }

    // MARK: - მოჭერა (screw-down)

    /// ფეხზე მიერთებული რომელიმე სადენი მოუჭერელია?
    func isPortUntightened(_ portID: String) -> Bool {
        board.wires.contains { !$0.tightened && ($0.fromPortID == portID || $0.toPortID == portID) }
    }

    /// ფეხის კლემის მოჭერა — ამ ფეხზე მისული ყველა სადენი მოჭერილად ითვლება.
    /// აბრუნებს true-ს, თუ რამე რეალურად მოიჭერა (feedback-ისთვის).
    @discardableResult
    func tightenPort(_ portID: String) -> Bool {
        var any = false
        for i in board.wires.indices
        where !board.wires[i].tightened
            && (board.wires[i].fromPortID == portID || board.wires[i].toPortID == portID) {
            board.wires[i].tightened = true
            any = true
        }
        if any { resetResult() }
        return any
    }

    var hasUntightened: Bool { board.wires.contains { !$0.tightened } }

    /// „ყველას მოჭერა" — ყველა მოუჭერელი შეერთება ერთიანად.
    func tightenAll() {
        guard hasUntightened else { return }
        for i in board.wires.indices { board.wires[i].tightened = true }
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
        if blockedByLiveEdit(board.components.filter { ids.contains($0.id) }.flatMap { $0.ports.map(\.id) }) { return }
        var comps = board.components
        let moving = comps.filter { ids.contains($0.id) }
        guard !moving.isEmpty,
              let firstIdx = comps.firstIndex(where: { ids.contains($0.id) }) else { return }
        comps.removeAll { ids.contains($0.id) }
        let target = max(0, min(comps.count, firstIdx + shift))
        comps.insert(contentsOf: moving, at: target)
        board.components = comps
        reseatCombs()   // ჯგუფურმა გადაადგილებამ შეიძლება სავარცხელის რანი დაარღვიოს
        resetResult()
    }

    /// ერთი კომპონენტის გადატანა სხვა პოზიციაზე/რიგზე — მოთავსდება `anchorID`-ის
    /// წინ/შემდეგ board.components-ში (რიგები ამ რიგიდან გამოითვლება wrapping-ით).
    func moveComponent(_ id: String, relativeTo anchorID: String, after: Bool) {
        guard id != anchorID,
              let comp = board.components.first(where: { $0.id == id }) else { return }
        if blockedByLiveEdit(comp.ports.map { $0.id }) { return }
        var comps = board.components
        comps.removeAll { $0.id == id }
        guard let aIdx = comps.firstIndex(where: { $0.id == anchorID }) else { return }
        let target = max(0, min(comps.count, after ? aIdx + 1 : aIdx))
        comps.insert(comp, at: target)
        board.components = comps
        resetResult()
    }

    // MARK: - კარადა + ფიქსირებული DIN-რელსები (Stage 3 → v1.1 Pro Panel)

    /// კომპონენტი → რელსის ინდექსი. დატვირთვები რელსზე არ ჯდება (ქვედა ზოლი).
    @Published var railOf: [String: Int] = [:]
    /// დონის კარადა (ზომა/მონტაჟი + გახსნილი ცემები) — runtime მდგომარეობა.
    @Published var enclosure: Enclosure = Enclosure(size: .m12)

    var railCount: Int { level.resolvedRailCount }
    /// მოდულების ტევადობა თითო რელსზე (კარადის ზომიდან).
    var modulesPerRow: Int { enclosure.modulesPerRow }

    /// მოდულის სიგანე სლოტებში (18მმ ერთეული).
    func widthUnits(of comp: Component) -> Int { comp.kind.moduleWidthUnits }

    /// მოდულის მარცხენა სლოტი — მარცხნივ ჩაწყობით (preceding წევრების ჯამური სიგანე).
    /// რეალური ფარივით ღრეჩოები არ რჩება; ღრეჩო = ცარიელი მოდული.
    func leadingSlot(of comp: Component) -> Int {
        let r = rail(of: comp)
        var acc = 0
        for m in railMembers(r) {
            if m.id == comp.id { return acc }
            acc += widthUnits(of: m)
        }
        return acc
    }
    /// რელსზე დაკავებული სლოტების ჯამი.
    func usedSlots(rail r: Int, excluding id: String? = nil) -> Int {
        railMembers(r).filter { $0.id != id }.reduce(0) { $0 + widthUnits(of: $1) }
    }
    /// რელსზე `width` სლოტი თავისუფალია (ტევადობის წესი — Core).
    func railHasRoom(_ r: Int, width: Int, excluding id: String? = nil) -> Bool {
        enclosure.rowHasRoom(usedSlots: usedSlots(rail: r, excluding: id), adding: width)
    }

    /// ცემის გახსნა/დახურვა (tap) — პოპ + ჰაპტიკა.
    func toggleKnockout(_ k: Knockout) {
        enclosure.toggle(k)
        GameFeedback.tick()
    }

    /// DIN-რელსზე მჯდომი მოწყობილობაა? (დატვირთვები ქვედა ზოლში იხატება)
    static func isRailMounted(_ c: Component) -> Bool { !c.kind.isLoad }

    func rail(of comp: Component) -> Int {
        min(max(railOf[comp.id] ?? 0, 0), railCount - 1)
    }

    /// რელსის წევრები board.components-ის რიგით (within-rail order). comb ცალკე იხატება.
    func railMembers(_ r: Int) -> [Component] {
        board.components.filter { Self.isRailMounted($0) && $0.kind != .comb && rail(of: $0) == r }
    }
    var loadStrip: [Component] { board.components.filter { $0.kind.isLoad } }
    var combs: [Component] { board.components.filter { $0.kind == .comb } }

    /// საწყისი განაწილება: რელს-მოწყობილობები მარცხნიდან ივსება, რიგ-რიგობით
    /// (კვება ზედა-მარცხნივ); რელსის ტევადობის ამოწურვისას — შემდეგ რელსზე.
    private func assignDefaultRails() {
        railOf.removeAll()
        let mounted = board.components.filter { Self.isRailMounted($0) && $0.kind != .comb }
        guard !mounted.isEmpty else { return }
        var cursor = Array(repeating: 0, count: railCount)   // ჯამური სიგანე თითო რელსზე
        var r = 0
        for comp in mounted {
            let w = widthUnits(of: comp)
            if cursor[r] + w > modulesPerRow && r < railCount - 1 { r += 1 }   // ვერ ეტევა → შემდეგი
            railOf[comp.id] = r
            cursor[r] += w
        }
    }

    /// გადატანა კონკრეტულ რელსზე, `afterID`-ის შემდეგ (nil → რელსის ბოლოში).
    /// ცარიელ რელსზეც მუშაობს — ეს ასწორებს „ქვედა რიგზე ვერ გადამაქვს" შეცდომას.
    func moveToRail(_ id: String, rail r: Int, afterID: String?) {
        guard let comp = board.components.first(where: { $0.id == id }) else { return }
        if blockedByLiveEdit(comp.ports.map { $0.id }) { return }
        let target = min(max(r, 0), railCount - 1)
        if comp.kind == .comb {
            // სავარცხელი — გადაჯდომა სხვა რელსზე ხელახალი ჩასმით
            if !seatComb(id, preferRail: target) {
                inspectNotice = "ამ რელსზე სავარცხელს 2 მომიჯნავე ავტომატი სჭირდება"
            }
            resetResult()
            return
        }
        // ტევადობა: სამიზნე რელსზე უნდა დარჩეს ადგილი (იმავე რელსზე გადაადგილება
        // ტევადობას არ ცვლის — excluding: id).
        guard railHasRoom(target, width: widthUnits(of: comp), excluding: id) else {
            inspectNotice = "რიგზე ადგილი აღარ არის"
            return
        }
        railOf[id] = target
        var comps = board.components
        comps.removeAll { $0.id == id }
        if let afterID, let aIdx = comps.firstIndex(where: { $0.id == afterID }) {
            comps.insert(comp, at: aIdx + 1)
        } else {
            comps.append(comp)
        }
        board.components = comps
        reseatCombs()
        resetResult()
    }

    // MARK: - სავარცხელი სალტე (comb) — ჩასმა/გადაჯდომა

    /// comb-სადენია? (კბილების ავტო-კავშირები — მომხმარებლის სიაში არ ჩანს)
    func isCombWire(_ w: Wire) -> Bool {
        combs.contains { w.fromPortID.hasPrefix($0.id + ".") || w.toPortID.hasPrefix($0.id + ".") }
    }
    /// მომხმარებლის სადენები (comb-ის ავტო-კავშირების გარეშე).
    var userWires: [Wire] { board.wires.filter { !isCombWire($0) } }

    /// სავარცხელის ჩასმა: რელსზე ავტომატების ყველაზე გრძელ უწყვეტ მონაკვეთზე
    /// (მინ. 2) კბილები მაგრდება L-შესასვლელებზე tightened-სადენებით.
    /// სხვა სავარცხელის უკვე დაკავებული ავტომატები არ ითვლება (არ ჯდება ზედმეტად);
    /// ცოცხალ კლემებზე ჩასმა იბლოკება შოკით (live-wire წესი ვრცელდება).
    @discardableResult
    func seatComb(_ combID: String, preferRail: Int? = nil) -> Bool {
        guard let comb = board.components.first(where: { $0.id == combID }) else { return false }
        // ძველი კბილ-კავშირების მოხსნა
        board.wires.removeAll {
            $0.fromPortID.hasPrefix(combID + ".") || $0.toPortID.hasPrefix(combID + ".")
        }
        // სხვა სავარცხელების მიერ დაკავებული შესასვლელები
        let otherCombIDs = combs.map(\.id).filter { $0 != combID }
        let claimed = Set(board.wires.compactMap { w -> String? in
            guard otherCombIDs.contains(where: { w.fromPortID.hasPrefix($0 + ".") }) else { return nil }
            return w.toPortID
        })
        var railOrder = Array(0..<railCount)
        if let p = preferRail { railOrder = [p] + railOrder.filter { $0 != p } }
        for r in railOrder {
            // ყველაზე გრძელი უწყვეტი თავისუფალი ავტომატების რანი ამ რელსზე
            var best: [Component] = [], current: [Component] = []
            for m in railMembers(r) {
                let inPort = m.ports.first { $0.side == .input && $0.conductor.isHot }
                if m.kind.isBreaker, let inPort, !claimed.contains(inPort.id) {
                    current.append(m)
                    if current.count > best.count { best = current }
                } else {
                    current = []
                }
            }
            guard best.count >= 2 else { continue }
            let span = Array(best.prefix(comb.ports.count))
            let spanPorts = span.compactMap { m in
                m.ports.first { $0.side == .input && $0.conductor.isHot }?.id
            }
            // ცოცხალ კლემებზე სავარცხელის დასმა = შოკი (de-energize ჯერ!)
            if blockedByLiveEdit(spanPorts) { return false }
            for (i, portID) in spanPorts.enumerated() {
                // tooth-ის გამტარი (3-ფაზიანზე ბრუნავს L1/L2/L3) → შესაბამისი ფერი
                let cond = comb.ports.indices.contains(i) ? comb.ports[i].conductor : .L
                board.connect("\(combID).\(i)", portID, csaMm2: 10,
                              color: WireColor.standard(for: cond), tightened: true)
            }
            railOf[combID] = r
            return true
        }
        return false
    }

    /// ყველა სავარცხელის ხელახალი ჩასმა (გადაადგილების/წაშლის შემდეგ).
    /// თუ სავარცხელს ადგილი აღარ აქვს — იხსნება ფარიდან.
    func reseatCombs() {
        for comb in combs where !seatComb(comb.id, preferRail: railOf[comb.id]) {
            board.components.removeAll { $0.id == comb.id }
            railOf[comb.id] = nil
            if let tid = templates.keys.first(where: { comb.id.hasPrefix($0 + "_") }) {
                placedCounts[tid] = max(0, (placedCounts[tid] ?? 1) - 1)
            }
            inspectNotice = "სავარცხელი მოიხსნა — აღარ აქვს 2 მომიჯნავე ავტომატი ერთ რელსზე"
        }
    }

    /// შემოწმებაზე გაგზავნა — საჭიროა ჩართული კვება (live ფარი). გამორთულზე →
    /// შეტყობინება. ჩართულზე → ინსპექტორი (solver) აფასებს ცოცხალ ფარს.
    func inspect(game: GameState) {
        guard energized else {
            inspectNotice = "ჩართე კვება შემოწმებამდე"
            return
        }
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
        guard let liveAnalysis else { return false }
        return LiveWire.isPortLive(liveAnalysis, portID)
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

/// კარადის ფიქსირებული DIN-რელსების ჩარჩოები "board" სივრცეში (drop-სამიზნეები).
struct RailFrameKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}


/// "board" — საერთო კოორდინატთა სივრცე drag-ისა და ფეხების პოზიციებისთვის.
let kBoardSpace = "board"

/// ერთი DIN-სლოტის სიგანე წერტილებში (18მმ-ის ვიზუალური ეკვივალენტი).
/// მოდულები ზუსტად `moduleWidthUnits * kSlotPt` სიგანისაა და ერთმანეთს ებჯინება.
let kSlotPt: CGFloat = 44

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
    // შედეგის sheet-ის დახურვის შემდეგ შესასრულებელი ნავიგაცია (race-ის თავიდან ასაცილებლად).
    @State private var pendingNav: PendingNav?
    private enum PendingNav: Equatable { case next(String), pop, paywall }
    // პალიტრის აკორდეონი — ერთდროულად მხოლოდ ერთი კატეგორიაა გახსნილი.
    @State private var expandedCategory: ComponentCategory?
    @State private var didInitPalette = false
    // ჩაჭდობა (snap-in): გადათრევისას სამიზნე რელსის სლოტის ჰაილაითი + დაჯდომის პულსი.
    private struct DropSlot: Equatable {
        let rail: Int           // -1 → დატვირთვების ზოლი (anchor-რეჟიმი)
        let afterID: String?
        let x: CGFloat
    }
    @State private var dropSlot: DropSlot?
    @State private var snappedID: String?
    @State private var railFrames: [Int: CGRect] = [:]
    @State private var didFitCamera = false             // კარადა-პირველი კადრირება (ერთხელ)
    @State private var knockoutPulseID: Knockout?       // ცემის გახსნის პულსი
    // ფარი-პირველი განლაგება: ბრიფი ერთ ხაზად (გასაშლელით) + ფოკუს-რეჟიმი.
    @State private var briefExpanded = false
    @State private var focusMode = false
    @State private var preFocusZoom: CGFloat?
    @State private var showFocusPalette = false
    // ფოკუს-პალიტრიდან ჩაკეტილ ბარათზე შეხება: ჯერ პალიტრა იხურება, მერე paywall
    // (ორი sheet ერთდროულად ვერ იქნება წარდგენილი).
    @State private var pendingPaywallAfterPalette = false
    // ფარის ჟესტები (board სივრცე)
    @State private var portPoints: [String: CGPoint] = [:]
    @State private var componentFrames: [String: CGRect] = [:]
    @State private var dragMode: BoardDragMode = .none
    @State private var dragFrom: String?
    @State private var moveID: String?
    @State private var dragCurrent: CGPoint = .zero
    @State private var isZooming = false
    @State private var railWidth: CGFloat = 0   // ფარის ზონის სიგანე
    @State private var railAreaSize: CGSize = .zero   // ფარის ზონის ზომა (კადრირებისთვის)

    // MARK: კარადის ფიქსირებული რელსები — drop-სამიზნე
    /// drop-სამიზნე: უახლოესი ფიქსირებული რელსი (y-ით) + ჩასმის ადგილი წევრებს
    /// შორის (x-ით). ცარიელი რელსიც ვალიდური სამიზნეა — სწორედ ეს ასწორებს
    /// „ავტომატი ქვედა რიგზე ვერ გადამაქვს" შეცდომას. დატვირთვებს რელსი არ
    /// ეხებათ — ისინი ზოლში anchor-ით ლაგდება (rail == -1).
    private func railDropTarget(for id: String, at p: CGPoint) -> DropSlot? {
        guard let comp = model.board.components.first(where: { $0.id == id }) else { return nil }
        if comp.kind.isLoad {
            // დატვირთვა: ზოლის შიგნით x-ით დალაგება (afterID nil → ზოლის თავში)
            let members = model.loadStrip.filter { $0.id != id }
            guard !members.isEmpty else { return nil }
            let after = members.last { (componentFrames[$0.id]?.midX ?? -.greatestFiniteMagnitude) < p.x }
            let x: CGFloat
            if let after, let f = componentFrames[after.id] { x = f.maxX + 14 }
            else if let f = componentFrames[members[0].id] { x = f.minX - 14 }
            else { x = p.x }
            return DropSlot(rail: -1, afterID: after?.id, x: x)
        }
        // DIN-მოწყობილობა/სავარცხელი: უახლოესი რელსი
        guard let (r, frame) = railFrames.min(by: {
            abs($0.value.midY - p.y) < abs($1.value.midY - p.y)
        }) else { return nil }
        let members = model.railMembers(r).filter { $0.id != id }
        let after = members.last { (componentFrames[$0.id]?.midX ?? -.greatestFiniteMagnitude) < p.x }
        let x: CGFloat
        if let after, let f = componentFrames[after.id] { x = f.maxX + 14 }
        else if let first = members.first, let f = componentFrames[first.id] { x = f.minX - 14 }
        else { x = frame.minX + 40 }   // ცარიელი რელსი
        return DropSlot(rail: r, afterID: after?.id, x: x)
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

    /// საწყისად გახსნილი კატეგორია — პირველი (ჩვენების რიგით), რომელშიც დონის
    /// მიზნისთვის (goal.poweredLoads) საჭირო კომპონენტია; თუ ასეთი არ არის — პირველივე.
    private var defaultExpandedCategory: ComponentCategory? {
        let goalKinds = Set(model.level.goal.poweredLoads.keys.compactMap { ComponentKind(rawValue: $0) })
        if !goalKinds.isEmpty {
            for cat in paletteCategories {
                let kinds = paletteEntries(in: cat).compactMap { model.templates[$0.templateId]?.kind }
                if kinds.contains(where: goalKinds.contains) { return cat }
            }
        }
        return paletteCategories.first
    }

    /// აკორდეონის სიმაღლე: სათაურები + (გახსნილი რიგი). ზღვრულია, რომ ქვედა
    /// ღილაკები ეკრანიდან არ გავიდეს (ბევრი კატეგორიის დონეზე შიგნით გადაიხვევა).
    private var paletteAccordionHeight: CGFloat {
        let headers = CGFloat(paletteCategories.count) * 27
        let expanded: CGFloat = expandedCategory != nil ? 74 : 0
        return min(headers + expanded + 8, 180)
    }

    /// კატეგორიის ჩამოსაშლელი სათაური: ხატულა + სახელი + რაოდენობა + chevron.
    private func categoryHeader(_ cat: ComponentCategory, proxy: ScrollViewProxy? = nil) -> some View {
        let isOpen = expandedCategory == cat
        let count = paletteEntries(in: cat).count
        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                // აკორდეონი: ერთის გახსნა წინას კეტავს; ხელახლა შეხება — კეტავს.
                expandedCategory = isOpen ? nil : cat
            }
            // გახსნისას კატეგორია ხედში შემოგვაქვს — ქვედა header-ის გაშლილი
            // რიგი ზღვრული კლასტერის ჩარჩოს მიღმა არ უნდა დარჩეს.
            if !isOpen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy?.scrollTo(cat, anchor: .top)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: cat.sfSymbol).font(.caption2)
                Text("\(cat.georgian) (\(count))").font(.caption2.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
            }
            .foregroundStyle(isOpen ? Color.primary : Color.secondary)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(isOpen ? Color.yellow.opacity(0.18) : Color(.tertiarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("palette-cat-\(cat.rawValue)")
        .accessibilityValue(isOpen ? "გახსნილია" : "დახურულია")
    }

    /// კაბელის კვეთის ერთხაზიანი იარლიყი — locale-დამოუკიდებელი წერტილით, ქართული „მმ²".
    static func csaLabel(_ csa: Double) -> String {
        String(format: "%.1f", csa) + " მმ²"
    }

    @ViewBuilder
    private func paletteCard(_ e: PaletteEntry, afterAdd: (() -> Void)? = nil) -> some View {
        let t = model.templates[e.templateId]
        let locked = isPaletteLocked(e)
        Button {
            if locked {
                // ფოკუს-პალიტრის sheet-იდან paywall პირდაპირ ვერ წარდგება —
                // ჯერ პალიტრა დაიხუროს, paywall მის onDismiss-ში გაიხსნება.
                if showFocusPalette {
                    pendingPaywallAfterPalette = true
                    showFocusPalette = false
                } else {
                    showPaywall = true
                }
            } else if let newID = model.add(e) {
                snapPulse(newID)   // ჩაჭდობა რელსზე
                afterAdd?()        // ფოკუს-პალიტრა: არჩევაზე იხურება
            }
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
        .accessibilityIdentifier("palette-card-\(e.templateId)")
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
            guard !pts.isEmpty else {
                // ფეხების გარეშე მოდული (ცარიელი) — ბარათის ჩარჩოთი hit-test.
                if let f = componentFrames[comp.id], f.contains(p) {
                    let d = hypot(f.midX - p.x, f.midY - p.y)
                    if d < bestDist { bestDist = d; bestID = comp.id }
                }
                continue
            }
            let xs = pts.map(\.x), ys = pts.map(\.y)
            let minX = xs.min()!, maxX = xs.max()!
            let minY = ys.min()!, maxY = ys.max()!
            // კლემები ზედა/ქვედა კიდეებზეა, მაგრამ ზოგ კომპონენტს მხოლოდ ერთ
            // მხარეს აქვს (SPD ზევით, დატვირთვები ქვევით) → სიმეტრიული მარჟა
            // ორივე მიმართულებით, რომ მოდულის სახეც დაიჭიროს.
            let region = CGRect(x: minX - 28, y: minY - 80,
                                width: (maxX - minX) + 56, height: (maxY - minY) + 160)
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
                if dragMode == .wire || dragMode == .move { dragCurrent = toBoard(v.location) }
                // გადატანისას — სამიზნე რელსის სლოტის ჰაილაითი (სად ჩაჯდება).
                if dragMode == .move, let id = moveID,
                   !(model.selection.contains(id) && model.selection.count > 1) {
                    dropSlot = railDropTarget(for: id, at: toBoard(v.location))
                }
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
                            snapPulse(id)
                        } else if let drop = railDropTarget(for: id, at: toBoard(v.location)) {
                            if drop.rail >= 0 {
                                // DIN-მოწყობილობა — ნებისმიერ (ცარიელ) რელსზეც ჯდება.
                                model.moveToRail(id, rail: drop.rail, afterID: drop.afterID)
                            } else if let anchor = drop.afterID {
                                // დატვირთვა — ზოლში anchor-ის შემდეგ
                                model.moveComponent(id, relativeTo: anchor, after: true)
                            } else if let first = model.loadStrip.first(where: { $0.id != id }) {
                                // დატვირთვა — ზოლის თავში
                                model.moveComponent(id, relativeTo: first.id, after: false)
                            }
                            snapPulse(id)                          // ჩაჭდობა: პულსი + კლიკი
                        }
                    }
                case .pan:
                    pan.width += v.translation.width; pan.height += v.translation.height
                case .none: break
                }
                dragMode = .none; dragFrom = nil; moveID = nil; dropSlot = nil
            }
    }

    /// რელსზე ჩაჭდობის უკუკავშირი: წამიერი მასშტაბის პულსი + მყარი ჰაპტიკა/კლიკი.
    private func snapPulse(_ id: String) {
        snappedID = id
        GameFeedback.snap()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if snappedID == id { snappedID = nil }
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
    /// „შემდეგი" იგივე ტრეკშია — ფარის აწყობას ფარის აწყობა მოჰყვება, Learn-ს Learn.
    private var nextLevelID: String? {
        let track = model.level.isPanelAssembly ? game.panelLevels : game.learnLevels
        guard let idx = track.firstIndex(where: { $0.id == model.level.id }) else { return nil }
        let n = idx + 1
        return n < track.count ? track[n].id : nil
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

    /// „შემდეგი დონე" — ვაყენებთ განზრახვას და ვხურავთ შედეგის sheet-ს; რეალური
    /// ნავიგაცია ხდება onDismiss-ში (handleResultDismiss), რომ sheet-ის დახურვასა
    /// და path-ის ცვლილებას შორის race არ მოხდეს (ეს იყო „შემდეგი“-ს ბაგი).
    private func goNext() {
        guard let dest = nextDestination() else { backToMenu(); return }
        if dest.locked { pendingNav = .paywall; model.showResult = false; return }
        pendingNav = .next(dest.route)
        model.showResult = false
    }
    /// უკან სიაში/ბორდზე დაბრუნება (workbench-ის pop). მენიუ ახლა root-ია.
    private func backToMenu() {
        // Learn: პროგრესის უსაფრთხო შენახვა (career-ს markCompleted არ სჭირდება).
        if model.careerJob == nil, model.levelPassed { game.markCompleted(model.level) }
        pendingNav = .pop
        model.showResult = false
    }
    /// შედეგის sheet დაიხურა → ახლა უსაფრთხოა path-ის ცვლილება (sheet აღარ ეჯახება).
    private func handleResultDismiss() {
        guard let nav = pendingNav else { return }   // უბრალო დახურვა/swipe — ვრჩებით დონეზე
        pendingNav = nil
        switch nav {
        case .next(let route):
            // იგივე სიღრმეზე route-ის ჩანაცვლება მუშაობს მხოლოდ destination-ის
            // .id(route)-თან ერთად (იხ. RootView) — სხვანაირად SwiftUI ძველ
            // @StateObject-იან ეკრანს იტოვებს. ეს იყო „შემდეგი დონე"-ს ბაგი.
            if path.isEmpty { path = [route] } else { path[path.count - 1] = route }
        case .pop:
            if !path.isEmpty { path.removeLast() }
        case .paywall:
            showPaywall = true
        }
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                if !focusMode {
                    briefBar
                    powerHUD
                }
                railView
                if let m = model.measurement, !focusMode {
                    Text(m)
                        .font(.callout.bold())
                        .padding(6)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow.opacity(0.2))
                }
                if !focusMode {
                    Divider()
                    // კონტროლების კლასტერი ზღვრულია (~36%) — ფარი იღებს ეკრანის
                    // უმეტესობას; შიგთავსი საჭიროებისას შიგნით გადაიხვევა.
                    controls
                        .frame(height: geo.size.height * 0.36)
                }
            }
            // ფოკუს-რეჟიმი: ფარი მთელ ეკრანზე + თხელი მცურავი ზოლი ქვემოთ.
            .overlay(alignment: .bottom) { if focusMode { focusStrip } }
        }
        .overlay { shockOverlay }
        .animation(.easeInOut(duration: 0.12), value: model.shockFlash)
        .onChange(of: model.shockCount) { _ in shockHaptic() }
        .alert(model.inspectNotice ?? "", isPresented: Binding(
            get: { model.inspectNotice != nil },
            set: { if !$0 { model.inspectNotice = nil } }
        )) {
            Button("გასაგებია", role: .cancel) { model.inspectNotice = nil }
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
        .onAppear {
            model.configure(game.templates, game: game)
            // საწყისი აკორდეონი — configure-ის შემდეგ (templates უკვე ჩატვირთულია,
            // კატეგორიები სწორად დგინდება); მომხმარებლის არჩევანს აღარ ვცვლით.
            if !didInitPalette {
                didInitPalette = true
                expandedCategory = defaultExpandedCategory
                // ბრიფი: პირველი ნახვისას გაშლილი, შემდეგ ჯერებზე ერთ ხაზად.
                let seenKey = "briefSeen.\(model.level.id)"
                briefExpanded = !UserDefaults.standard.bool(forKey: seenKey)
                UserDefaults.standard.set(true, forKey: seenKey)
            }
        }
        .sheet(isPresented: $model.showResult, onDismiss: handleResultDismiss) {
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
        .sheet(isPresented: $showFocusPalette, onDismiss: {
            if pendingPaywallAfterPalette {
                pendingPaywallAfterPalette = false
                showPaywall = true
            }
        }) { focusPaletteSheet }
        .alert("მინიშნება", isPresented: $showHint) {
            Button("გასაგებია", role: .cancel) {}
        } message: { Text(model.level.hint) }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }

    /// ბრიფი ერთ ხაზად — „მეტი ▾" შლის სრულ ტექსტს + რეჟიმის ბანერებს.
    /// პირველი ნახვის შემდეგ ავტომატურად იკეცება (briefSeen.<id>, per level).
    private var briefBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(model.level.brief)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(briefExpanded ? nil : 1)
                Spacer(minLength: 0)
                Button(briefExpanded ? "ნაკლები ▴" : "მეტი ▾") {
                    withAnimation(.easeInOut(duration: 0.2)) { briefExpanded.toggle() }
                }
                .font(.caption2.bold())
                .accessibilityIdentifier("brief-toggle")
            }
            if briefExpanded {
                if model.level.resolvedMode == .faultFind {
                    Label("დეფექტის ძებნა — იპოვე და გაასწორე ხარვეზი", systemImage: "magnifyingglass")
                        .font(.caption2.bold())
                        .foregroundStyle(.orange)
                }
                if model.level.isPanelAssembly {
                    Label("ფარის აწყობა — თანმიმდევრობა: მთავარი → SPD → RCD → ავტომატები (ზოლით)",
                          systemImage: "rectangle.3.group")
                        .font(.caption2.bold())
                        .foregroundStyle(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal).padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: HUD — კვების ინდიკატორი/გადამრთველი, ერთი კომპაქტური რიგი
    private var powerHUD: some View {
        HStack(spacing: 8) {
            Button { model.togglePower() } label: {
                Label(model.energized ? "ჩართულია" : "გამორთულია",
                      systemImage: model.energized ? "bolt.fill" : "bolt.slash.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(model.energized ? Color.green.opacity(0.22) : Color.gray.opacity(0.18),
                                in: Capsule())
                    .foregroundStyle(model.energized ? .green : .secondary)
                    .overlay(Capsule().stroke(model.energized ? Color.green : Color.gray.opacity(0.4),
                                              lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("power-toggle")

            Text(model.energized ? "ფარი ცოცხალია" : "უსაფრთხოა — შეგიძლია რედაქტირება")
                .font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal).padding(.vertical, 4)
        .background(model.energized ? Color.green.opacity(0.07) : Color(.secondarySystemBackground))
    }

    // MARK: შოკის ვიზუალი — წითელი ფლეში + გაფრთხილება
    @ViewBuilder private var shockOverlay: some View {
        if model.shockFlash {
            ZStack(alignment: .top) {
                Color.red.opacity(0.30).ignoresSafeArea()
                Text("⚡ დაგარტყა დენმა! ჯერ გამორთე კვება!")
                    .font(.headline.bold()).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.red, in: Capsule())
                    .padding(.top, 60).padding(.horizontal, 24)
                    .accessibilityIdentifier("shock-warning")
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    private func shockHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    private var railView: some View {
        // ფარის შიგთავსი overlay-შია (და არა ZStack-ში), რომ მისმა ბუნებრივმა
        // სიმაღლემ კონტეინერი არ გაზარდოს და ქვედა ღილაკები ეკრანიდან არ
        // გამოდევნოს — ჭარბი ეჭრება, ნავიგაცია pan/zoom-ით ხდება.
        Color(.systemBackground)
            .overlay(alignment: .topLeading) {
                boardContent
                    .scaleEffect(zoom * pinch, anchor: .topLeading)
                    .offset(x: pan.width + panLive.width, y: pan.height + panLive.height)
            }
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
        .background(GeometryReader { g in
            Color.clear
                .onAppear {
                    railWidth = g.size.width; railAreaSize = g.size
                    fitCabinetIfNeeded(content: lastCabinetContent)
                }
                .onChange(of: g.size) {
                    railWidth = $0.width; railAreaSize = $0
                    fitCabinetIfNeeded(content: lastCabinetContent)
                }
        })
        .contentShape(Rectangle())
        .clipped()
        // ერთიანი drag (wire/move/pan) + pinch zoom — ორივე simultaneous, არ ეჯახება.
        .simultaneousGesture(boardDrag)
        .simultaneousGesture(boardZoom)
        .overlay(alignment: .bottomTrailing) { zoomControls }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board-rail")
    }

    /// ფოკუს-რეჟიმის გადართვა: ფარი მთელ ეკრანზე, მოდულები უფრო მსხვილად.
    private func toggleFocus() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if focusMode {
                focusMode = false
                if let z = preFocusZoom { zoom = z; preFocusZoom = nil }
            } else {
                focusMode = true
                preFocusZoom = zoom
                if zoom < 1.35 { zoom = 1.35 }   // დეტალები კომფორტულად იკითხება
            }
        }
    }

    /// ფოკუს-რეჟიმის თხელი მცურავი ზოლი: პალიტრა / სადენი / კვება / ინსპექცია.
    private var focusStrip: some View {
        HStack(spacing: 18) {
            Button { showFocusPalette = true } label: {
                Image(systemName: "square.grid.2x2.fill").font(.title3)
            }
            .accessibilityIdentifier("focus-palette")
            Button { model.tool = .wire; model.selectedPort = nil } label: {
                Image(systemName: Tool.wire.symbol).font(.title3)
                    .foregroundStyle(model.tool == .wire ? Color.brand : Color.secondary)
            }
            .accessibilityIdentifier("focus-wire")
            Button { model.togglePower() } label: {
                Image(systemName: model.energized ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title3)
                    .foregroundStyle(model.energized ? Color.green : Color.secondary)
            }
            .accessibilityIdentifier("power-toggle")
            Button { model.inspect(game: game) } label: {
                Image(systemName: "paperplane.fill").font(.title3)
                    .foregroundStyle(Color.brand)
            }
            .accessibilityIdentifier("inspect")
        }
        .padding(.horizontal, 20).padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.gray.opacity(0.3)))
        .padding(.bottom, 10)
    }

    /// ფოკუს-რეჟიმის პალიტრა — მცურავი ფურცელი ფარის თავზე; არჩევაზე იხურება.
    private var focusPaletteSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(paletteCategories, id: \.self) { cat in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(cat.georgian, systemImage: cat.sfSymbol)
                                .font(.caption.bold()).foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(paletteEntries(in: cat)) { e in
                                        paletteCard(e, afterAdd: { showFocusPalette = false })
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("პალიტრა")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("დახურვა") { showFocusPalette = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    /// რელსის შიდა სიგანე — კარადის ზომით ფიქსირებული (modulesPerRow × სლოტი).
    private var railContentWidth: CGFloat { CGFloat(model.modulesPerRow) * kSlotPt }

    private var boardContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            knockoutStrip(.top)        // ზედა კიდის ცემები
            // ფიქსირებული DIN-რელსები — ცარიელიც drop-სამიზნეა (ქვედა რიგზე გადატანა მუშაობს)
            ForEach(0..<model.railCount, id: \.self) { r in
                railRow(r)
            }
            // დატვირთვების თარო — კარადის ძირში
            if !model.loadStrip.isEmpty { loadStripRow }
            knockoutStrip(.bottom)     // ქვედა კიდის ცემები
        }
        .padding(20)
        .background(cabinetBody)   // კარადის კორპუსი — ფერი მონტაჟის ტიპით
        .padding(28)
        .coordinateSpace(name: kBoardSpace)
        .overlay { wireOverlay }
        .overlay { combOverlay }   // სავარცხელები მოდულების ზემოდან
        .background(GeometryReader { g in
            Color.clear
                .onAppear { fitCabinetIfNeeded(content: g.size) }
                .onChange(of: g.size) { fitCabinetIfNeeded(content: $0) }
        })
        .onPreferenceChange(PortFrameKey.self) { portPoints = $0 }
        .onPreferenceChange(CardFrameKey.self) { componentFrames = $0 }
        .onPreferenceChange(RailFrameKey.self) { railFrames = $0 }
    }

    /// ერთი ფიქსირებული DIN-რელსი: მოდულები მარცხნიდან სლოტებში ჩაწყობილი,
    /// ფიქსირებული ტევადობით (კარადის ზომა); ცარიელ ნაწილზე სლოტ-ბადე ჩანს.
    private func railRow(_ r: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(model.railMembers(r)) { comp in card(for: comp) }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .frame(width: railContentWidth, alignment: .leading)
        .frame(minHeight: 132, alignment: .topLeading)
        .background(slotGrid)
        .background(GeometryReader { g in
            Color.clear.preference(key: RailFrameKey.self,
                                   value: [r: g.frame(in: .named(kBoardSpace))])
        })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rail-\(r)")
    }

    /// მონტაჟის ფირფიტა (back box) + DIN რელსი + 18მმ სლოტ-ბადე.
    /// ფირფიტა ღია ფერისაა, რომ მუქ flush-კარადაშიც სლოტები ნათლად ჩანდეს.
    private var slotGrid: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(white: 0.82))
            .overlay { dinRailBackground }
            .overlay {
                HStack(spacing: 0) {
                    ForEach(0..<model.modulesPerRow, id: \.self) { i in
                        Rectangle().fill(Color.clear).frame(width: kSlotPt)
                            .overlay(alignment: .leading) {
                                if i > 0 { Rectangle().fill(Color.black.opacity(0.10)).frame(width: 0.5) }
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .allowsHitTesting(false)
            }
    }

    /// კარადის კიდის ცემები (knockouts) — დახურული დისკი / გახსნილი ხვრელი; tap → გახსნა.
    private func knockoutStrip(_ edge: Knockout.Edge) -> some View {
        let ks = model.enclosure.availableKnockouts.filter { $0.edge == edge }
        return ZStack(alignment: .leading) {
            Color.clear.frame(height: 16)
            ForEach(ks, id: \.self) { k in
                knockoutDisc(k)
                    .position(x: CGFloat(k.index) * kSlotPt + kSlotPt / 2, y: 8)
            }
        }
        .frame(width: railContentWidth, height: 16, alignment: .leading)
        .accessibilityIdentifier("knockouts-\(edge.rawValue)")
    }

    private func knockoutDisc(_ k: Knockout) -> some View {
        let open = model.enclosure.isOpen(k)
        return Button {
            model.toggleKnockout(k)
            knockoutPulseID = k
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                if knockoutPulseID == k { knockoutPulseID = nil }
            }
        } label: {
            ZStack {
                if open {
                    // გახსნილი ხვრელი — მუქი, კაბელის შესაყვანი რგოლით
                    Circle().fill(Color.black.opacity(0.55))
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1.5))
                        .frame(width: 13, height: 13)
                } else {
                    // დახურული ცემა — ბლანკირებული დისკი
                    Circle().fill(Color(white: 0.80))
                        .overlay(Circle().stroke(Color.black.opacity(0.30), lineWidth: 1))
                        .overlay(Circle().fill(Color(white: 0.68)).frame(width: 7, height: 7))
                        .frame(width: 13, height: 13)
                }
            }
            .scaleEffect(knockoutPulseID == k ? 1.35 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: knockoutPulseID == k)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("knockout-\(k.edge.rawValue)-\(k.index)")
        .accessibilityLabel(open ? "გახსნილი ცემა" : "დახურული ცემა")
    }

    /// დატვირთვების ზოლი კარადის ქვედა ნაწილში (რელსები DIN-მოწყობილობებისთვისაა).
    private var loadStripRow: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(model.loadStrip) { comp in card(for: comp) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(width: railContentWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.18), lineWidth: 1))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("load-strip")
    }

    /// კარადის კორპუსი — ფერი მონტაჟის ტიპით: surface = ღია პლასტიკი,
    /// flush = მუქი ლითონის კარადა. ჩარჩო + კუთხის ხრახნები.
    private var cabinetBody: some View {
        let flush = model.enclosure.mount == .flush
        let colors = flush
            ? [Color(white: 0.30), Color(white: 0.20)]   // მუქი ლითონი
            : [Color(white: 0.97), Color(white: 0.89)]   // ღია პლასტიკი
        return RoundedRectangle(cornerRadius: 16)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(flush ? Color(white: 0.10) : Color(white: 0.60), lineWidth: 1.6))
            .overlay(alignment: .topLeading) { cabinetScrew }
            .overlay(alignment: .topTrailing) { cabinetScrew }
            .overlay(alignment: .bottomLeading) { cabinetScrew }
            .overlay(alignment: .bottomTrailing) { cabinetScrew }
            .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 3)
    }
    private var cabinetScrew: some View {
        ZStack {
            Circle().fill(ModuleStyle.screw).frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.black.opacity(0.3), lineWidth: 0.5))
            Rectangle().fill(Color.black.opacity(0.6)).frame(width: 5.5, height: 1.2)
                .rotationEffect(.degrees(45))
        }
        .padding(7)
        .allowsHitTesting(false)
    }

    /// კარადა-პირველი კადრირება (ფარის აწყობა): მთელი კარადა ეტევა ფარის ზონაში.
    /// content/area ზომები სხვადასხვა დროს ჩნდება — ორივე მხრიდან ვცდით (race-მდგრადი).
    @State private var lastCabinetContent: CGSize = .zero
    private func fitCabinetIfNeeded(content: CGSize) {
        if content.width > 50 { lastCabinetContent = content }
        guard model.level.isPanelAssembly, !didFitCamera,
              railAreaSize.width > 50, railAreaSize.height > 50,
              lastCabinetContent.width > 50, lastCabinetContent.height > 50 else { return }
        didFitCamera = true
        let fit = min(railAreaSize.width / lastCabinetContent.width,
                      railAreaSize.height / lastCabinetContent.height, 1.0)
        zoom = max(0.3, fit * 0.98)
        pan = .zero
    }

    /// კომპონენტის ბარათი — საერთო პარამეტრებით (რელსები/ზოლი ერთნაირად ხატავს).
    private func card(for comp: Component) -> some View {
        ComponentCardView(
            component: comp,
            selectedPort: model.selectedPort,
            loadState: model.result?.state(for: comp.id),
            isSelected: model.selection.contains(comp.id),
            isLive: { model.isLive($0) },
            onTapPort: { model.tapPort($0) },
            onLongPress: { model.toggleSelect(comp.id) },
            onDelete: comp.id == "supply" ? nil : { model.removeComponent(comp.id) },
            // ბერკეტი = ამომრთველის მდგომარეობა: ჩართული (closed) → ზევით, გამორთული → ქვევით.
            leverUp: !comp.isOpen,
            // ბერკეტის გადართვა — მხოლოდ toggleable მოწყობილობებზე.
            onToggleLever: comp.kind.isToggleable ? { model.toggleDevice(comp.id) } : nil,
            isSnapped: snappedID == comp.id,
            isUntightened: { model.isPortUntightened($0) },
            hasWire: { pid in
                model.board.wires.contains { $0.fromPortID == pid || $0.toPortID == pid }
            },
            onTightenPort: { pid in
                if model.tightenPort(pid) { GameFeedback.ratchet() }
            },
            wireInfo: { pid in
                guard let w = model.board.wires.first(where: {
                    $0.fromPortID == pid || $0.toPortID == pid
                }) else { return nil }
                return TerminalWireInfo(color: w.color.swiftUIColor,
                                        ferruled: w.ferruled,
                                        stranded: w.conductorType == .stranded)
            }
        )
        // რელს-მოწყობილობა იკავებს ზუსტად მის სლოტ(ებ)ს და ებჯინება მეზობელს;
        // დატვირთვები ბუნებრივად იზომებიან (ზოლი).
        .frame(width: WorkbenchModel.isRailMounted(comp)
               ? CGFloat(comp.kind.moduleWidthUnits) * kSlotPt : nil)
    }

    /// DIN 35მმ რელსის ვიზუალი: ლითონის გრადიენტი, ზედა/ქვედა ბაგეები (lips) და
    /// დამახასიათებელი მონტაჟის ნახვრეტები — მოდულები ვიზუალურად ამაზე „სხდება".
    private var dinRailBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.gray.opacity(0.10))
            .overlay(alignment: .center) {
                VStack(spacing: 0) {
                    Rectangle().fill(Color(white: 0.52)).frame(height: 1)      // ზედა ბაგე
                    Rectangle().fill(ModuleStyle.rail).frame(height: 9)
                        .overlay(
                            HStack(spacing: 16) {
                                ForEach(0..<14, id: \.self) { _ in
                                    Capsule().fill(Color.black.opacity(0.13))
                                        .frame(width: 6, height: 3.2)
                                }
                            }
                        )
                        .clipped()
                    Rectangle().fill(Color(white: 0.42)).frame(height: 1)      // ქვედა ბაგე
                }
                .allowsHitTesting(false)
            }
    }

    private var wireOverlay: some View {
        ZStack {
            ForEach(model.board.wires) { wire in
                if let a = portPoints[wire.fromPortID], let b = portPoints[wire.toPortID] {
                    // ცოცხალი (ფაზიანი) სადენი ჩართულ ფარზე — მსუბუქი ყვითელი ნათება
                    if model.energized,
                       model.isLive(wire.fromPortID) || model.isLive(wire.toPortID) {
                        Path { p in p.move(to: a); p.addLine(to: b) }
                            .stroke(Color.yellow.opacity(0.32),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    }
                    Path { p in p.move(to: a); p.addLine(to: b) }
                        .stroke(wire.color.swiftUIColor, style: wireStroke(wire.conductorType))
                }
            }
            if let from = dragFrom, let a = portPoints[from] {
                Path { p in p.move(to: a); p.addLine(to: dragCurrent) }
                    .stroke(Color.gray.opacity(0.7),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 4]))
            }
            // ჩაჭდობის სლოტი — სამიზნე რელსში (ცარიელშიც) სად დაჯდება მოდული.
            if let slot = dropSlot {
                let railFrame = slot.rail >= 0 ? railFrames[slot.rail] : nil
                let y = railFrame?.midY
                    ?? componentFrames[slot.afterID ?? ""]?.midY
                    ?? dragCurrent.y
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])))
                    .frame(width: 16, height: (railFrame?.height ?? 132) - 14)
                    .position(x: slot.x, y: y)
            }
        }
        .allowsHitTesting(false)   // არ ბლოკავს ფეხების/ბარათების ჟესტებს
    }

    // MARK: სავარცხელი სალტეების ვიზუალი — სპილენძის კბილები + იზოლირებული ზურგი

    private var combOverlay: some View {
        ZStack {
            ForEach(model.combs) { comb in combView(comb) }
        }
    }

    /// კბილის შევსება: ერთფაზიანი — სპილენძის გრადიენტი; სამფაზიანი — IEC ფაზის
    /// ფერი (L1 ყავისფერი, L2 შავი, L3 ნაცრისფერი).
    private func combToothFill(_ c: Conductor) -> AnyShapeStyle {
        c == .L ? AnyShapeStyle(ModuleStyle.screw)
                : AnyShapeStyle(WireColor.standard(for: c).swiftUIColor)
    }

    @ViewBuilder
    private func combView(_ comb: Component) -> some View {
        // კბილები: სამიზნე წერტილი + გამტარი (ფაზის ფერისთვის). სამიზნე = comb-ის
        // ავტო-სადენის მეორე ბოლო (მოდულის L-შესასვლელი); გამტარი — comb-ის პორტიდან.
        let teeth: [(pt: CGPoint, cond: Conductor)] = model.board.wires
            .filter { $0.fromPortID.hasPrefix(comb.id + ".") }
            .compactMap { w in
                guard let pt = portPoints[w.toPortID] else { return nil }
                let cond = comb.ports.first { $0.id == w.fromPortID }?.conductor ?? .L
                return (pt, cond)
            }
            .sorted { $0.pt.x < $1.pt.x }
        if teeth.count >= 2, let first = teeth.first?.pt, let last = teeth.last?.pt {
            let spineY = first.y - 16
            let minX = first.x - 12
            let maxX = last.x + 12
            // კბილები — ზურგიდან თითო კლემამდე (ფაზის ფერით)
            ForEach(Array(teeth.enumerated()), id: \.offset) { _, t in
                RoundedRectangle(cornerRadius: 1)
                    .fill(combToothFill(t.cond))
                    .frame(width: 5, height: max(10, t.pt.y - spineY))
                    .position(x: t.pt.x, y: (spineY + t.pt.y) / 2)
                    .allowsHitTesting(false)
            }
            // იზოლირებული (ნაცრისფერი) ზურგი — drag-ისთვის ჩარჩოსაც აწვდის (CardFrame)
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.33)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.black.opacity(0.25), lineWidth: 0.6))
                .frame(width: maxX - minX, height: 8)
                .position(x: (minX + maxX) / 2, y: spineY)
                .preference(key: CardFrameKey.self,
                            value: [comb.id: CGRect(x: minX, y: spineY - 12,
                                                    width: maxX - minX, height: 24)])
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("comb-\(comb.id)")
                .accessibilityLabel(comb.name)
            // მოხსნის ღილაკი — ზურგის მარჯვენა ბოლოსთან
            Button { model.removeComponent(comb.id) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.red).background(Circle().fill(.white))
            }
            .position(x: maxX + 12, y: spineY - 10)
        }
    }

    /// ხისტი = მუდმივი ხაზი; მრავალწვერა = ოდნავ სქელი + ზოლიანი (striped).
    private func wireStroke(_ c: ConductorType) -> StrokeStyle {
        c == .stranded
        ? StrokeStyle(lineWidth: 5, lineCap: .round, dash: [5, 3])
        : StrokeStyle(lineWidth: 4, lineCap: .round)
    }

    private var zoomControls: some View {
        VStack(spacing: 6) {
            // ფოკუს-რეჟიმი (⤢) — ფარი მთელ ეკრანზე / უკან
            Button { toggleFocus() } label: {
                zoomIcon(focusMode ? "arrow.down.right.and.arrow.up.left"
                                   : "arrow.up.left.and.arrow.down.right")
            }
            .accessibilityIdentifier("focus-toggle")
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

            // შიდა გადახვევადი ნაწილი — კლასტერი ზღვრულია (ფარი-პირველი განლაგება).
            ScrollView(.vertical, showsIndicators: false) {
                ScrollViewReader { paletteProxy in
                VStack(spacing: 8) {
                    Text(model.tool.hint).font(.caption2).foregroundStyle(.secondary)

                    // კომპონენტების პალიტრა — აკორდეონი (ერთდროულად ერთი კატეგორია).
                    if !paletteCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(paletteCategories, id: \.self) { cat in
                                categoryHeader(cat, proxy: paletteProxy)
                                    .id(cat)
                                if expandedCategory == cat {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(paletteEntries(in: cat)) { e in paletteCard(e) }
                                        }
                                        .padding(.horizontal, 2)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // სადენის ხელსაწყოები — კვეთა მხოლოდ სადენის ხელსაწყოზე
                    HStack {
                        if model.tool == .wire {
                            Text("კვეთა").font(.caption)
                            Picker("კვეთა", selection: $model.selectedCSA) {
                                ForEach(model.csaOptions, id: \.self) { csa in
                                    Text(Self.csaLabel(csa)).tag(csa)
                                }
                            }
                            .pickerStyle(.menu)
                            .fixedSize()   // ერთ ხაზზე — „6.0 მმ²" არ უნდა გადატყდეს
                        }
                        Spacer()
                        // „ყველას მოჭერა" — ჩანს, სანამ მოუჭერელი შეერთება არსებობს.
                        if model.hasUntightened {
                            Button {
                                model.tightenAll()
                                GameFeedback.ratchet()
                            } label: {
                                Label("მოჭერა", systemImage: "wrench.and.screwdriver.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            .accessibilityIdentifier("tighten-all")
                            .accessibilityLabel("ყველას მოჭერა")
                        }
                        Button { model.showWires = true } label: {
                            Label("\(model.userWires.count)", systemImage: "list.bullet")
                        }
                        .accessibilityIdentifier("wires-list")
                        Button { model.removeLastWire() } label: { Image(systemName: "arrow.uturn.backward") }
                        Button(role: .destructive) { model.clearWires() } label: { Image(systemName: "trash") }
                    }.padding(.horizontal)

                    // კაბელის პარამეტრები — მხოლოდ სადენის ხელსაწყოზე
                    if model.tool == .wire {
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

                        Text(model.selectedConductorType.cableName(csaMm2: model.selectedCSA))
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .accessibilityIdentifier("cable-name")

                        Stepper("სიგრძე: \(Int(model.selectedLengthM))მ",
                                value: $model.selectedLengthM, in: 0...100, step: 5)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 4)
                }
            }

            // ფიქსირებული ქვედა მოქმედება — ყოველთვის ხილული (არ გადაიხვევა)
            Button { model.inspect(game: game) } label: {
                Label("შემოწმებაზე გაგზავნა", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
            .accessibilityIdentifier("inspect")
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
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
    // რეალისტური DIN-მოდული — default-ებით, რომ read-only ჩვენებებმა (FaultBoardView)
    // უცვლელად იმუშაოს: ბერკეტი, ჩაჭდობის პულსი, კლემის მოჭერა.
    var leverUp: Bool = false
    /// ბერკეტის გადართვა (ჩართვა/გამორთვა) — nil → არა-toggleable (read-only ჩვენებებიც).
    var onToggleLever: (() -> Void)? = nil
    var isSnapped: Bool = false
    var isUntightened: (String) -> Bool = { _ in false }
    var hasWire: (String) -> Bool = { _ in false }
    var onTightenPort: (String) -> Void = { _ in }
    /// კლემაში შესული სადენის ფერი/ბუნიკი — ვიზუალური ჭდისთვის (nil → სადენი არ არის).
    var wireInfo: (String) -> TerminalWireInfo? = { _ in nil }

    /// რომელი კლემაა ამჟამად დაჭერილი (პროგრესული მოჭერის ანიმაცია).
    @State private var pressingPort: String?

    private var inputs: [Port] { component.ports.filter { $0.side == .input } }
    private var outputs: [Port] { component.ports.filter { $0.side == .output } }
    private var singles: [Port] { component.ports.filter { $0.side == .single } }
    private var isConnector: Bool { component.kind.isConnector }

    var body: some View {
        let photo = photoAssetName
        return VStack(spacing: 5) {
            if let photo {
                // ფოტო-რეალისტური მოდული (ხატული ბერკეტი/კორპუსი იხშობა)
                photoBody(photo)
            } else {
                // ზედა კიდე — შემავალი ხრახნიანი კლემები (კვების მხარე)
                if !inputs.isEmpty { terminalRow(inputs, edge: .top) }
                // მოდულის სახე (კონექტორებს ცალკე სახე არ აქვთ — სალტეა)
                if !isConnector { moduleFace }
                // ქვედა კიდე — გამავალი/დატვირთვის კლემები
                let bottom = outputs + singles
                if !bottom.isEmpty { terminalRow(bottom, edge: .bottom) }
            }
            // ქართული სახელი — მოდულის ქვეშ (სლოტის სიგანეში, რომ ბარათი არ გაგანიერდეს)
            Text(component.name)
                .font(.system(size: 8)).foregroundStyle(Color.black.opacity(0.55))
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(maxWidth: CGFloat(moduleUnits) * kSlotPt - 4)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, photo == nil ? 7 : 1)
        // DIN-მოდულის კორპუსი: სპილოსძვლისფერი გრადიენტი + რელსის ჩამჭიდის ღარი.
        // ფოტო-მოდულს კორპუსი არ სჭირდება — სურათი თავად აჩვენებს კორპუსს.
        .background {
            if photo == nil {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isConnector ? AnyShapeStyle(Color(white: 0.88)) : AnyShapeStyle(ModuleStyle.casing))
                        .shadow(color: .black.opacity(0.20), radius: 2.5, x: 0, y: 1.5)
                    if !isConnector {
                        Rectangle().fill(Color.black.opacity(0.10))
                            .frame(height: 1.6)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(isSelected ? Color.brand : Color.gray.opacity(0.35), lineWidth: isSelected ? 2 : 1))
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red).background(Circle().fill(.white))
                }
                // ოდნავ გარეთ — ზედა კლემებს (IN) არ უნდა ეფაროს.
                .offset(x: 9, y: -9)
            }
        }
        .overlay(alignment: .topLeading) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.brand).background(Circle().fill(.white))
                    .offset(x: -9, y: -9)
            }
        }
        // ჩაჭდობის პულსი — რელსზე დაჯდომისას წამიერი „დაწოლა".
        .scaleEffect(isSnapped ? 1.06 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: isSnapped)
        // კვება ჩართულია და მუშაობს → ყვითელი ჰალო (ნათურა ანათებს).
        .shadow(color: loadState?.isPowered == true ? Color.yellow.opacity(0.55) : .clear,
                radius: loadState?.isPowered == true ? 10 : 0)
        .animation(.easeInOut(duration: 0.25), value: loadState?.isPowered == true)
        // ბარათის ჩარჩო board-სივრცეში (გადაადგილების hit-test).
        .background(GeometryReader { g in
            Color.clear.preference(key: CardFrameKey.self,
                                   value: [component.id: g.frame(in: .named(kBoardSpace))])
        })
        // გრძელი დაჭერა — მონიშვნა (group move). გადათრევას ამუშავებს ფარის ერთიანი ჟესტი.
        .onLongPressGesture(minimumDuration: 0.4) { onLongPress() }
    }

    // MARK: მოდულის სახე — თეთრი კორპუსი, ბერკეტი/ხატულა, ტექ-იარლიყი

    /// DIN-მოდულის სიგანე სლოტებში — ერთიანი წყარო Core-ში (v1.1 Pro Panel).
    private var moduleUnits: Int { component.kind.moduleWidthUnits }
    /// მოდულის სახის სიგანე — სლოტ(ებ)ს ავსებს მცირე ბეჟელით.
    private var faceWidth: CGFloat { CGFloat(moduleUnits) * kSlotPt - 16 }

    /// ფოტო-asset-ის მოსალოდნელი სახელი KIND + POLES-ით (template-id-ის გარეშე):
    /// `<KIND><poles>P`. ნებისმიერი ერთპოლუსიანი ავტომატი → MCB1P, RCD → RCD2P და ა.შ.
    /// asset-ის არსებობა card-ში მოწმდება (`photoAssetName`).
    private var photoAssetBaseName: String? {
        switch component.kind {
        case .mcb:        return "MCB\(component.poles)P"
        case .rcd:        return "RCD\(component.poles)P"
        case .rcbo:       return "RCBO\(component.poles)P"
        case .mpcb:       return "MPCB\(component.poles)P"
        case .mainSwitch: return "MAIN\(component.poles)P"
        case .spd:        return "SPD\(component.poles)P"
        case .contactor:  return "CONTACTOR\(component.poles)P"
        case .relay:      return "RELAY\(component.poles)P"
        default:          return nil
        }
    }

    /// რეალური ფოტო-asset (თუ imageset არსებობს). არ არსებობს → nil → ხელით ხატული
    /// სახე (placeholder-fallback: ცარიელი/ავარია არ ხდება; asset-ის ჩასმისთანავე ჩნდება).
    private var photoAssetName: String? {
        guard let base = photoAssetBaseName else { return nil }
        #if canImport(UIKit)
        return UIImage(named: base) != nil ? base : nil
        #else
        return base
        #endif
    }

    /// ფოტოს ბუნებრივი თანაფარდობა (სიგანე/სიმაღლე) — სიმაღლის ფიქსაციისთვის.
    /// წაკითხულია თავად asset-ის ზომიდან → ნებისმიერი ახალი asset ავტომატურად ჯდება.
    private var photoAspect: CGFloat {
        #if canImport(UIKit)
        if let base = photoAssetBaseName, let img = UIImage(named: base), img.size.height > 0 {
            return img.size.width / img.size.height
        }
        #endif
        return max(0.2, CGFloat(moduleUnits) * 0.29)   // სარეზერვო შეფასება
    }

    /// ფოტო-მოდულის სხეული: სურათი სლოტ-სიგანის ჩარჩოში (scaledToFit, top-aligned),
    /// ფეხების ანკრები/ხრახნი/მოჭერა გადადებული ფოტოს ზედა და ქვედა კლემებზე.
    /// ხატული ბერკეტი იხშობა — ფოტო თავად აჩვენებს ბერკეტს.
    private func photoBody(_ name: String) -> some View {
        let w = CGFloat(moduleUnits) * kSlotPt
        let h = w / photoAspect            // სრული სიმაღლე — თორემ მშობელი ჭყლეტს
        let bottom = outputs + singles
        let leverPt = CGPoint(x: photoLeverAnchor.x * w, y: photoLeverAnchor.y * h)
        return ZStack {
            // სურათი = მოდულის სახე (ერთი accessibility ელემენტი — face-<id>)
            Image(name).resizable().scaledToFit().frame(width: w, height: h)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("face-\(component.id)")
            // გაგდება/კვება — მსუბუქი შეფერილობა (clear → უჩინარი)
            RoundedRectangle(cornerRadius: 4).fill(faceTint).frame(width: w, height: h)
            // გამორთული — ბნელდება + შავი ბერკეტი ქვევით ფოტოს „ON"-ს ფარავს
            if component.isOpen {
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.40))
                    .frame(width: w, height: h)
                photoOffLever.position(leverPt)
            }
            // ფეხების უხილავი hit-zone — ფოტოს ნამდვილ კლემებზე (ცალკე term-<id> ელემენტებად)
            VStack(spacing: 0) {
                if !inputs.isEmpty {
                    HStack(spacing: 7) { ForEach(inputs) { photoTerminal($0, edge: .top) } }
                }
                Spacer(minLength: 0)
                if !bottom.isEmpty {
                    HStack(spacing: 7) { ForEach(bottom) { photoTerminal($0, edge: .bottom) } }
                }
            }
            .padding(.vertical, 9)
            // ბერკეტის შეხების ზონა — ჩართვა/გამორთვა (ფოტოს ბერკეტზე)
            if let onToggleLever {
                Color.clear.frame(width: max(24, w * 0.55), height: 28)
                    .contentShape(Rectangle())
                    .position(leverPt)
                    .onTapGesture { onToggleLever() }
                    .accessibilityIdentifier("lever-\(component.id)")
                    .accessibilityLabel(component.isOpen ? "გამორთული ბერკეტი" : "ჩართული ბერკეტი")
            }
        }
        .frame(width: w, height: h)
    }

    /// ფოტოს ბერკეტის ნორმალიზებული პოზიცია (asset-ის მიხედვით) — OFF-ბერკეტისა და
    /// შეხების ზონისთვის. (პილოტში მცირე per-asset მორგება შესაძლოა დასჭირდეს.)
    private var photoLeverAnchor: CGPoint {
        switch component.kind {
        case .mcb:        return CGPoint(x: 0.50, y: 0.56)
        case .rcd:        return CGPoint(x: 0.33, y: 0.60)
        case .rcbo:       return CGPoint(x: 0.50, y: 0.58)
        case .mainSwitch: return CGPoint(x: 0.50, y: 0.55)
        case .mpcb:       return CGPoint(x: 0.50, y: 0.55)
        default:          return CGPoint(x: 0.50, y: 0.56)
        }
    }

    /// გამორთული ფოტო-მოდულის ბერკეტი ქვედა (OFF) მდგომარეობაში.
    private var photoOffLever: some View {
        VStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.10))
                .frame(width: 11, height: 17)
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.30))
                        .frame(width: 7, height: 2).padding(.bottom, 2)
                }
            Text("OFF").font(.system(size: 6, weight: .heavy)).foregroundStyle(.white)
        }
    }

    /// ფოტო-მოდულის კლემა — უხილავი hit-zone ფოტოს ნამდვილ კლემაზე. ხატული ბუდე/ხრახნი
    /// არ ჩანს (ფოტოს თავისი აქვს); შესული სადენი კი ფოტოს კლემაში „შედის".
    private func photoTerminal(_ port: Port, edge: TerminalEdge) -> some View {
        let selected = selectedPort == port.id
        let live = isLive(port.id)
        let loose = isUntightened(port.id)
        let wired = hasWire(port.id)
        let info = wireInfo(port.id)
        let pressing = pressingPort == port.id
        let outward: CGFloat = edge == .top ? -1 : 1
        return ZStack {
            // შესული სადენი — ფერადი წვერი ფოტოს კლემის ღრუში; ფერული შესასვლელის ბაგესთან
            if let info {
                if info.ferruled {
                    Rectangle().fill(ModuleStyle.ferrule)
                        .frame(width: 4.4, height: 5).offset(y: outward * 6)
                }
                RoundedRectangle(cornerRadius: 1.5).fill(info.color)
                    .frame(width: 5, height: 12).offset(y: -outward * 1)   // შიგნით, კლემაში
            }
            // მოჭერის მინიშნება — ნარინჯისფერი რგოლი კლემაზე (ხრახნის გარეშე); ჭერისას ქრება
            if loose {
                Circle().stroke(Color.orange, lineWidth: 2)
                    .frame(width: 16, height: 16).opacity(pressing ? 0.3 : 0.95)
                Text("🔧").font(.system(size: 7)).offset(x: 8, y: outward * -7)
            }
            if selected { Circle().stroke(Color.yellow, lineWidth: 3).frame(width: 19, height: 19) }
            if live { Circle().stroke(Color.yellow, lineWidth: 2).blur(radius: 2).frame(width: 16, height: 16) }
            // უხილავი hit-zone + board-სივრცის ანკრი (სადენი აქ მიება)
            Color.clear.frame(width: 22, height: 20)
                .background(GeometryReader { g in
                    Color.clear.preference(key: PortFrameKey.self,
                        value: [port.id: CGPoint(x: g.frame(in: .named(kBoardSpace)).midX,
                                                 y: g.frame(in: .named(kBoardSpace)).midY)])
                })
        }
        .frame(width: 22, height: 20)
        .contentShape(Rectangle())
        .onTapGesture { onTapPort(port.id) }
        .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 14) {
            pressingPort = nil
            if loose { onTightenPort(port.id) } else { onLongPress() }
        } onPressingChanged: { p in
            if p { if loose { pressingPort = port.id } }
            else if pressingPort == port.id { pressingPort = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("term-\(port.id)")
        .accessibilityLabel("კლემა \(port.name)")
        .accessibilityValue(loose ? "მოსაჭერია" : (wired ? "მოჭერილია" : "თავისუფალია"))
    }

    private var moduleFace: some View {
        ZStack {
            // კორპუსი: ვერტიკალური გრადიენტი + გვერდითი ბევლები + ფასადის ნაკერები
            RoundedRectangle(cornerRadius: 5)
                .fill(ModuleStyle.body)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.35), lineWidth: 0.8))
                .overlay(alignment: .leading) {   // შუქის ბევლი
                    RoundedRectangle(cornerRadius: 0.8).fill(Color.white.opacity(0.75))
                        .frame(width: 1.1).padding(.vertical, 2.5).padding(.leading, 1.2)
                }
                .overlay(alignment: .trailing) {  // ჩრდილის ბევლი
                    RoundedRectangle(cornerRadius: 0.8).fill(Color.black.opacity(0.10))
                        .frame(width: 1.1).padding(.vertical, 2.5).padding(.trailing, 1.2)
                }
                .overlay(alignment: .top) {       // ზედა ნაკერი
                    Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.7)
                        .padding(.horizontal, 2.5).padding(.top, 4.5)
                }
                .overlay(alignment: .bottom) {    // ქვედა ნაკერი
                    Rectangle().fill(Color.black.opacity(0.08)).frame(height: 0.7)
                        .padding(.horizontal, 2.5).padding(.bottom, 4.5)
                }
            // მდგომარეობის შეფერილობა (გაგდება/კვება) — სახეზე
            RoundedRectangle(cornerRadius: 5).fill(faceTint)
            if component.kind.isSeriesDevice {
                VStack(spacing: 2) {
                    brandPlate
                    if component.kind == .rcd || component.kind == .rcbo {
                        HStack(spacing: 5) { lever; testButton }
                    } else {
                        lever
                    }
                }
                .padding(.vertical, 2)
            } else {
                VStack(spacing: 2) {
                    if component.kind.hasArtwork {
                        Image(component.kind.assetName)
                            .resizable().scaledToFit().frame(height: 24)
                    } else {
                        Image(systemName: component.kind.sfSymbol)
                            .font(.body)
                            .foregroundStyle(iconColor)
                    }
                    if !techLabel.isEmpty { brandPlate }
                }
                .padding(2)
            }
        }
        .frame(width: faceWidth, height: 54)
        .shadow(color: .black.opacity(0.10), radius: 1.5, x: 0, y: 1)
        // როზეტი კვების ქვეშ — მწვანე „ცოცხალი" წერტილი
        .overlay(alignment: .topTrailing) {
            if component.kind == .socket, loadState?.isPowered == true {
                Circle().fill(.green).frame(width: 6, height: 6).padding(4)
            }
        }
        // დატვირთვის მდგომარეობა accessibility-ში (ტესტებisთვის/VoiceOver)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("face-\(component.id)")
        .accessibilityValue(component.kind.isLoad
                            ? (loadState?.isPowered == true ? "ანთია" : "გამორთულია") : "")
    }

    /// ამოტვიფრული/დაბეჭდილი იარლიყი მოდულის სახეზე (brand plate).
    private var brandPlate: some View {
        Text(techLabel)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(Color.black.opacity(0.58))
            .shadow(color: .white.opacity(0.9), radius: 0, x: 0, y: 0.7)   // ამოტვიფრულის ეფექტი
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 3).padding(.vertical, 1)
            .background(RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.55)))
    }

    /// RCD/RCBO-ის TEST ღილაკი (დეკორატიული).
    private var testButton: some View {
        Text("T")
            .font(.system(size: 6, weight: .heavy)).foregroundStyle(.white)
            .frame(width: 10, height: 10)
            .background(RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.78, green: 0.56, blue: 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 2)
                .stroke(Color.black.opacity(0.25), lineWidth: 0.5))
    }

    /// შავი გადამრთველი ბერკეტი — ბრუნავს საყრდენზე (3D გადახრა), I/0 აღნიშვნებით.
    private var lever: some View {
        VStack(spacing: 0.5) {
            Text("I").font(.system(size: 5, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.45))
            ZStack {
                // საყრდენი (pivot)
                Circle().fill(Color(white: 0.35)).frame(width: 5, height: 5)
                // ბერკეტი — გლუვი 3D ბრუნვა ზევით/ქვევით (არა სვაპი), ჰაილაითით
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(ModuleStyle.lever)
                    .frame(width: 11, height: 21)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(0.30))
                            .frame(width: 7, height: 2).padding(.top, 2)
                    }
                    .rotation3DEffect(.degrees(leverUp ? -28 : 28),
                                      axis: (x: 1, y: 0, z: 0),
                                      anchor: .center, perspective: 0.55)
                    .offset(y: leverUp ? -1.5 : 1.5)
            }
            .frame(width: 20, height: 22)
            Text("0").font(.system(size: 5, weight: .heavy))
                .foregroundStyle(Color.black.opacity(0.45))
        }
        .animation(.easeInOut(duration: 0.22), value: leverUp)
        // ბერკეტზე შეხება — ამომრთველის ჩართვა/გამორთვა (toggleable მოწყობილობებზე).
        .contentShape(Rectangle())
        .onTapGesture { onToggleLever?() }
    }

    /// ტექნიკური იარლიყი მოდულის სახეზე (მაგ. "C16", "30mA", "2P").
    private var techLabel: String {
        let k = component.kind
        if k == .rcd { return "\(Int(component.mAtrip ?? 30))mA" }
        if k == .rcbo, let r = component.ratingA {
            return "\(component.curve?.rawValue ?? "B")\(Int(r)) \(Int(component.mAtrip ?? 30))mA"
        }
        if k.isBreaker, let r = component.ratingA {
            return "\(component.curve?.rawValue ?? "C")\(Int(r))"
        }
        switch k {
        case .mainSwitch: return component.poles >= 3 ? "4P" : "2P"
        case .spd:        return "SPD"
        case .supply:     return component.poles >= 3 ? "400V" : "230V"
        default:
            if let r = component.ratingA { return "\(Int(r))A" }
            return ""
        }
    }

    // MARK: ხრახნიანი კლემები (ზედა/ქვედა კიდე) + სალტის ლითონის ზოლი

    /// კლემის მხარე — სადენის ღრუ/ჭდე მოდულისგან გარეთ იყურება.
    enum TerminalEdge { case top, bottom }

    @ViewBuilder
    private func terminalRow(_ ports: [Port], edge: TerminalEdge = .bottom) -> some View {
        let row = HStack(alignment: .top, spacing: 7) {
            ForEach(ports) { terminal($0, edge: edge) }
        }
        if isConnector {
            // სალტე (busbar): ლითონის ზოლი ხრახნებით + გამტარის ფერის მინიშნება
            row
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [Color(white: 0.86), Color(white: 0.64)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(alignment: .top) {
                            busTint
                                .frame(height: 3)
                                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                                .padding(.horizontal, 3).padding(.top, 1.5)
                        }
                )
        } else {
            row
        }
    }

    /// სალტის ფერის მინიშნება: PE → მწვანე-ყვითელი, N → ლურჯი, L → სპილენძი.
    @ViewBuilder
    private var busTint: some View {
        switch component.ports.first?.conductor {
        case .PE: LinearGradient(colors: [.green, .yellow], startPoint: .leading, endPoint: .trailing).opacity(0.85)
        case .N:  Color.blue.opacity(0.7)
        default:  Color.orange.opacity(0.5)
        }
    }

    /// რეალისტური ხრახნიანი კლემა: სპილენძის ბუდე მუქი სადენის-ღრუთი, დაჭრილი
    /// სპილენძის ხრახნი (45° + ამოწეული = მოუჭერელი; 0° + ჩასმული = მოჭერილი),
    /// შესული სადენის იზოლაციის ჭდე და ბუნიკის sleeve. ჭერისას ხრახნი
    /// პროგრესულად ბრუნავს — ადრე აშვება = რჩება მოუჭერელი.
    private func terminal(_ port: Port, edge: TerminalEdge = .bottom) -> some View {
        let selected = selectedPort == port.id
        let live = isLive(port.id)
        let loose = isUntightened(port.id)
        let wired = hasWire(port.id)
        let info = wireInfo(port.id)
        let pressing = pressingPort == port.id
        // ჭრილის კუთხე: მოჭერილი 0°; მოუჭერელი 45°; ჭერისას 45°→4° (პროგრესი)
        let slotAngle: Double = loose ? (pressing ? 4 : 45) : 0
        let outward: CGFloat = edge == .top ? -1 : 1
        return VStack(spacing: 1) {
            ZStack {
                // შესული სადენი: იზოლაციის ფერადი ჭდე (+ ბუნიკის sleeve) ღრუსკენ —
                // ორივე მთლიანად ბუდის გარეთ, რომ ბლოკმა არ დაფაროს.
                if let info {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(info.color)
                        .frame(width: 5, height: 8)
                        .offset(y: outward * (info.ferruled ? 17 : 13.5))
                    if info.ferruled {
                        Rectangle()
                            .fill(ModuleStyle.ferrule)
                            .frame(width: 4.4, height: 4)
                            .offset(y: outward * 11)
                    }
                }
                // სპილენძის კლემის ბუდე გამტარის ფერის კოდით + მუქი სადენის ღრუ
                RoundedRectangle(cornerRadius: 3)
                    .fill(ModuleStyle.brass)
                    .frame(width: 18, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 3)
                        .stroke(port.conductor.swiftUIColor, lineWidth: 1.5))
                    .overlay(alignment: edge == .top ? .top : .bottom) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(white: 0.13))
                            .frame(width: 8, height: 4.5)
                            .padding(edge == .top ? .top : .bottom, 1.2)
                    }
                // დაჭრილი სპილენძის ხრახნი — ამოწეული სანამ მოუჭერელია
                ZStack {
                    Circle().fill(ModuleStyle.screw).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(Color.black.opacity(0.30), lineWidth: 0.6))
                    if loose {
                        Circle().fill(Color.orange.opacity(0.45)).frame(width: 11, height: 11)
                    }
                    Rectangle().fill(Color.black.opacity(0.75))
                        .frame(width: 8.5, height: 1.6)
                        .rotationEffect(.degrees(slotAngle))
                }
                .scaleEffect(loose ? 1.12 : 1.0)                 // ამოწეული თავი
                .offset(y: -outward * 2.2)                       // ღრუს მოპირდაპირედ
                .animation(.linear(duration: 0.42), value: slotAngle)
                .animation(.easeOut(duration: 0.18), value: loose)
            }
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(selected ? Color.yellow : .clear, lineWidth: 3)
                .frame(width: 22, height: 22))
            .overlay { if live { Circle().stroke(Color.yellow, lineWidth: 2).blur(radius: 2) } }
            .overlay(alignment: .topTrailing) {
                if loose { Text("🔧").font(.system(size: 7)).offset(x: 7, y: -6) }
            }
            .background(GeometryReader { g in
                Color.clear.preference(
                    key: PortFrameKey.self,
                    value: [port.id: CGPoint(x: g.frame(in: .named(kBoardSpace)).midX,
                                             y: g.frame(in: .named(kBoardSpace)).midY)])
            })
            Text(port.name).font(.system(size: 8))
                .foregroundStyle(Color.black.opacity(0.5)).lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapPort(port.id) }
        // tap-and-hold (~0.45წმ) — ხრახნი პროგრესულად იჭერა; ადრე აშვება = უკან
        // ბრუნდება. მოჭერილზე გრძელი დაჭერა — ბარათის მონიშვნა (კონექტორებს
        // სახე არ აქვთ და მონიშვნა კლემებიდანაც უნდა შეიძლებოდეს).
        .onLongPressGesture(minimumDuration: 0.45, maximumDistance: 14) {
            pressingPort = nil
            if loose { onTightenPort(port.id) } else { onLongPress() }
        } onPressingChanged: { p in
            // აშვებაზე ყოველთვის ვასუფთავებთ — თუნდაც loose შუა ჭერისას შეიცვალოს.
            if p { if loose { pressingPort = port.id } }
            else if pressingPort == port.id { pressingPort = nil }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("term-\(port.id)")
        .accessibilityLabel("კლემა \(port.name)")
        .accessibilityValue(loose ? "მოსაჭერია" : (wired ? "მოჭერილია" : "თავისუფალია"))
    }

    private var faceTint: Color {
        if let st = loadState {
            if st.trip != nil { return Color.red.opacity(0.28) }
            if st.isPowered { return Color.yellow.opacity(0.40) }
        }
        return .clear
    }

    private var iconColor: Color {
        if let st = loadState {
            if st.trip != nil { return .red }
            // სასიგნალო ნათურა კვების ქვეშ — მწვანედ ანათებს
            if st.isPowered { return component.kind == .indicatorLight ? .green : .orange }
        }
        return component.kind == .supply ? .yellow : Color.black.opacity(0.7)
    }
}

// MARK: - Wires list (targeted deletion for fault-finding)

struct WiresListView: View {
    @ObservedObject var model: WorkbenchModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if model.userWires.isEmpty {
                    Text("სადენები ჯერ არ არის.")
                        .foregroundStyle(.secondary)
                } else {
                    // მხოლოდ მომხმარებლის სადენები — comb-ის ავტო-კბილები არ ჩანს
                    ForEach(model.userWires) { wire in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(wire.color.swiftUIColor)
                                    .frame(width: 14, height: 14)
                                    .overlay(Circle().stroke(.gray.opacity(0.4)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(label(wire.fromPortID))  →  \(label(wire.toPortID))")
                                        .font(.caption)
                                    Text("\(wire.conductorType.cableName(csaMm2: wire.csaMm2)) · \(wire.color.georgianName)")
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
                            // ბუნიკი მხოლოდ მრავალწვერა კაბელისთვისაა აქტუალური (ხრახნიან კლემაში).
                            if wire.conductorType == .stranded {
                                Toggle(isOn: Binding(
                                    get: { wire.ferruled },
                                    set: { model.setFerrule(wire.id, $0) }
                                )) {
                                    Label("ბუნიკი (ferrule)",
                                          systemImage: wire.ferruled ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(wire.ferruled ? .green : .orange)
                                }
                                .accessibilityIdentifier("ferrule-toggle")
                            }
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
