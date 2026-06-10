//
//  CircuitSolver+Analysis.swift
//  ElectricSim — Core
//
//  მსუბუქი ანალიზი ხელსაწყოებისთვის (მულტიმეტრი / ფაზის ინდიკატორი).
//  ითვლის თითო ფეხის ელექტრულ ქსელზე მისულ გამტარის იარლიყებს.
//

import Foundation

public struct NetAnalysis: Sendable {
    /// ფეხის id → მასზე მისული გამტარები (L/N/PE…).
    public let portConductors: [String: Set<Conductor>]
}

extension CircuitSolver {

    /// აშენებს ქსელებს და აბრუნებს თითო ფეხის გამტარულ იარლიყებს.
    public func analyze(_ board: Board) -> NetAnalysis {
        let uf = UnionFind()
        for comp in board.components { for p in comp.ports { uf.makeSet(p.id) } }
        for wire in board.wires {
            uf.makeSet(wire.fromPortID); uf.makeSet(wire.toPortID)
            uf.union(wire.fromPortID, wire.toPortID)
        }
        for comp in board.components where comp.kind.isConnector {
            if let first = comp.ports.first {
                for p in comp.ports.dropFirst() { uf.union(first.id, p.id) }
            }
        }
        func net(_ id: String) -> String { uf.find(id) }

        var labels: [String: Set<Conductor>] = [:]
        for src in board.components where src.kind.isSource {
            for p in src.ports where p.side == .output {
                labels[net(p.id), default: []].insert(p.conductor)
            }
        }

        // მიმდევრობითი მოწყობილობების კიდეები
        struct E { let inNet: String; let outNet: String }
        var edges: [E] = []
        for comp in board.components where comp.kind.isSeriesDevice {
            for c in Set(comp.ports.map { $0.conductor }) {
                guard let i = comp.port(side: .input, conductor: c),
                      let o = comp.port(side: .output, conductor: c) else { continue }
                edges.append(E(inNet: net(i.id), outNet: net(o.id)))
            }
        }
        var changed = true
        while changed {
            changed = false
            for e in edges {
                let merged = (labels[e.inNet] ?? []).union(labels[e.outNet] ?? [])
                if merged != (labels[e.inNet] ?? []) || merged != (labels[e.outNet] ?? []) {
                    labels[e.inNet] = merged
                    labels[e.outNet] = merged
                    changed = true
                }
            }
        }

        var portMap: [String: Set<Conductor>] = [:]
        for comp in board.components {
            for p in comp.ports { portMap[p.id] = labels[net(p.id)] ?? [] }
        }
        return NetAnalysis(portConductors: portMap)
    }

    /// მულტიმეტრი — ძაბვა ორ ფეხს შორის (V).
    public func measureVoltage(_ board: Board, _ a: String, _ b: String) -> Double {
        let m = analyze(board).portConductors
        let sa = m[a] ?? [], sb = m[b] ?? []
        let aHot = sa.contains { $0.isHot }, bHot = sb.contains { $0.isHot }
        let aN = sa.contains(.N) || sa.contains(.PE)
        let bN = sb.contains(.N) || sb.contains(.PE)
        let aHotPhases = sa.filter { $0.isHot }
        let bHotPhases = sb.filter { $0.isHot }
        if aHot && bHot {
            // ფაზა–ფაზა, თუ განსხვავებული ფაზებია → 400V, თუ ერთი და იგივე → 0
            return aHotPhases == bHotPhases ? 0 : Electrical.phaseToPhase
        }
        if (aHot && bN) || (bHot && aN) { return Electrical.phaseToNeutral }
        return 0
    }

    /// ფაზის ინდიკატორი — არის თუ არა ფეხზე ფაზა.
    public func isLive(_ board: Board, _ port: String) -> Bool {
        (analyze(board).portConductors[port] ?? []).contains { $0.isHot }
    }
}

// MARK: - Live-wire safety

/// Live-wire უსაფრთხოების ლოგიკა — ცოცხალ (energized) ფარზე რედაქტირების შემოწმება
/// და შოკის ჯარიმის დათვლა. სუფთა, Foundation-only და ტესტირებადი (UI-ს გარეშე).
public enum LiveWire {

    /// პორტი „ცოცხალია" (ფაზაზეა) NetAnalysis-ის მიხედვით.
    public static func isPortLive(_ analysis: NetAnalysis, _ portID: String) -> Bool {
        (analysis.portConductors[portID] ?? []).contains { $0.isHot }
    }

    /// კომპონენტი ცოცხალია — რომელიმე ფეხი ფაზაზეა.
    public static func isComponentLive(_ analysis: NetAnalysis, _ component: Component) -> Bool {
        component.ports.contains { isPortLive(analysis, $0.id) }
    }

    /// რედაქტირება დაბლოკილია? მხოლოდ მაშინ, თუ ფარი ჩართულია (energized) და
    /// რომელიმე შესახები ფეხი ცოცხალია. გამორთულ ფარზე / nil ანალიზზე — false.
    public static func isEditBlocked(energized: Bool,
                                     analysis: NetAnalysis?,
                                     touchingPorts ports: [String]) -> Bool {
        guard energized, let analysis else { return false }
        return ports.contains { isPortLive(analysis, $0) }
    }

    /// შოკის ჯარიმის ოდენობა ჯილდოს მიხედვით (default 10%, დამრგვალებული, floor 0).
    public static func shockPenalty(reward: Int, fraction: Double = 0.10) -> Int {
        max(0, Int((Double(reward) * fraction).rounded()))
    }
}
