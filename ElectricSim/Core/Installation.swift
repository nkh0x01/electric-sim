//
//  Installation.swift
//  ElectricSim — Core
//
//  „მონტაჟის დიზაინერი" (Floor Plan / Installation Designer) — Phase 1.
//  გეგმის დოკუმენტი: ერთი ოთახი ბადეზე, რამდენიმე დატვირთვის წერტილი, ერთ
//  წრედში გაერთიანებული, ერთი კაბელის ტრასა ფარამდე.
//
//  წმინდა Foundation — გამოსაცდელი `swift test`-ით. არსებულ solver/IEC კოდს
//  არ ეხება: გეგმა ProjectCompiler-ით „ფარად" (Board) ითარგმნება და უკვე
//  არსებული CircuitSolver/PanelAssembly ამოწმებს.
//

import Foundation

// MARK: - ბადის გეომეტრია

/// ბადის უჯრედის კოორდინატი (მთელი რიცხვები). 1 უჯრედი = `GridSpec.cellMeters` მ.
public struct GridPoint: Codable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
}

/// ბადის ზომა და მასშტაბი — `cellMeters` აქცევს უჯრედებს რეალურ მეტრებად.
public struct GridSpec: Codable, Sendable {
    public var cols: Int
    public var rows: Int
    public var cellMeters: Double
    public init(cols: Int, rows: Int, cellMeters: Double) {
        self.cols = cols; self.rows = rows; self.cellMeters = cellMeters
    }
}

/// ერთი მართკუთხა ოთახი ბადეზე (უჯრედებში).
public struct PlanRoom: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var origin: GridPoint    // ზედა-მარცხენა კუთხე
    public var width: Int           // უჯრედებში
    public var height: Int
    public init(id: String, name: String, origin: GridPoint, width: Int, height: Int) {
        self.id = id; self.name = name; self.origin = origin
        self.width = width; self.height = height
    }
}

// MARK: - დატვირთვის წერტილი

/// გეგმაზე განთავსებული დატვირთვა — components.json-ის შაბლონს მიუთითებს
/// (იქიდან მოაქვს powerW / requiresPE).
public struct LoadPoint: Codable, Identifiable, Sendable {
    public var id: String
    public var templateId: String
    public var kind: ComponentKind
    public var at: GridPoint
    public init(id: String, templateId: String, kind: ComponentKind, at: GridPoint) {
        self.id = id; self.templateId = templateId; self.kind = kind; self.at = at
    }
}

// MARK: - წრედი

/// წრედის დანიშნულება (UI-ჯგუფი + ნაგულისხმევი წესები).
public enum CircuitKind: String, Codable, Sendable, CaseIterable {
    case lighting    // განათება
    case socket      // როზეტები
    case cooker      // ქურა / გაზქურა
    case dedicated   // გამოყოფილი (ბოილერი, კონდიციონერი…)

    public var georgianName: String {
        switch self {
        case .lighting:  return "განათება"
        case .socket:    return "როზეტები"
        case .cooker:    return "ქურა"
        case .dedicated: return "გამოყოფილი ხაზი"
        }
    }
}

/// ერთი წრედი: დატვირთვები + კაბელის ტრასა + არჩეული ავტომატი/კვეთა.
public struct PlanCircuit: Codable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: CircuitKind
    public var phaseLeg: Conductor          // L (1-ფაზა) ან L1/L2/L3 — ფაზის დაბალანსებისთვის
    public var loadIDs: [String]
    public var run: [GridPoint]             // კაბელის ტრასის polyline (ფარიდან დატვირთვებამდე)
    public var csaMm2: Double
    public var cableType: CableType
    public var breakerRatingA: Double
    public var breakerCurve: BreakerCurve

    public init(id: String, name: String, kind: CircuitKind, phaseLeg: Conductor = .L,
                loadIDs: [String], run: [GridPoint], csaMm2: Double,
                cableType: CableType = .copper, breakerRatingA: Double,
                breakerCurve: BreakerCurve = .B) {
        self.id = id; self.name = name; self.kind = kind; self.phaseLeg = phaseLeg
        self.loadIDs = loadIDs; self.run = run; self.csaMm2 = csaMm2
        self.cableType = cableType; self.breakerRatingA = breakerRatingA
        self.breakerCurve = breakerCurve
    }
}

// MARK: - მონტაჟის პროექტი (Phase 1: ერთი ოთახი, ერთი წრედი)

public struct InstallationProject: Codable, Sendable {
    public var id: String
    public var title: String
    public var phase: Phase
    public var grid: GridSpec
    public var room: PlanRoom
    public var panelAt: GridPoint           // ფარის (consumer unit) ადგილი გეგმაზე
    public var loads: [LoadPoint]
    public var circuit: PlanCircuit

    public init(id: String, title: String, phase: Phase = .single, grid: GridSpec,
                room: PlanRoom, panelAt: GridPoint, loads: [LoadPoint], circuit: PlanCircuit) {
        self.id = id; self.title = title; self.phase = phase; self.grid = grid
        self.room = room; self.panelAt = panelAt; self.loads = loads; self.circuit = circuit
    }

    /// ტრასის რეალური სიგრძე (მ) — polyline-ის ევკლიდური მონაკვეთების ჯამი × cellMeters.
    public func runLengthM() -> Double {
        InstallationGeometry.polylineLengthCells(circuit.run) * grid.cellMeters
    }

    /// წრედის დატვირთვების ჯამური სიმძლავრე (W) — templates-იდან powerW.
    public func loadSumW(templates: [String: ComponentTemplate]) -> Double {
        circuit.loadIDs.reduce(0.0) { sum, lid in
            guard let lp = loads.first(where: { $0.id == lid }) else { return sum }
            let w = templates[lp.templateId]?.powerW ?? 0
            return sum + w
        }
    }
}

// MARK: - გეგმის გეომეტრია (წმინდა, ტესტირებადი)

public enum InstallationGeometry {
    /// polyline-ის სიგრძე უჯრედებში (ევკლიდური მონაკვეთების ჯამი).
    public static func polylineLengthCells(_ pts: [GridPoint]) -> Double {
        guard pts.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1..<pts.count {
            let dx = Double(pts[i].x - pts[i - 1].x)
            let dy = Double(pts[i].y - pts[i - 1].y)
            total += (dx * dx + dy * dy).squareRoot()
        }
        return total
    }
}
