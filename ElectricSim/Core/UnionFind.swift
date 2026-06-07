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
