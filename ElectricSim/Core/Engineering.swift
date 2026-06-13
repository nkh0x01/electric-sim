//
//  Engineering.swift
//  ElectricSim — Core
//
//  საინჟინრო გათვლები: ძაბვის ვარდნა (ΔU%), სელექტიურობა, მასალების ნუსხა (BOM).
//  წმინდა ლოგიკა (Foundation), გამოსაცდელი `swift test`-ით.
//

import Foundation

// MARK: - Voltage drop (ძაბვის ვარდნა)

public enum VoltageDrop {
    /// ხვედრითი წინაღობა (Ω·mm²/m) 20°C-ზე.
    public static func resistivity(_ cable: CableType) -> Double {
        cable == .copper ? 0.0175 : 0.0282
    }

    /// ΔU% — ძაბვის ვარდნა პროცენტებში.
    public static func percent(currentA: Double, lengthM: Double, csaMm2: Double,
                               cable: CableType, threePhase: Bool) -> Double {
        guard csaMm2 > 0, lengthM > 0, currentA > 0 else { return 0 }
        let u = threePhase ? Electrical.phaseToPhase : Electrical.phaseToNeutral
        let factor = threePhase ? Double(3).squareRoot() : 2.0   // 2L ერთფაზაზე, √3 სამფაზაზე
        let dropV = factor * resistivity(cable) * lengthM * currentA / csaMm2
        return u > 0 ? dropV / u * 100 : 0
    }

    /// დასაშვები ზღვარი (%) — განათება 3%, დანარჩენი 5% (IEC პრაქტიკა).
    public static func limitPct(for kind: ComponentKind) -> Double {
        (kind == .lamp || kind == .dimmer) ? 3 : 5
    }
}

// MARK: - Selectivity (სელექტიურობა / დისკრიმინაცია)

public enum Selectivity {
    /// კოეფიციენტი — ზედა ავტომატი დაბლა მდებარის მინიმუმ 1.6×-ჯერ უნდა აღემატებოდეს.
    public static let ratio: Double = 1.6

    /// არის თუ არა სელექტიური წყვილი (upstream ზემოთ, downstream დაბლა).
    public static func isSelective(upstream: Double, downstream: Double) -> Bool {
        guard downstream > 0 else { return true }
        return upstream >= downstream * ratio - 0.001
    }
}

// MARK: - Bill of materials (მასალების ნუსხა)

public struct BOMItem: Identifiable, Sendable {
    public let id: String          // templateid ან kind
    public let name: String
    public let quantity: Int
    public let unitPriceGEL: Double
    public var totalGEL: Double { Double(quantity) * unitPriceGEL }
}

public struct BillOfMaterials: Sendable {
    public let items: [BOMItem]
    public let cableTotalM: Double
    public let cablePriceGEL: Double
    public var componentsGEL: Double { items.reduce(0) { $0 + $1.totalGEL } }
    public var totalGEL: Double { componentsGEL + cablePriceGEL }
}

public enum BOMBuilder {
    /// კაბელის ფასი ₾/მ კვეთის მიხედვით (ალუმინი ≈0.7×).
    public static func cablePricePerM(csaMm2: Double, cable: CableType) -> Double {
        let base: Double
        switch csaMm2 {
        case ..<2.0: base = 1.5
        case ..<3.0: base = 2.2
        case ..<5.0: base = 3.5
        case ..<8.0: base = 5.0
        default:     base = 8.0
        }
        return base * (cable == .copper ? 1.0 : 0.7)
    }

    /// სარეზერვო ფასი თუ შაბლონს არ აქვს მითითებული.
    public static func fallbackPrice(_ kind: ComponentKind) -> Double {
        switch kind {
        case .mainSwitch: return 25
        case .spd: return 60
        case .rcd: return 55
        case .rcbo: return 45
        case .mcb: return 12
        case .mpcb: return 70
        case .contactor: return 35
        case .relay, .lightSwitch: return 10
        case .busbar, .comb, .wago: return 8
        case .lamp, .dimmer: return 15
        case .socket, .socket3ph: return 12
        case .boiler: return 350
        case .oven: return 600
        case .heater: return 120
        case .airConditioner: return 900
        case .motor: return 800
        case .smartSwitch, .smartRelay, .smartDimmer: return 45
        case .smartMeter: return 90
        case .fuse: return 6
        case .terminalBlock: return 5
        case .emergencyStop: return 22
        case .selectorSwitch: return 18
        case .indicatorLight: return 6
        case .currentTransformer: return 25
        case .transformer: return 400
        case .vfd: return 650
        case .generator: return 3500
        case .solarPanel: return 250
        case .ups: return 700
        case .inverter: return 900
        case .battery: return 500
        case .supply: return 0
        }
    }

