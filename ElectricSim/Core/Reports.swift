//
//  Reports.swift
//  ElectricSim — Core
//
//  დატვირთვის გრაფის სიმულაცია და ცალხაზოვანი ნახაზი (single-line diagram).
//  წმინდა ლოგიკა (Foundation) — გამოსაცდელი `swift test`-ით; ექსპორტი (CSV/PNG)
//  ხდება აპის ფენაში.
//

import Foundation

// MARK: - Load report (დატვირთვის გრაფი)

public struct LoadLine: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let kind: ComponentKind
    public let phase: Conductor      // L / L1 / L2 / L3
    public let currentA: Double      // ერთ ფაზაზე
    public let powerW: Double
    public let powered: Bool
    public let csaMm2: Double         // ხაზის კაბელის კვეთა (0 თუ უცნობია)
    public let lengthM: Double        // ხაზის სიგრძე (0 თუ უცნობია)
    public let cableType: CableType
    public let conductorType: ConductorType
    public let voltageDropPct: Double // ΔU%
}

public struct LoadReport: Sendable {
    public let lines: [LoadLine]
    public let perPhase: [Conductor: Double]   // L1/L2/L3 (ან L) დენების ჯამი
    public let totalPowerW: Double
    public let totalCurrentA: Double
    public let phase: Phase

    /// ფაზური დისბალანსი 0…1 (0 = იდეალური). მხოლოდ 3 ფაზაზე საინტერესოა.
    public var imbalance: Double {
        let vals: [Double] = [perPhase[.L1] ?? 0, perPhase[.L2] ?? 0, perPhase[.L3] ?? 0]
        guard let mx = vals.max(), mx > 0, let mn = vals.min() else { return 0 }
        return (mx - mn) / mx
    }

    /// CSV ექსპორტი (ცხრილების/ანალიზის პროგრამებისთვის).
    public func csv() -> String {
        var rows = ["id,name,kind,phase,current_A,power_W,powered"]
        for l in lines {
            let name = l.name.replacingOccurrences(of: ",", with: " ")
            rows.append("\(l.id),\(name),\(l.kind.rawValue),\(l.phase.rawValue),"
                        + String(format: "%.2f", l.currentA) + ","
                        + String(format: "%.0f", l.powerW) + ","
                        + (l.powered ? "1" : "0"))
        }
        rows.append("")
        rows.append("TOTAL,,,," + String(format: "%.2f", totalCurrentA) + ","
                    + String(format: "%.0f", totalPowerW) + ",")
        return rows.joined(separator: "\n")
    }
}

// MARK: - Single-line diagram

public struct SLDNode: Identifiable, Sendable {
    public let id: String
    public let kind: ComponentKind
    public let title: String
    public let subtitle: String
}

public struct SLDCircuit: Identifiable, Sendable {
    public let id: String
    public let breaker: SLDNode?
    public let load: SLDNode
    public let csaMm2: Double?
    public let cableType: CableType
}

public struct SingleLineDiagram: Sendable {
    public let phase: Phase
    public let incomer: [SLDNode]      // საერთო ნაწილი: კვება → მთავარი → SPD → RCD
    public let circuits: [SLDCircuit]
}

// MARK: - Builders

extension CircuitSolver {

    /// დატვირთვის გრაფის ანგარიში (დენი/სიმძლავრე თითო ხაზსა და ფაზაზე).
    public func loadReport(_ board: Board) -> LoadReport {
        let result = solve(board, energize: true)
        let labels = analyze(board).portConductors
        var lines: [LoadLine] = []
        var perPhase: [Conductor: Double] = [.L: 0, .L1: 0, .L2: 0, .L3: 0]
        var totalPower = 0.0

        // union-find (სადენები + კონექტორები) — ხაზის კაბელის კვეთის/სიგრძის დასათვლელად.
        let uf = UnionFind()
        for c in board.components { for p in c.ports { uf.makeSet(p.id) } }
        for w in board.wires { uf.union(w.fromPortID, w.toPortID) }
        uf.unionConnectors(board)
        func lineSegments(of comp: Component) -> [Wire] {
            let port = comp.port(conductor: comp.kind.isThreePhaseLoad ? .L1 : .L)
            guard let net = port.map({ uf.find($0.id) }) else { return [] }
            return board.wires.filter { uf.find($0.fromPortID) == net || uf.find($0.toPortID) == net }
        }

        func hotPhase(of comp: Component) -> Conductor {
            for p in comp.ports where p.conductor.isHot {
                if let hot = (labels[p.id] ?? []).first(where: { $0.isHot }) { return hot }
            }
            return comp.ports.first(where: { $0.conductor.isHot })?.conductor ?? .L
        }

        for comp in board.components where comp.kind.isLoad {
            guard let st = result.state(for: comp.id) else { continue }
            let phase = hotPhase(of: comp)
            let power = st.isPowered ? (comp.powerW ?? 0) : 0
            totalPower += power
            let segs = lineSegments(of: comp)
            let csa = segs.map { $0.csaMm2 }.min() ?? 0
            let length = segs.reduce(0) { $0 + $1.lengthM }
            let cable = segs.first?.cableType ?? .copper
            let conductor = segs.first?.conductorType ?? .solid
            let drop = VoltageDrop.percent(currentA: st.currentA, lengthM: length,
                                           csaMm2: csa, cable: cable,
                                           threePhase: comp.kind.isThreePhaseLoad)
            lines.append(LoadLine(id: comp.id, name: comp.name, kind: comp.kind,
                                  phase: phase, currentA: st.currentA, powerW: power,
                                  powered: st.isPowered, csaMm2: csa, lengthM: length,
                                  cableType: cable, conductorType: conductor, voltageDropPct: drop))
            if comp.kind.isThreePhaseLoad {
                for p in [Conductor.L1, .L2, .L3] { perPhase[p, default: 0] += st.currentA }
            } else {
                perPhase[phase, default: 0] += st.currentA
            }
        }

        let total: Double
        if board.phase == .three {
            total = max(perPhase[.L1] ?? 0, perPhase[.L2] ?? 0, perPhase[.L3] ?? 0)
        } else {
            total = perPhase[.L] ?? 0
        }
        return LoadReport(lines: lines, perPhase: perPhase,
                          totalPowerW: totalPower, totalCurrentA: total, phase: board.phase)
    }

