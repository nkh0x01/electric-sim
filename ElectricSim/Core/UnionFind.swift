//
//  UnionFind.swift
//  ElectricSim — Core
//
//  გრაფის კავშირების სწრაფი დაჯგუფება (disjoint-set).
//  გამოიყენება კვანძების (terminal) ერთ ელექტრულ ქსელში (net) გასაერთიანებლად.
//

import Foundation

public final class UnionFind {
    private var parent: [String: String] = [:]
    private var rank: [String: Int] = [:]

    public init() {}

    public func makeSet(_ x: String) {
        if parent[x] == nil {
            parent[x] = x
            rank[x] = 0
        }
    }

    public func find(_ x: String) -> String {
        makeSet(x)
        var root = x
        while let p = parent[root], p != root { root = p }
        // path compression
        var cur = x
        while let p = parent[cur], p != root {
            parent[cur] = root
            cur = p
        }
        return root
    }

    public func union(_ a: String, _ b: String) {
        let ra = find(a)
        let rb = find(b)
        guard ra != rb else { return }
        let rankA = rank[ra] ?? 0
        let rankB = rank[rb] ?? 0
        if rankA < rankB {
            parent[ra] = rb
        } else if rankA > rankB {
            parent[rb] = ra
        } else {
            parent[rb] = ra
            rank[ra] = rankA + 1
        }
    }

    public func connected(_ a: String, _ b: String) -> Bool {
        find(a) == find(b)
    }
}

public extension UnionFind {
    /// აერთიანებს ბორდის კონექტორების ფეხებს ერთ ელექტრულ ქსელში.
    /// busbar / wago / terminalBlock → ყველა ფეხი ერთ კვანძში.
    /// comb (სავარცხელი) → კბილები *გამტარის (ფაზის) მიხედვით* ცალკე ჯგუფდება,
    /// ასე რომ 3-ფაზიანი სავარცხელი L1/L2/L3-ს არ ამოკლებს ერთმანეთში.
    /// (იდემპოტენტურია — union თვითონ ქმნის set-ებს.)
    func unionConnectors(_ board: Board) {
        for comp in board.components where comp.kind.isConnector {
            if comp.kind == .comb {
                var firstOfConductor: [Conductor: String] = [:]
                for p in comp.ports {
                    if let head = firstOfConductor[p.conductor] { union(head, p.id) }
                    else { firstOfConductor[p.conductor] = p.id }
                }
            } else if let first = comp.ports.first {
                for p in comp.ports.dropFirst() { union(first.id, p.id) }
            }
        }
    }
}
