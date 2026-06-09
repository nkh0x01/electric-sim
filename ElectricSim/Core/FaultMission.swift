//
//  FaultMission.swift
//  ElectricSim — Core
//
//  Fault-finding მისიები — Phase 1: მონაცემთა მოდელი + დეფექტის ინჟექცია +
//  დიაგნოსტიკის ძრავა (UI გარეშე). იყენებს არსებულ Board/CircuitSolver/
//  SimulationResult-ს — solver არ იფორკება.
//
//  იდეა: მისია ინახავს *ჯანსაღ* წინასწარ-აწყობილ ფარს (PrebuiltBoard) + `fault`
//  (BoardEdit), რომელიც ფარს დეფექტს ამატებს. `fix` (BoardEdit) კი ასწორებს.
//  იგივე BoardEdit ტიპი გამოიყენება ინჟექციისა და შესწორებისთვის (სიმეტრიული).
//

import Foundation

// MARK: - Fault type

/// დეფექტის ტიპი (დიაგნოზი). ka labels UI-სთვის.
public enum FaultType: String, Codable, Sendable, CaseIterable {
    case shortCircuitLN
    case shortCircuitLPE
    case missingPE
    case reversedPolarity
    case earthLeakage
    case missingRCD
    case wrongBreakerSize
    case overloadedCable
    case wrongCableSize
    case sharedNeutral
    case nuisanceRCDTrip
    case failedSPD
    case missingSPD
    case wrongPhaseSequence
    case unbalanced3ph
    case looseNeutral

    public var georgian: String {
        switch self {
        case .shortCircuitLN:    return "მოკლე ჩართვა (ფაზა–ნული)"
        case .shortCircuitLPE:   return "მოკლე ჩართვა (ფაზა–მიწა)"
        case .missingPE:         return "დამცავი მიწა (PE) აკლია"
        case .reversedPolarity:  return "არეული პოლარობა (L/N)"
        case .earthLeakage:      return "დენის გაჟონვა მიწაზე"
        case .missingRCD:        return "RCD დაცვა აკლია"
        case .wrongBreakerSize:  return "არასწორი ნომინალის ავტომატი"
        case .overloadedCable:   return "გადატვირთული კაბელი"
        case .wrongCableSize:    return "არასწორი კვეთის კაბელი"
        case .sharedNeutral:     return "გაზიარებული ნული"
        case .nuisanceRCDTrip:   return "RCD-ის ცრუ გაგდება"
        case .failedSPD:         return "გაუმართავი SPD"
        case .missingSPD:        return "SPD აკლია"
        case .wrongPhaseSequence: return "ფაზების არასწორი თანმიმდევრობა"
        case .unbalanced3ph:     return "ფაზების დისბალანსი"
        case .looseNeutral:      return "შესუსტებული ნულის კონტაქტი"
        }
    }
}

// MARK: - Board edit (ერთიანი ტიპი ინჟექციისა და შესწორებისთვის)

/// ფარზე ცვლილებების data-driven აღწერა. იყენებენ `fault` (დეფექტის დამატება) და
/// `fix` (შესწორება). ცარიელი BoardEdit — არაფერს ცვლის.
public struct BoardEdit: Codable, Sendable {
    public var setRatingA: [String: Double]?     // componentID → ახალი ნომინალი (A)
    public var setLeakageMa: [String: Double]?   // componentID → გაჟონვა (0 = გაწმენდა)
    public var setAllCsaMm2: Double?             // ყველა სადენის კვეთა (mm²)
    public var addWires: [PrebuiltWire]?         // დასამატებელი სადენები (მაგ. PE)
    public var removeWires: [PrebuiltWire]?      // წასაშლელი სადენები (ემთხვევა ფეხებით)

    public init(setRatingA: [String: Double]? = nil,
                setLeakageMa: [String: Double]? = nil,
                setAllCsaMm2: Double? = nil,
                addWires: [PrebuiltWire]? = nil,
                removeWires: [PrebuiltWire]? = nil) {
        self.setRatingA = setRatingA
        self.setLeakageMa = setLeakageMa
        self.setAllCsaMm2 = setAllCsaMm2
        self.addWires = addWires
        self.removeWires = removeWires
    }

    /// ცვლილებების გამოყენება Board-ზე.
    public func apply(to board: inout Board) {
        if let ratings = setRatingA {
            for (id, v) in ratings { mutate(id, &board) { $0.ratingA = v } }
        }
        if let leaks = setLeakageMa {
            for (id, v) in leaks { mutate(id, &board) { $0.leakageMa = (v == 0 ? nil : v) } }
        }
        if let csa = setAllCsaMm2 {
            for i in board.wires.indices { board.wires[i].csaMm2 = csa }
        }
        if let rem = removeWires {
            for w in rem {
                board.wires.removeAll { samePorts($0, w.from.portID, w.to.portID) }
            }
        }
        if let add = addWires {
            for w in add {
                let color = w.color.flatMap { WireColor(rawValue: $0) }
                    ?? WireColor.standard(for: board.port(w.from.portID)?.conductor ?? .L)
                board.connect(w.from.portID, w.to.portID, csaMm2: w.csa, color: color)
            }
        }
    }