    /// ცალხაზოვანი ნახაზი — ფარის სტრუქტურა (კვება → დაცვები → ხაზები).
    public func singleLineDiagram(_ board: Board) -> SingleLineDiagram {
        // union-find (სადენები + კონექტორები; breaker-ის გამოსავალი ↔ დატვირთვის ხაზი).
        let uf = UnionFind()
        for c in board.components { for p in c.ports { uf.makeSet(p.id) } }
        for w in board.wires { uf.union(w.fromPortID, w.toPortID) }
        uf.unionConnectors(board)
        func net(_ id: String) -> String { uf.find(id) }

        // საერთო შემომავალი (წყაროები → მთავარი → SPD → RCD)
        var incomer: [SLDNode] = []
        for c in board.components where c.kind.isSource {
            incomer.append(node(for: c))
        }
        for kind in [ComponentKind.mainSwitch, .spd, .rcd] {
            for c in board.components where c.kind == kind {
                incomer.append(node(for: c))
            }
        }

        // ხაზები: თითო დატვირთვა + მისი breaker + კაბელი
        var circuits: [SLDCircuit] = []
        for load in board.components where load.kind.isLoad {
            let linePort = load.port(conductor: load.kind.isThreePhaseLoad ? .L1 : .L)
            let lineNet = linePort.map { net($0.id) }
            var breakerNode: SLDNode?
            if let lineNet = lineNet {
                if let brk = board.components.first(where: { c in
                    c.kind.isBreaker && c.ports.contains { $0.side == .output && net($0.id) == lineNet }
                }) {
                    breakerNode = node(for: brk)
                }
            }
            let segWires = lineNet.map { ln in board.wires.filter { net($0.fromPortID) == ln || net($0.toPortID) == ln } } ?? []
            let csa = segWires.map { $0.csaMm2 }.min()
            let cable = segWires.first?.cableType ?? .copper
            circuits.append(SLDCircuit(id: load.id, breaker: breakerNode,
                                       load: node(for: load), csaMm2: csa, cableType: cable))
        }

        return SingleLineDiagram(phase: board.phase, incomer: incomer, circuits: circuits)
    }

    private func node(for c: Component) -> SLDNode {
        var sub = ""
        if let r = c.ratingA, c.kind.isBreaker || c.kind == .mainSwitch {
            sub = "\(c.curve?.rawValue ?? "")\(Int(r))A"
        } else if let mA = c.mAtrip {
            sub = "\(Int(mA))mA"
        } else if let p = c.powerW {
            sub = "\(Int(p))W"
        }
        return SLDNode(id: c.id, kind: c.kind, title: c.kind.georgianTitle, subtitle: sub)
    }
}

// MARK: - Georgian titles (Core, UI-ისგან დამოუკიდებელი)

extension ComponentKind {
    public var georgianTitle: String {
        switch self {
        case .supply: return "კვება"
        case .mainSwitch: return "მთავარი"
        case .spd: return "ზეძაბვის დამცავი (SPD)"
        case .rcd: return "დიფ. დამცავი (RCD)"
        case .rcbo: return "დიფ-ავტომატი (RCBO)"
        case .mcb: return "ავტომატი (MCB)"
        case .comb: return "სავარცხელი სალტე"
        case .mpcb: return "ძრავის დამცავი (MPCB)"
        case .contactor: return "კონტაქტორი"
        case .relay: return "რელე"
        case .lightSwitch: return "გამთიშველი"
        case .busbar: return "შინა (busbar)"
        case .wago: return "კლემა (Wago)"
        case .lamp: return "ნათურა"
        case .dimmer: return "დიმერი"
        case .socket: return "როზეტი"
        case .boiler: return "ბოილერი"
        case .oven: return "ღუმელი"
        case .heater: return "გამახურებელი"
        case .airConditioner: return "კონდიციონერი"
        case .motor: return "ძრავა"
        case .socket3ph: return "3-ფაზ. როზეტი"
        case .smartSwitch: return "ჭკვიანი ამომრთ."
        case .smartRelay: return "ჭკვიანი რელე"
        case .smartDimmer: return "ჭკვიანი დიმერი"
        case .smartMeter: return "ჭკვიანი მრიცხ."
        case .fuse: return "დამცველი"
        case .terminalBlock: return "კლემები"
        case .emergencyStop: return "ავარიული გაჩერება"
        case .selectorSwitch: return "გადამრთველი"
        case .indicatorLight: return "სასიგნალო ნათურა"
        case .currentTransformer: return "დენის ტრანსფ. (CT)"
        case .transformer: return "ტრანსფორმატორი"
        case .vfd: return "სიხშ. გარდ. (VFD)"
        case .generator: return "გენერატორი"
        case .solarPanel: return "მზის პანელი"
        case .ups: return "უწყვეტი კვება (UPS)"
        case .inverter: return "ინვერტორი"
        case .battery: return "აკუმულატორი"
        }
    }
}