    public static func build(_ board: Board) -> BillOfMaterials {
        var counts: [String: Int] = [:]
        var price: [String: Double] = [:]
        var kindOf: [String: ComponentKind] = [:]
        for c in board.components where c.kind != .supply {
            counts[c.name, default: 0] += 1
            price[c.name] = c.priceGEL ?? fallbackPrice(c.kind)
            kindOf[c.name] = c.kind
        }
        let items = counts.keys.sorted().map { name in
            BOMItem(id: name, name: name, quantity: counts[name] ?? 0,
                    unitPriceGEL: price[name] ?? 0)
        }
        let totalM = board.wires.reduce(0.0) { $0 + $1.lengthM }
        let cableGEL = board.wires.reduce(0.0) {
            $0 + $1.lengthM * cablePricePerM(csaMm2: $1.csaMm2, cable: $1.cableType)
        }
        return BillOfMaterials(items: items, cableTotalM: totalM, cablePriceGEL: cableGEL)
    }
}

// MARK: - Protective chain + selectivity analysis

extension CircuitSolver {

    /// დატვირთვის დამცავი ავტომატების ჯაჭვი (ახლოდან შორს: branch → main).
    public func protectiveChain(_ board: Board, loadID: String) -> [Component] {
        guard let load = board.components.first(where: { $0.id == loadID }) else { return [] }
        let uf = UnionFind()
        for c in board.components { for p in c.ports { uf.makeSet(p.id) } }
        for w in board.wires { uf.union(w.fromPortID, w.toPortID) }
        uf.unionConnectors(board)
        func net(_ id: String) -> String { uf.find(id) }

        struct Edge { let comp: Component; let inNet: String; let outNet: String }
        var edges: [Edge] = []
        for comp in board.components where comp.kind.isSeriesDevice {
            for c in Set(comp.ports.map { $0.conductor }) where c.isHot {
                guard let i = comp.port(side: .input, conductor: c),
                      let o = comp.port(side: .output, conductor: c) else { continue }
                edges.append(Edge(comp: comp, inNet: net(i.id), outNet: net(o.id)))
            }
        }
        var supplyNets = Set<String>()
        for s in board.components where s.kind.isSource {
            for p in s.ports where p.side == .output && p.conductor.isHot { supplyNets.insert(net(p.id)) }
        }
        var parentDevice: [String: Component] = [:]
        var parentNet: [String: String] = [:]
        var visited = supplyNets
        var queue = Array(supplyNets)
        while !queue.isEmpty {
            let cur = queue.removeFirst()
            for e in edges {
                let nb: String? = e.inNet == cur ? e.outNet : (e.outNet == cur ? e.inNet : nil)
                if let nb, !visited.contains(nb) {
                    visited.insert(nb); parentDevice[nb] = e.comp; parentNet[nb] = cur; queue.append(nb)
                }
            }
        }
        let linePort = load.port(conductor: load.kind.isThreePhaseLoad ? .L1 : .L)
        guard var cur = linePort.map({ net($0.id) }) else { return [] }
        var chain: [Component] = []
        while let dev = parentDevice[cur] {
            if dev.kind.isBreaker { chain.append(dev) }
            guard let up = parentNet[cur] else { break }
            cur = up
        }
        return chain
    }

    /// სელექტიურობის გაფრთხილებები (ზედა ავტომატი დაბლას ≥1.6×).
    public func selectivityIssues(_ board: Board) -> [Recommender.Recommendation] {
        var recs: [Recommender.Recommendation] = []
        var seen = Set<String>()
        for load in board.components where load.kind.isLoad {
            let chain = protectiveChain(board, loadID: load.id)
            guard chain.count >= 2 else { continue }
            for i in 0..<(chain.count - 1) {
                let down = chain[i], up = chain[i + 1]
                guard let dr = down.ratingA, let ur = up.ratingA else { continue }
                if !Selectivity.isSelective(upstream: ur, downstream: dr) {
                    let key = up.id + "|" + down.id
                    if seen.contains(key) { continue }
                    seen.insert(key)
                    recs.append(Recommender.Recommendation(
                        severity: .warning,
                        message: "სელექტიურობა: \(up.name) (\(Int(ur))A) ↔ \(down.name) (\(Int(dr))A) — ზედა ავტომატი დაბლას მინიმუმ 1.6×-ით უნდა აღემატებოდეს, რომ მხოლოდ დაზიანებული ხაზი გაითიშოს.",
                        componentIDs: [up.id, down.id]))
                }
            }
        }
        return recs
    }
}
