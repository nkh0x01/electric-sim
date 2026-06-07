//
//  Recommender.swift
//  ElectricSim — Core
//
//  მრჩეველი/რეკომენდატორი: მოცემული დატვირთვისთვის გვირჩევს სწორ ავტომატს,
//  კაბელის კვეთასა და RCD-ს; ფარისთვის — ზოგად რეკომენდაციებს.
//  წმინდა ლოგიკა (Foundation), გამოსაცდელი `swift test`-ით.
//

import Foundation

public enum Recommender {

    /// სტანდარტული ავტომატის ნომინალები (A).
    public static let standardBreakers: [Double] = [6, 10, 16, 20, 25, 32, 40, 50, 63]

    /// უწყვეტი დატვირთვის მარაგი (IEC პრაქტიკა).
    public static let designFactor: Double = 1.25

    public struct LoadAdvice: Sendable {
        public let current: Double          // გათვლილი დენი (A)
        public let breakerRatingA: Double
        public let curve: BreakerCurve
        public let csaMm2: Double
        public let cableType: CableType
        public let needsRCD: Bool
        public let summary: String          // ქართული შეჯამება
    }

    /// დატვირთვის მიხედვით სრული რეკომენდაცია.
    public static func advise(kind: ComponentKind, powerW: Double,
                              phase: Phase = .single, cable: CableType = .copper) -> LoadAdvice {
        let threePhase = kind.isThreePhaseLoad || phase == .three
        let current: Double = threePhase
            ? powerW / (Double(3).squareRoot() * Electrical.phaseToPhase)
            : powerW / Electrical.phaseToNeutral

        let needed = current * designFactor
        let rating = standardBreakers.first { $0 >= needed - 0.001 } ?? (standardBreakers.last ?? 63)

        let csaValues: [Double] = Ampacity.table.map { $0.csa }.sorted()
        let csa = csaValues.first { Ampacity.maxBreaker(forCsa: $0, cable: cable) >= rating - 0.001 } ?? (csaValues.last ?? 10)

        let curve = curveFor(kind)
        let rcd = needsRCD(kind)

        var summary = "\(curve.rawValue)\(Int(rating))A ავტომატი + \(formatCsa(csa))mm² (\(cable.georgianName))"
        if rcd { summary += " + RCD 30mA" }
        return LoadAdvice(current: current, breakerRatingA: rating, curve: curve,
                          csaMm2: csa, cableType: cable, needsRCD: rcd, summary: summary)
    }

    public static func curveFor(_ kind: ComponentKind) -> BreakerCurve {
        switch kind {
        case .motor: return .C
        case .airConditioner: return .C
        default: return .B
        }
    }

    public static func needsRCD(_ kind: ComponentKind) -> Bool {
        switch kind {
        case .socket, .socket3ph, .boiler, .heater, .airConditioner:
            return true
        default:
            return false
        }
    }

    // MARK: - ფარის დონის რეკომენდაციები

    public struct Recommendation: Identifiable, Sendable {
        public let id = UUID()
        public let severity: IssueSeverity
        public let message: String
        public let componentIDs: [String]
    }

    public static func boardAdvice(_ board: Board) -> [Recommendation] {
        var recs: [Recommendation] = []

        if !board.components.contains(where: { $0.kind == .mainSwitch }) {
            recs.append(Recommendation(severity: .warning,
                message: "დაამატე მთავარი ამომრთველი ფარის თავში (\(board.phase == .three ? "4P" : "2P")).",
                componentIDs: []))
        }
        if !board.components.contains(where: { $0.kind == .spd }) {
            recs.append(Recommendation(severity: .info,
                message: "რეკომენდებულია SPD ზეძაბვის დამცავი მთავარის შემდეგ.",
                componentIDs: []))
        }
        let hasRCD = board.components.contains { $0.kind == .rcd || $0.kind == .rcbo }
        let hasSocket = board.components.contains { $0.kind == .socket || $0.kind == .socket3ph }
        if hasSocket && !hasRCD {
            recs.append(Recommendation(severity: .warning,
                message: "როზეტებისთვის დაამატე RCD 30mA (ან RCBO).", componentIDs: []))
        }

        for load in board.components where load.kind.isLoad {
            let a = advise(kind: load.kind, powerW: load.powerW ?? 0, phase: board.phase)
            recs.append(Recommendation(severity: .info,
                message: "\(load.name): რეკომენდ. — \(a.summary) (≈\(formatCsa(a.current))A).",
                componentIDs: [load.id]))
        }

        return recs
    }

    // MARK: - დამხმარე

    private static func formatCsa(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