    private func mutate(_ id: String, _ board: inout Board, _ change: (inout Component) -> Void) {
        guard let idx = board.components.firstIndex(where: { $0.id == id }) else { return }
        var comp = board.components[idx]
        change(&comp)
        board.components[idx] = comp
    }

    private func samePorts(_ wire: Wire, _ a: String, _ b: String) -> Bool {
        (wire.fromPortID == a && wire.toPortID == b) ||
        (wire.fromPortID == b && wire.toPortID == a)
    }
}

// MARK: - Fault mission (faults.json)

public struct FaultMission: Codable, Identifiable, Sendable {
    public let id: String
    public let georgianTitle: String
    public let customerName: String
    public let location: String
    public let difficulty: Int            // 1...5
    public let tier: LevelTier            // free / pro
    public let customerComplaint: String  // ka
    public let symptoms: [String]         // ka
    public let faultType: FaultType       // სწორი დიაგნოზი
    public let phase: Phase?              // nil → single
    public let board: PrebuiltBoard       // ჯანსაღი საბაზისო ფარი
    public let fault: BoardEdit           // დეფექტის ინჟექცია
    public let fix: BoardEdit             // სწორი შესწორება
    public let xpReward: Int
    public let cashReward: Int

    public var resolvedPhase: Phase { phase ?? .single }
    public var resolvedDifficulty: Int { min(5, max(1, difficulty)) }

    /// ჯანსაღი ფარი (დეფექტამდე).
    public func baseBoard(templates: [String: ComponentTemplate]) -> Board {
        board.build(phase: resolvedPhase, templates: templates)
    }
    /// დეფექტიანი ფარი (ბაზისი + fault).
    public func faultedBoard(templates: [String: ComponentTemplate]) -> Board {
        var b = baseBoard(templates: templates)
        fault.apply(to: &b)
        return b
    }
    /// შესწორებული ფარი (დეფექტიანი + fix).
    public func repairedBoard(templates: [String: ComponentTemplate]) -> Board {
        var b = faultedBoard(templates: templates)
        fix.apply(to: &b)
        return b
    }
}

// MARK: - Fault engine (დიაგნოსტიკა + შესწორების ვერიფიკაცია)

public enum FaultEngine {
    private static let solver = CircuitSolver()

    /// ფარი ელექტრულად გამართულია? (Test რეჟიმი — გაგდებებიც ფასდება).
    public static func boardPasses(_ board: Board) -> Bool {
        solver.solve(board, energize: true).passed
    }

    /// დეფექტიანი ფარის ელექტრულად-სწორი დიაგნოზი (faultType) ან nil.
    /// IEC: ავტომატი ≤ კაბელის ampacity, როზეტს სჭირდება RCD, ყველა ხაზს PE და ა.შ.
    public static func diagnose(_ board: Board) -> FaultType? {
        let r = solver.solve(board, energize: true)
        if r.contains(.shortPhasePhase)       { return .shortCircuitLN }
        if r.contains(.shortLN)               { return .shortCircuitLN }
        if r.contains(.shortLPE)              { return .shortCircuitLPE }
        if r.contains(.shortNPE)              { return .sharedNeutral }
        if r.contains(.polarityReversed)      { return .reversedPolarity }
        if r.contains(.missingPE)             { return .missingPE }
        if r.contains(.breakerExceedsCable)   { return .wrongBreakerSize }
        if r.contains(.leakageTrip)           { return .earthLeakage }
        if r.contains(.shockRisk)             { return .earthLeakage }
        let leaking = board.components.contains { ($0.leakageMa ?? 0) > 0 }
        if leaking && r.contains(.socketWithoutRCD) { return .earthLeakage }
        if r.contains(.socketWithoutRCD)      { return .missingRCD }
        if r.contains(.overload)              { return .overloadedCable }
        if r.contains(.phaseImbalance)        { return .unbalanced3ph }
        return nil
    }

    /// შემოთავაზებული შესწორება აგვარებს დეფექტს? (ფარი ხდება ელექტრულად გამართული).
    public static func fixResolves(faulted: Board, fix: BoardEdit) -> Bool {
        var b = faulted
        fix.apply(to: &b)
        return boardPasses(b)
    }
}
