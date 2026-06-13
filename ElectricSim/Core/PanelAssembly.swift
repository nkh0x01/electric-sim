//
//  PanelAssembly.swift
//  ElectricSim — Core
//
//  „ფარის აწყობა" (consumer unit) რეჟიმის ვალიდაცია: მოწყობილობების სწორი
//  თანმიმდევრობა DIN რელსზე და ავტომატების სავარცხელი ზოლით (busbar) კვება.
//
//  სწორი წყობა (კვებიდან დატვირთვისკენ):
//      მთავარი ამომრთველი → SPD → RCD/RCBO → ავტომატები (MCB, busbar-ით) → ხაზები
//
//  რელსზე თანმიმდევრობა = `board.components` მასივის რიგი (მარცხნიდან მარჯვნივ),
//  რომელსაც მოთამაშე ცვლის გადათრევით.
//

import Foundation

public enum PanelAssembly {

    /// ფარის აწყობის წესების შემოწმება. აბრუნებს ქართულ შეცდომებს (error severity).
    public static func validate(_ board: Board) -> [Issue] {
        var issues: [Issue] = []

        func indices(_ pred: (ComponentKind) -> Bool) -> [Int] {
            board.components.enumerated().filter { pred($0.element.kind) }.map { $0.offset }
        }
        let mainIdxs = indices { $0 == .mainSwitch }
        let spdIdxs  = indices { $0 == .spd }
        let rcdIdxs  = indices { $0 == .rcd || $0 == .rcbo }
        let mcbIdxs  = indices { $0 == .mcb || $0 == .mpcb || $0 == .fuse }

        let railIdxs = mainIdxs + spdIdxs + rcdIdxs + mcbIdxs
        // ცარიელ/დაუწყებელ ფარს არ ვამოწმებთ (ჯერ არაფერი დადგმულა).
        guard let firstRail = railIdxs.min() else { return [] }

        // 1. მთავარი ამომრთველი ფარის თავში.
        if mainIdxs.isEmpty || mainIdxs.min()! != firstRail {
            issues.append(Issue(code: .panelMainNotFirst))
        }

        // 2. SPD — main-სა და RCD-ს შორის.
        if let s = spdIdxs.min() {
            if let m = mainIdxs.min(), s < m {
                issues.append(Issue(code: .panelSpdOrder))
            } else if let r = rcdIdxs.min(), s > r {
                issues.append(Issue(code: .panelSpdOrder))
            }
        }

        // 3. RCD ავტომატების წინ (ზემოთ).
        if let r = rcdIdxs.min(), let firstMcb = mcbIdxs.min(), firstMcb < r {
            issues.append(Issue(code: .panelRcdAfterMcb))
        }

        // 4. ავტომატების სავარცხელი ზოლით (busbar) კვება RCD-ის გამოსასვლელიდან.
        issues.append(contentsOf: busbarFeedIssues(board))

        return issues
    }

    /// busbar-ის კვების ელექტრული შემოწმება (union-find-ით, solver-ის ანალოგიურად).
    private static func busbarFeedIssues(_ board: Board) -> [Issue] {
        let mcbs = board.components.filter { $0.kind == .mcb }
        guard !mcbs.isEmpty else { return [] }

        let uf = UnionFind()
        for comp in board.components { for p in comp.ports { uf.makeSet(p.id) } }
        for w in board.wires {
            uf.makeSet(w.fromPortID); uf.makeSet(w.toPortID)
            uf.union(w.fromPortID, w.toPortID)
        }
        uf.unionConnectors(board)
        func net(_ id: String) -> String { uf.find(id) }

        // ფაზის სალტე ან სავარცხელი (comb) — ორივე ვალიდური მკვებავი ზოლია.
        let busbars = board.components.filter { $0.kind == .busbar || $0.kind == .comb }
        let busbarNets = Set(busbars.flatMap { $0.ports.map { net($0.id) } })

        // ყველა MCB-ის შესასვლელი ზოლზეა?
        var allOnBusbar = true
        for mcb in mcbs {
            guard let inP = mcb.port(side: .input, conductor: .L) else { continue }
            if !busbarNets.contains(net(inP.id)) { allOnBusbar = false }
        }

        if busbars.isEmpty {
            // ერთზე მეტი ავტომატი ცალკეული სადენებით — საჭიროა სავარცხელი ზოლი.
            if mcbs.count >= 2 { return [Issue(code: .panelBusbarFeed)] }
            return []
        }
        if !allOnBusbar { return [Issue(code: .panelBusbarFeed)] }

        // ზოლი RCD-ის (ან მთავარის) გამოსასვლელიდან უნდა იკვებებოდეს.
        let feeder = board.components.first { $0.kind == .rcd }
            ?? board.components.first { $0.kind == .rcbo }
            ?? board.components.first { $0.kind == .mainSwitch }
        if let feeder, let lout = feeder.port(side: .output, conductor: .L) {
            if !busbarNets.contains(net(lout.id)) { return [Issue(code: .panelBusbarFeed)] }
        }
        return []
    }
}
