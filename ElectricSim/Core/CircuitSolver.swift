//
//  CircuitSolver.swift
//  ElectricSim — Core
//
//  გრაფზე დაფუძნებული წრედის ამომხსნელი.
//    • node  = ფეხი (terminal / port)
//    • edge  = სადენი (wire) ან კომპონენტის შიდა გამტარობა (closed device)
//
//  ალგორითმი:
//    1. სადენებითა და კონექტორებით ფეხები ერთიანდება ელექტრულ ქსელებად (nets).
//    2. კვებიდან ვრცელდება გამტარის იარლიყი (L/N/PE) მიმდევრობითი მოწყობილობების გავლით.
//    3. მოწმდება ვალიდაციის წესები (short, polarity, PE, RCD, ampacity).
//    4. Test რეჟიმში — გამოითვლება დენი (I = P/U) და დამცავების გაგდება.
//

import Foundation

public struct CircuitSolver {

    public init() {}

    // MARK: შიდა სტრუქტურები

    /// მიმდევრობითი მოწყობილობის ერთი პოლუსის გამტარი კავშირი.
    private struct SeriesEdge {
        let component: Component
        let conductor: Conductor
        let inNet: String
        let outNet: String
    }

    // MARK: მთავარი მეთოდი

    /// აანალიზებს ფარს. `energize == true` → Test/Power რეჟიმი (დენი, გაგდებები).
    public func solve(_ board: Board, energize: Bool = false) -> SimulationResult {
        var issues: [Issue] = []
        var loadStates: [LoadState] = []

        // --- 1. ქსელების აგება (union-find) ---
        let uf = UnionFind()
        for comp in board.components {
            for port in comp.ports { uf.makeSet(port.id) }
        }
        // სადენები
        for wire in board.wires {
            uf.makeSet(wire.fromPortID)
            uf.makeSet(wire.toPortID)
            uf.union(wire.fromPortID, wire.toPortID)
        }
        // კონექტორები — busbar ერთ ქსელში; comb ფაზებად (იხ. unionConnectors)
        uf.unionConnectors(board)

        func net(_ portID: String) -> String { uf.find(portID) }

        // --- 2. კვების ქსელები (ერთი ან მეტი წყარო) ---
        let sources = board.components.filter { $0.kind.isSource }
        guard !sources.isEmpty else {
            issues.append(Issue(code: .noSupply))
            return SimulationResult(issues: issues, loadStates: [], energized: false)
        }
        var sourceSeeds: [(Conductor, String)] = []
        for src in sources {
            for port in src.ports where port.side == .output {
                sourceSeeds.append((port.conductor, net(port.id)))
            }
        }

        // --- 3. მიმდევრობითი მოწყობილობების კიდეები (closed) ---
        var seriesEdges: [SeriesEdge] = []
        for comp in board.components where comp.kind.isSeriesDevice {
            // თითო პოლუსზე input ↔ output (SPD-ს არ ვითვლით — ის შუნტია და ჩვეულებრივ ღიაა)
            let compConductors = Set(comp.ports.map { $0.conductor })
            for c in compConductors {
                guard let inP = comp.port(side: .input, conductor: c),
                      let outP = comp.port(side: .output, conductor: c) else { continue }
                seriesEdges.append(SeriesEdge(component: comp, conductor: c,
                                              inNet: net(inP.id), outNet: net(outP.id)))
            }
        }

        // --- 4. იარლიყების გავრცელება (ორმხრივად, fixpoint) ---
        var labels: [String: Set<Conductor>] = [:]
        for (c, n) in sourceSeeds { labels[n, default: []].insert(c) }
        var changed = true
        while changed {
            changed = false
            for e in seriesEdges {
                let before = (labels[e.inNet]?.count ?? 0) + (labels[e.outNet]?.count ?? 0)
                let merged = (labels[e.inNet] ?? []).union(labels[e.outNet] ?? [])
                labels[e.inNet] = merged
                labels[e.outNet] = merged
                if merged.count * 2 != before { changed = true }
            }
        }
        func conductors(of portID: String) -> Set<Conductor> { labels[net(portID)] ?? [] }

        // --- 5. მოკლე ჩართვის აღმოჩენა ---
        // ქსელი, რომელშიც ერთზე მეტი განსხვავებული გამტარია → short.
        var shortedNets: Set<String> = []
        for (n, set) in labels where set.count >= 2 {
            shortedNets.insert(n)
            let hasHot = set.contains { $0.isHot }
            let hots = set.filter { $0.isHot }
            if hots.count >= 2 {
                issues.append(Issue(code: .shortPhasePhase))
            } else if hasHot && set.contains(.N) {
                issues.append(Issue(code: .shortLN))
            } else if hasHot && set.contains(.PE) {
                issues.append(Issue(code: .shortLPE))
            } else if set.contains(.N) && set.contains(.PE) {
                issues.append(Issue(code: .shortNPE))
            }
        }

        // --- 6. კვების მიმართულებით feed-tree (რომელ მოწყობილობა-ჯაჭვი კვებავს ქსელს) ---
        // BFS L-ქსელ(ებ)იდან; თითო ქსელისთვის ვინახავთ მშობელ მოწყობილობას.
        var parentDevice: [String: Component] = [:]   // net -> მისი მკვებავი device
        var parentNet: [String: String] = [:]         // net -> ზემოთა net
        var queue: [String] = []
        var visited: Set<String> = []
        for (c, n) in sourceSeeds where c.isHot {
            if !visited.contains(n) { queue.append(n); visited.insert(n) }
        }
        while !queue.isEmpty {
            let cur = queue.removeFirst()
            for e in seriesEdges where e.conductor.isHot {
                // მოწყობილობა cur-ს უკავშირდება ერთ-ერთი ბოლოთი
                let neighbor: String?
                if e.inNet == cur { neighbor = e.outNet }
                else if e.outNet == cur { neighbor = e.inNet }
                else { neighbor = nil }
                if let nb = neighbor, !visited.contains(nb) {
                    visited.insert(nb)
                    parentDevice[nb] = e.component
                    parentNet[nb] = cur
                    queue.append(nb)
                }
            }
        }

        /// დატვირთვის ფაზურ ქსელამდე მკვებავი მიმდევრობითი მოწყობილობების ჯაჭვი (ახლოდან შორს).
        func deviceChain(forHotNet hotNet: String) -> [Component] {
            var chain: [Component] = []
            var cur = hotNet
            while let dev = parentDevice[cur] {
                chain.append(dev)
                guard let up = parentNet[cur] else { break }
                cur = up
            }
            return chain
        }

        // --- 7. დატვირთვების ვალიდაცია ---
        var phaseCurrent: [Conductor: Double] = [.L1: 0, .L2: 0, .L3: 0]
        let loads = board.components.filter { $0.kind.isLoad }
        for load in loads {
            // 3-ფაზიანი დატვირთვა (მოტორი / 3-ფაზ. როზეტი) — L1/L2/L3 + PE
            if load.kind.isThreePhaseLoad {
                let phases: [Conductor] = [.L1, .L2, .L3]
                var allPresent = true
                var seen = Set<Conductor>()
                for ph in phases {
                    guard let p = load.port(conductor: ph) else { allPresent = false; break }
                    if let hot = conductors(of: p.id).first(where: { $0.isHot }) {
                        seen.insert(hot)
                    } else { allPresent = false }
                }
                let complete = allPresent && seen.count >= 3
                var mTrip: TripType? = nil

                if load.requiresPE {
                    let peOK = load.port(conductor: .PE).map { conductors(of: $0.id).contains(.PE) } ?? false
                    if !peOK { issues.append(Issue(code: .missingPE, componentIDs: [load.id])) }
                }
                if !complete { issues.append(Issue(code: .openCircuit, componentIDs: [load.id])) }

                let l1Net = load.port(conductor: .L1).map { net($0.id) }
                let chain = l1Net.map { deviceChain(forHotNet: $0) } ?? []
                let breaker = chain.first { $0.kind.isBreaker }
                let rcdInPath = chain.contains { $0.kind == .rcd || $0.kind == .rcbo }
                if complete && breaker == nil {
                    issues.append(Issue(code: .noBreaker, componentIDs: [load.id]))
                }
                // 3-ფაზიანი როზეტი → RCD სავალდებულო
                if load.kind == .socket3ph && complete && !rcdInPath {
                    issues.append(Issue(code: .socketWithoutRCD, componentIDs: [load.id]))
                }

                // სამფაზიანი დენი: I = P / (√3 · U_LL)
                let perPhase = complete ? (load.powerW ?? 0) / (Double(3).squareRoot() * Electrical.phaseToPhase) : 0

                if complete {
                    if let rating = breaker?.ratingA, let l1Net = l1Net {
                        let seg = board.wires.filter { net($0.fromPortID) == l1Net || net($0.toPortID) == l1Net }
                        if let allowed = seg.map({ Ampacity.maxBreaker(forCsa: $0.csaMm2, cable: $0.cableType) }).min(),
                           rating > allowed + 0.001 {
                            issues.append(Issue(code: .breakerExceedsCable, componentIDs: [load.id]))
                        }
                    }
                    if energize {
                        let anyShort = phases.contains { ph in
                            load.port(conductor: ph).map { shortedNets.contains(net($0.id)) } ?? false
                        }
                        if anyShort {
                            mTrip = .magnetic
                            issues.append(Issue(code: .shortCircuit, componentIDs: [load.id]))
                        } else if let rating = breaker?.ratingA, perPhase > rating + 0.001 {
                            mTrip = .thermal
                            issues.append(Issue(code: .overload, componentIDs: [load.id]))
                        }
                    }
                    for ph in phases { phaseCurrent[ph, default: 0] += perPhase }
                }
                let powered = complete && mTrip == nil && energize
                loadStates.append(LoadState(id: load.id, isPowered: powered, currentA: perPhase, trip: mTrip))
                continue
            }

            guard let lineP = load.port(conductor: .L),
                  let neutralP = load.port(conductor: .N) else { continue }
            let lineNet = net(lineP.id)
            let neutralNet = net(neutralP.id)
            let lineSet = conductors(of: lineP.id)
            let neutralSet = conductors(of: neutralP.id)

            var trip: TripType? = nil
            var shockRisk = false

            // 7a. პოლარობა
            let lineHasHot = lineSet.contains { $0.isHot }
            let lineHasN = lineSet.contains(.N)
            if lineHasN && !lineHasHot {
                issues.append(Issue(code: .polarityReversed, componentIDs: [load.id]))
            }

            // 7b. PE
            if load.requiresPE {
                if let peP = load.port(conductor: .PE) {
                    let peSet = conductors(of: peP.id)
                    if !peSet.contains(.PE) {
                        issues.append(Issue(code: .missingPE, componentIDs: [load.id]))
                    }
                } else {
                    issues.append(Issue(code: .missingPE, componentIDs: [load.id]))
                }
            }

            // 7c. წრედის სისრულე
            let circuitComplete = lineHasHot && neutralSet.contains(.N)
            if !circuitComplete {
                issues.append(Issue(code: .openCircuit, componentIDs: [load.id]))
            }

            // 7d. მკვებავი ჯაჭვი / ავტომატი / RCD
            let chain = deviceChain(forHotNet: lineNet)
            let breaker = chain.first { $0.kind.isBreaker }
            let rcdInPath = chain.contains { $0.kind == .rcd || $0.kind == .rcbo }

            if lineHasHot && breaker == nil {
                issues.append(Issue(code: .noBreaker, componentIDs: [load.id]))
            }

            // 7e. როზეტი → RCD სავალდებულო
            if load.kind == .socket && !rcdInPath {
                issues.append(Issue(code: .socketWithoutRCD, componentIDs: [load.id]))
            }

            // 7f. ampacity: ავტომატი ≤ კაბელის დასაშვები დენი
            if let breaker = breaker, let rating = breaker.ratingA {
                let segWires = board.wires.filter {
                    net($0.fromPortID) == lineNet || net($0.toPortID) == lineNet
                }
                if let allowed = segWires.map({ Ampacity.maxBreaker(forCsa: $0.csaMm2, cable: $0.cableType) }).min(),
                   rating > allowed + 0.001 {
                    issues.append(Issue(code: .breakerExceedsCable,
                                        componentIDs: [breaker.id, load.id]))
                }
            }

            // 7g. დენის გამოთვლა
            let voltage = Electrical.phaseToNeutral
            let power = load.powerW ?? 0
            let current = circuitComplete ? power / voltage : 0

            // --- 8. Test/Power რეჟიმი: დამცავების გაგდება ---
            if energize && circuitComplete {
                // მოკლე ჩართვა ამ წრედის ქსელებში → მაგნიტური გაგდება
                let shorted = shortedNets.contains(lineNet) || shortedNets.contains(neutralNet) || load.faultShortToN
                if shorted {
                    trip = .magnetic
                    issues.append(Issue(code: .shortCircuit, componentIDs: [load.id]))
                } else if let rating = breaker?.ratingA, current > rating + 0.001 {
                    // გადატვირთვა → თერმული
                    trip = .thermal
                    issues.append(Issue(code: .overload, componentIDs: [load.id]))
                } else if let leak = load.leakageMa, leak > 0 {
                    // დენის გაჟონვა
                    let hasPE = (load.port(conductor: .PE).map { conductors(of: $0.id).contains(.PE) }) ?? false
                    if rcdInPath, let mA = (chain.first { $0.mAtrip != nil }?.mAtrip), leak >= mA {
                        trip = .rcd
                        issues.append(Issue(code: .leakageTrip, componentIDs: [load.id]))
                    } else if !hasPE {
                        shockRisk = true
                        issues.append(Issue(code: .shockRisk, componentIDs: [load.id]))
                    }
                }
            }

            // ფაზის დატვირთვის აღრიცხვა ბალანსისთვის (რეალური ფაზა line-ქსელიდან)
            if let ph = lineSet.first(where: { $0.isHot }) {
                phaseCurrent[ph == .L ? .L1 : ph, default: 0] += current
            }

            let powered = circuitComplete && trip == nil && energize
            loadStates.append(LoadState(id: load.id, isPowered: powered,
                                        currentA: current, trip: trip, shockRisk: shockRisk))
        }

        // --- 8b. ბუნიკი (ferrule): მრავალწვერა კაბელი ხრახნიან კლემაში (IEC) ---
        for wire in board.wires where wire.conductorType == .stranded && !wire.ferruled {
            for portID in [wire.fromPortID, wire.toPortID] {
                if let comp = board.component(withPort: portID), comp.kind.hasScrewTerminal {
                    issues.append(Issue(code: .missingFerrule,
                                        message: "მრავალწვერა კაბელს ბუნიკი სჭირდება \(comp.kind.ferruleTerm) კლემაში",
                                        componentIDs: [comp.id]))
                    break
                }
            }
        }

        // --- 8c. მოჭერა (screw-down): შეერთებული კლემა მოუჭერელია → ინსპექცია იჭრება ---
        for wire in board.wires where !wire.tightened {
            let owners = [wire.fromPortID, wire.toPortID]
                .compactMap { board.component(withPort: $0)?.id }
            issues.append(Issue(code: .looseTerminal,
                                message: "კლემა არ არის მოჭერილი — დაშურუპე შეერთება",
                                componentIDs: owners))
        }

        // --- 9. სამფაზიანი ბალანსი (Phase 3) ---
        if board.phase == .three {
            let vals: [Double] = [phaseCurrent[.L1] ?? 0, phaseCurrent[.L2] ?? 0, phaseCurrent[.L3] ?? 0]
            if let mx = vals.max(), let mn = vals.min(), mx > 0, (mx - mn) > 0.5 * mx {
                issues.append(Issue(code: .phaseImbalance))
            }
        }

        // დუბლიკატი issue-ების მოცილება (კოდი + კომპონენტები)
        issues = dedupe(issues)

        return SimulationResult(issues: issues, loadStates: loadStates, energized: energize)
    }

    // MARK: დამხმარე

    private func dedupe(_ issues: [Issue]) -> [Issue] {
        var seen: Set<String> = []
        var result: [Issue] = []
        for issue in issues {
            let key = issue.code.rawValue + "|" + issue.componentIDs.sorted().joined(separator: ",")
            if !seen.contains(key) {
                seen.insert(key)
                result.append(issue)
            }
        }
        return result
    }
}
