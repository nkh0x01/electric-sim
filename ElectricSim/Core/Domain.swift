//
//  Domain.swift
//  ElectricSim — Core
//
//  ელექტრო-მონტაჟის სიმულატორის ძირითადი მონაცემთა მოდელი.
//  მთლიანად Foundation-ზე დაფუძნებული (UIKit/SwiftUI გარეშე), რათა
//  გამოსაცდელი იყოს `swift test`-ით ნებისმიერ პლატფორმაზე.
//
//  სისტემა: TN-C-S (PEN ფარში იყოფა PE-დ და N-ად).
//  ძაბვები: 1 ფაზა L–N = 230 V; 3 ფაზა L–L = 400 V, L–N = 230 V.
//

import Foundation

// MARK: - Constants

public enum Electrical {
    /// ფაზა–ნული ძაბვა (V).
    public static let phaseToNeutral: Double = 230
    /// ფაზა–ფაზა ძაბვა (V).
    public static let phaseToPhase: Double = 400
    /// RCD-ის სტანდარტული გამშვები დენი როზეტებზე (mA).
    public static let standardRCDmA: Double = 30
}

// MARK: - Conductor (გამტარი)

/// ელექტრული გამტარის ლოგიკური დანიშნულება.
public enum Conductor: String, Codable, CaseIterable, Sendable {
    case L   // ერთფაზიანი ფაზა
    case L1  // სამფაზიანი ფაზა 1
    case L2  // სამფაზიანი ფაზა 2
    case L3  // სამფაზიანი ფაზა 3
    case N   // ნული (neutral)
    case PE  // დამცავი მიწა (protective earth)

    /// არის თუ არა „ცხელი" გამტარი (ფაზა).
    public var isHot: Bool {
        switch self {
        case .L, .L1, .L2, .L3: return true
        case .N, .PE: return false
        }
    }
}

// MARK: - Wire color (IEC 60446 / ჰარმონიზებული ფერები)

public enum WireColor: String, Codable, CaseIterable, Sendable {
    case yellowGreen // PE — ყვითელ-მწვანე
    case blue        // N — ლურჯი
    case brown       // L / L1 — ყავისფერი
    case black       // L2 — შავი
    case grey        // L3 — ნაცრისფერი

    /// მოცემული გამტარისთვის სტანდარტული ფერი.
    public static func standard(for conductor: Conductor) -> WireColor {
        switch conductor {
        case .PE: return .yellowGreen
        case .N:  return .blue
        case .L, .L1: return .brown
        case .L2: return .black
        case .L3: return .grey
        }
    }

    /// ქართული სახელი (UI-სთვის).
    public var georgianName: String {
        switch self {
        case .yellowGreen: return "ყვითელ-მწვანე"
        case .blue:        return "ლურჯი"
        case .brown:       return "ყავისფერი"
        case .black:       return "შავი"
        case .grey:        return "ნაცრისფერი"
        }
    }
}

// MARK: - Breaker curve

public enum BreakerCurve: String, Codable, CaseIterable, Sendable {
    case B // საყოფაცხოვრებო, 3–5×In
    case C // ინდუქციური/მოტორი, 5–10×In
    case D // მაღალი დამრტყმელი დენი, 10–20×In (ტრანსფორმატორები, ძრავები)
}

// MARK: - Cable type (გამტარის მასალა)

public enum CableType: String, Codable, CaseIterable, Sendable {
    case copper     // სპილენძი
    case aluminum   // ალუმინი (≈0.78× დასაშვები დენი იმავე კვეთაზე)

    public var ampacityFactor: Double { self == .copper ? 1.0 : 0.78 }

    public var georgianName: String {
        self == .copper ? "სპილენძი" : "ალუმინი"
    }
}

// MARK: - Conductor construction (ძარღვის ტიპი)

public enum ConductorType: String, Codable, CaseIterable, Sendable {
    case solid      // ხისტი (single solid core)
    case stranded   // მრავალწვერა (flexible/stranded)

    public var georgianName: String {
        self == .solid ? "ხისტი" : "მრავალწვერა"
    }

    /// კაბელის ტექნიკური აღნიშვნა (ხისტი → NYM, მრავალწვერა → PVS).
    public var designation: String { self == .solid ? "NYM" : "PVS" }

    /// ქართულ-პირველი სრული სახელი ფრჩხილებში აღნიშვნით — components.json-ის
    /// სტილში. მაგ.: „ხისტი კაბელი 1.5მმ² (NYM)" / „მრავალწვერა კაბელი 2.5მმ² (PVS)".
    public func cableName(csaMm2 csa: Double) -> String {
        let size = csa.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(csa)) : String(format: "%.1f", csa)
        return "\(georgianName) კაბელი \(size)მმ² (\(designation))"
    }
}

// MARK: - Component kind

public enum ComponentKind: String, Codable, CaseIterable, Sendable {
    // კვება/დაცვა/კომუტაცია
    case supply       // შემომავალი კვება (PEN → PE + N)
    case mainSwitch   // მთავარი ამომრთველი
    case spd          // ზეძაბვის დამცავი
    case rcd          // დიფ. ამომრთველი (30mA)
    case rcbo         // RCBO (MCB + RCD ერთ მოდულში)
    case mcb          // ავტომატური ამომრთველი
    case mpcb         // მოტორის დამცავი ამომრთველი
    case contactor    // კონტაქტორი
    case relay        // რელე
    case lightSwitch  // გამთიშველი/ჩამრთველი
    case busbar       // სავარცხელი/ნულის/მიწის ზოლი (კონექტორი)
    case wago         // Wago / კლემა (კონექტორი)
    // დატვირთვები (1 ფაზა)
    case lamp         // განათება
    case dimmer       // დიმერით განათება
    case socket       // როზეტი
    case boiler       // ბოილერი
    case oven         // ღუმელი
    case heater       // გამახურებელი
    case airConditioner // კონდიციონერი
    // დატვირთვები (3 ფაზა)
    case motor        // 3-ფაზიანი მოტორი
    case socket3ph    // 3-ფაზიანი როზეტი
    // Smart home მოდულები
    case smartSwitch  // ჭკვიანი ამომრთველი (relay)
    case smartRelay   // ჭკვიანი რელე
    case smartDimmer  // ჭკვიანი დიმერი
    case smartMeter   // ჭკვიანი მრიცხველი
    // დამატებითი დაცვა/კომუტაცია
    case fuse             // დამცველი (предохранитель)
    case terminalBlock    // კლემების ბლოკი (კონექტორი)
    case emergencyStop    // ავარიული გაჩერება
    case selectorSwitch   // გადამრთველი (selector)
    case indicatorLight   // სასიგნალო ნათურა
    case currentTransformer // დენის ტრანსფორმატორი (გაზომვა)
    case transformer      // ტრანსფორმატორი
    case vfd              // სიხშირის გარდამქმნელი (motor drive)
    // კვების წყაროები
    case generator        // გენერატორი (3 ფაზა)
    case solarPanel       // მზის პანელი (ინვერტორით)
    case ups              // უწყვეტი კვება (UPS)
    case inverter         // ინვერტორი
    case battery          // აკუმულატორი

    /// კონექტორია? (ყველა ფეხი ერთ კვანძში ერთიანდება)
    public var isConnector: Bool { self == .busbar || self == .wago || self == .terminalBlock }

    /// 3-ფაზიანი დატვირთვაა?
    public var isThreePhaseLoad: Bool { self == .motor || self == .socket3ph }

    /// კვების წყაროა? (ქსელში ასხამს L/N/PE-ს)
    public var isSource: Bool {
        switch self {
        case .supply, .generator, .solarPanel, .ups, .inverter, .battery:
            return true
        default:
            return false
        }
    }

    /// დატვირთვაა?
    public var isLoad: Bool {
        switch self {
        case .lamp, .dimmer, .socket, .boiler, .oven, .heater, .airConditioner,
             .motor, .socket3ph, .indicatorLight:
            return true
        default:
            return false
        }
    }

    /// მიმდევრობითი (series) მოწყობილობაა, რომელიც დენს ატარებს?
    public var isSeriesDevice: Bool {
        switch self {
        case .mainSwitch, .mcb, .mpcb, .rcbo, .rcd, .contactor, .relay, .lightSwitch,
             .smartSwitch, .smartRelay, .smartDimmer, .smartMeter,
             .fuse, .emergencyStop, .selectorSwitch, .currentTransformer, .transformer, .vfd:
            return true
        default:
            return false
        }
    }

    /// დამცავი ავტომატია (ampacity/ნომინალის შემოწმებისთვის)?
    public var isBreaker: Bool { self == .mcb || self == .mpcb || self == .rcbo || self == .fuse }

    /// ხრახნიანი კლემაა (screw terminal) — მრავალწვერა კაბელს ბუნიკი სჭირდება (IEC).
    public var hasScrewTerminal: Bool {
        switch self {
        case .mcb, .rcd, .rcbo, .mainSwitch, .spd: return true
        default: return false
        }
    }

    /// ქართული ტერმინი ferrule-შეტყობინებისთვის (კლემის მფლობელი).
    public var ferruleTerm: String {
        switch self {
        case .mcb:        return "ავტომატის"
        case .rcd:        return "RCD-ის"
        case .rcbo:       return "დიფ-ავტომატის (RCBO)"
        case .mainSwitch: return "მთავარი ამომრთველის"
        case .spd:        return "ზეძაბვის დამცავის (SPD)"
        default:          return "მოწყობილობის"
        }
    }
}

// MARK: - Port (ფეხი / terminal)

public enum PortSide: String, Codable, Sendable {
    case input   // შემავალი მხარე (კვების მხრიდან)
    case output  // გამავალი მხარე (დატვირთვის მხრიდან)
    case single  // ცალმხრივი (დატვირთვის ფეხი, შემომავალი წყარო)
}

/// კომპონენტის ერთი ფეხი — გრაფში ეს არის node (terminal).
public struct Port: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let conductor: Conductor
    public let side: PortSide
    public let name: String   // მოკლე იარლიყი, მაგ. "L IN"

    public init(id: String, conductor: Conductor, side: PortSide, name: String) {
        self.id = id
        self.conductor = conductor
        self.side = side
        self.name = name
    }
}

// MARK: - Component

public struct Component: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var kind: ComponentKind
    public var name: String          // ქართული დასახელება
    public var poles: Int
    public var ratingA: Double?      // ავტომატის ნომინალი (A)
    public var curve: BreakerCurve?  // ავტომატის მახასიათებელი
    public var mAtrip: Double?       // RCD-ის გამშვები დენი (mA)
    public var powerW: Double?       // დატვირთვის სიმძლავრე (W)
    public var requiresPE: Bool      // ესაჭიროება დამცავი მიწა?
    public var leakageMa: Double?    // დეფექტი: გაჟონვის დენი (mA)
    public var faultShortToN: Bool   // დეფექტი: შიდა მოკლე ჩართვა L→N
    public var priceGEL: Double?     // ერთეულის ფასი (₾) — BOM-ისთვის
    /// fault-finding მარკერი: არა-ელექტრული დეფექტის ნიშანი (FaultType rawValue),
    /// მაგ. looseNeutral/failedSPD/sharedNeutral, რომელსაც solver ვერ აღმოაჩენს.
    public var faultFlag: String?
    public var ports: [Port]

    public init(id: String,
                kind: ComponentKind,
                name: String,
                poles: Int = 1,
                ratingA: Double? = nil,
                curve: BreakerCurve? = nil,
                mAtrip: Double? = nil,
                powerW: Double? = nil,
                requiresPE: Bool = false,
                leakageMa: Double? = nil,
                faultShortToN: Bool = false,
                priceGEL: Double? = nil,
                faultFlag: String? = nil,
                ports: [Port]) {
        self.id = id
        self.kind = kind
        self.name = name
        self.poles = poles
        self.ratingA = ratingA
        self.curve = curve
        self.mAtrip = mAtrip
        self.powerW = powerW
        self.faultFlag = faultFlag
        self.requiresPE = requiresPE
        self.leakageMa = leakageMa
        self.faultShortToN = faultShortToN
        self.priceGEL = priceGEL
        self.ports = ports
    }

    public func port(side: PortSide, conductor: Conductor) -> Port? {
        ports.first { $0.side == side && $0.conductor == conductor }
    }

    public func port(conductor: Conductor) -> Port? {
        ports.first { $0.conductor == conductor }
    }
}

// MARK: - Component factory (სტანდარტული კომპონენტები)

public enum ComponentFactory {
    private static func pid(_ comp: String, _ suffix: String) -> String { "\(comp).\(suffix)" }

    public static func supply(id: String = "supply", phase: Phase = .single) -> Component {
        var ports: [Port] = []
        if phase == .single {
            ports.append(Port(id: pid(id, "L"), conductor: .L, side: .output, name: "L"))
        } else {
            ports.append(Port(id: pid(id, "L1"), conductor: .L1, side: .output, name: "L1"))
            ports.append(Port(id: pid(id, "L2"), conductor: .L2, side: .output, name: "L2"))
            ports.append(Port(id: pid(id, "L3"), conductor: .L3, side: .output, name: "L3"))
        }
        ports.append(Port(id: pid(id, "N"), conductor: .N, side: .output, name: "N"))
        ports.append(Port(id: pid(id, "PE"), conductor: .PE, side: .output, name: "PE"))
        return Component(id: id, kind: .supply,
                         name: phase == .single ? "კვება 230V" : "კვება 400V",
                         poles: phase == .single ? 1 : 3, ports: ports)
    }

    public static func mainSwitch(id: String, phase: Phase = .single) -> Component {
        var ports: [Port] = []
        let hots: [Conductor] = phase == .single ? [.L] : [.L1, .L2, .L3]
        for c in hots {
            ports.append(Port(id: pid(id, "\(c.rawValue)in"), conductor: c, side: .input, name: "\(c.rawValue) IN"))
            ports.append(Port(id: pid(id, "\(c.rawValue)out"), conductor: c, side: .output, name: "\(c.rawValue) OUT"))
        }
        ports.append(Port(id: pid(id, "Nin"), conductor: .N, side: .input, name: "N IN"))
        ports.append(Port(id: pid(id, "Nout"), conductor: .N, side: .output, name: "N OUT"))
        let poles = phase == .single ? 2 : 4
        return Component(id: id, kind: .mainSwitch,
                         name: "მთავარი ამომრთველი \(poles)P", poles: poles, ports: ports)
    }

    public static func mcb(id: String, ratingA: Double, curve: BreakerCurve = .B, conductor: Conductor = .L) -> Component {
        let ports = [
            Port(id: pid(id, "in"), conductor: conductor, side: .input, name: "IN"),
            Port(id: pid(id, "out"), conductor: conductor, side: .output, name: "OUT")
        ]
        return Component(id: id, kind: .mcb,
                         name: "ავტომატი (MCB) \(curve.rawValue)\(Int(ratingA))",
                         poles: 1, ratingA: ratingA, curve: curve, ports: ports)
    }

    public static func rcbo(id: String, ratingA: Double, curve: BreakerCurve = .B, mAtrip: Double = Electrical.standardRCDmA) -> Component {
        let ports = [
            Port(id: pid(id, "in"), conductor: .L, side: .input, name: "L IN"),
            Port(id: pid(id, "out"), conductor: .L, side: .output, name: "L OUT")
        ]
        return Component(id: id, kind: .rcbo,
                         name: "დიფ-ავტომატი (RCBO) \(curve.rawValue)\(Int(ratingA)) \(Int(mAtrip))mA",
                         poles: 1, ratingA: ratingA, curve: curve, mAtrip: mAtrip, ports: ports)
    }

    public static func rcd(id: String, ratingA: Double = 40, mAtrip: Double = Electrical.standardRCDmA) -> Component {
        let ports = [
            Port(id: pid(id, "Lin"), conductor: .L, side: .input, name: "L IN"),
            Port(id: pid(id, "Lout"), conductor: .L, side: .output, name: "L OUT"),
            Port(id: pid(id, "Nin"), conductor: .N, side: .input, name: "N IN"),
            Port(id: pid(id, "Nout"), conductor: .N, side: .output, name: "N OUT")
        ]
        return Component(id: id, kind: .rcd,
                         name: "დიფ. დამცავი (RCD) \(Int(ratingA))A \(Int(mAtrip))mA",
                         poles: 2, ratingA: ratingA, mAtrip: mAtrip, ports: ports)
    }

    public static func spd(id: String) -> Component {
        let ports = [
            Port(id: pid(id, "L"), conductor: .L, side: .input, name: "L"),
            Port(id: pid(id, "PE"), conductor: .PE, side: .input, name: "PE")
        ]
        return Component(id: id, kind: .spd, name: "ზეძაბვის დამცავი (SPD)", poles: 1, ports: ports)
    }

    /// ზოლი (busbar / ნულის ან მიწის სალტე). `slots` ფეხი, ყველა ერთ კვანძში.
    /// `name` — სურვილისამებრ ცხადი სახელი (template-იდან); არადა გამტარს მიხედვით.
    public static func busbar(id: String, conductor: Conductor, slots: Int, name: String? = nil) -> Component {
        let ports = (0..<slots).map {
            Port(id: pid(id, "\($0)"), conductor: conductor, side: .single, name: "\(conductor.rawValue)\($0)")
        }
        let title: String
        if let name { title = name }
        else {
            switch conductor {
            case .N: title = "ნულის სალტე (N-bus)"
            case .PE: title = "დამიწების სალტე (PE-bus)"
            default: title = "შინა (busbar)"
            }
        }
        return Component(id: id, kind: .busbar, name: title, poles: slots, ports: ports)
    }

    public static func lamp(id: String, powerW: Double = 60, requiresPE: Bool = true, leakageMa: Double? = nil) -> Component {
        let ports = [
            Port(id: pid(id, "L"), conductor: .L, side: .single, name: "L"),
            Port(id: pid(id, "N"), conductor: .N, side: .single, name: "N"),
            Port(id: pid(id, "PE"), conductor: .PE, side: .single, name: "PE")
        ]
        return Component(id: id, kind: .lamp, name: "ნათურა \(Int(powerW))W",
                         poles: 1, powerW: powerW, requiresPE: requiresPE, leakageMa: leakageMa, ports: ports)
    }

    public static func motor(id: String, powerW: Double = 4000) -> Component {
        let ports = [
            Port(id: pid(id, "L1"), conductor: .L1, side: .single, name: "L1"),
            Port(id: pid(id, "L2"), conductor: .L2, side: .single, name: "L2"),
            Port(id: pid(id, "L3"), conductor: .L3, side: .single, name: "L3"),
            Port(id: pid(id, "N"), conductor: .N, side: .single, name: "N"),
            Port(id: pid(id, "PE"), conductor: .PE, side: .single, name: "PE")
        ]
        return Component(id: id, kind: .motor, name: "ძრავა (3-ფაზიანი) \(Int(powerW))W",
                         poles: 3, powerW: powerW, requiresPE: true, ports: ports)
    }

    public static func socket(id: String, powerW: Double = 2300, leakageMa: Double? = nil) -> Component {
        let ports = [
            Port(id: pid(id, "L"), conductor: .L, side: .single, name: "L"),
            Port(id: pid(id, "N"), conductor: .N, side: .single, name: "N"),
            Port(id: pid(id, "PE"), conductor: .PE, side: .single, name: "PE")
        ]
        return Component(id: id, kind: .socket, name: "როზეტი",
                         poles: 1, powerW: powerW, requiresPE: true, leakageMa: leakageMa, ports: ports)
    }

    // MARK: გენერიკული ფაბრიკები (ახალი კომპონენტებისთვის)

    /// მიმდევრობითი კომუტაცია/დაცვა (კონტაქტორი, რელე, გამთიშველი, smart…).
    public static func seriesDevice(id: String, kind: ComponentKind, name: String,
                                    conductors: [Conductor],
                                    ratingA: Double? = nil, curve: BreakerCurve? = nil,
                                    mAtrip: Double? = nil) -> Component {
        var ports: [Port] = []
        for c in conductors {
            ports.append(Port(id: pid(id, "\(c.rawValue)in"), conductor: c, side: .input, name: "\(c.rawValue) IN"))
            ports.append(Port(id: pid(id, "\(c.rawValue)out"), conductor: c, side: .output, name: "\(c.rawValue) OUT"))
        }
        return Component(id: id, kind: kind, name: name, poles: conductors.count,
                         ratingA: ratingA, curve: curve, mAtrip: mAtrip, ports: ports)
    }

    /// გენერიკული დატვირთვა (ბოილერი, ღუმელი, კონდიციონერი, 3-ფაზ. როზეტი…).
    public static func appliance(id: String, kind: ComponentKind, name: String,
                                 powerW: Double, requiresPE: Bool = true,
                                 threePhase: Bool = false, leakageMa: Double? = nil) -> Component {
        let conductors: [Conductor] = threePhase ? [.L1, .L2, .L3, .N, .PE] : [.L, .N, .PE]
        let ports = conductors.map {
            Port(id: pid(id, $0.rawValue), conductor: $0, side: .single, name: $0.rawValue)
        }
        return Component(id: id, kind: kind, name: name, poles: threePhase ? 3 : 1,
                         powerW: powerW, requiresPE: requiresPE, leakageMa: leakageMa, ports: ports)
    }

    /// კონექტორი (Wago/კლემა) მოცემული გამტარისთვის.
    public static func connector(id: String, kind: ComponentKind, name: String,
                                 conductor: Conductor, slots: Int) -> Component {
        let ports = (0..<slots).map {
            Port(id: pid(id, "\($0)"), conductor: conductor, side: .single, name: "\(conductor.rawValue)\($0)")
        }
        return Component(id: id, kind: kind, name: name, poles: slots, ports: ports)
    }

    /// მოტორის დამცავი ამომრთველი (MPCB), 3-პოლუსიანი.
    public static func mpcb(id: String, ratingA: Double, curve: BreakerCurve = .D) -> Component {
        seriesDevice(id: id, kind: .mpcb, name: "ძრავის დამცავი (MPCB) \(Int(ratingA))A",
                     conductors: [.L1, .L2, .L3], ratingA: ratingA, curve: curve)
    }

    /// კვების წყარო (გენერატორი/მზე/UPS/ინვერტორი/აკუმულატორი) — supply-ის მსგავსი output.
    public static func source(id: String, kind: ComponentKind, name: String,
                              phase: Phase = .single) -> Component {
        var ports: [Port] = []
        let hots: [Conductor] = phase == .single ? [.L] : [.L1, .L2, .L3]
        for c in hots {
            ports.append(Port(id: pid(id, c.rawValue), conductor: c, side: .output, name: c.rawValue))
        }
        ports.append(Port(id: pid(id, "N"), conductor: .N, side: .output, name: "N"))
        ports.append(Port(id: pid(id, "PE"), conductor: .PE, side: .output, name: "PE"))
        return Component(id: id, kind: kind, name: name, poles: phase == .single ? 1 : 3, ports: ports)
    }
}

// MARK: - Wire

public struct Wire: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var fromPortID: String
    public var toPortID: String
    public var csaMm2: Double
    public var color: WireColor
    public var cableType: CableType
    public var conductorType: ConductorType
    public var lengthM: Double
    public var ferruled: Bool          // მრავალწვერა კაბელზე ბუნიკი (ferrule) დადებულია?
    public var tightened: Bool         // კლემები მოჭერილია? default true — მხოლოდ ახალი
                                       // ინტერაქტიული შეერთება იწყება მოუჭერელი.

    public init(id: String = UUID().uuidString,
                from: String, to: String,
                csaMm2: Double, color: WireColor,
                cableType: CableType = .copper,
                conductorType: ConductorType = .solid, lengthM: Double = 0,
                ferruled: Bool = false, tightened: Bool = true) {
        self.id = id
        self.fromPortID = from
        self.toPortID = to
        self.csaMm2 = csaMm2
        self.color = color
        self.cableType = cableType
        self.conductorType = conductorType
        self.lengthM = lengthM
        self.ferruled = ferruled
        self.tightened = tightened
    }

    // backward-compatible decode (cableType/conductorType/lengthM default-ებით თუ აკლია)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fromPortID = try c.decode(String.self, forKey: .fromPortID)
        toPortID = try c.decode(String.self, forKey: .toPortID)
        csaMm2 = try c.decode(Double.self, forKey: .csaMm2)
        color = try c.decode(WireColor.self, forKey: .color)
        cableType = try c.decodeIfPresent(CableType.self, forKey: .cableType) ?? .copper
        conductorType = try c.decodeIfPresent(ConductorType.self, forKey: .conductorType) ?? .solid
        lengthM = try c.decodeIfPresent(Double.self, forKey: .lengthM) ?? 0
        ferruled = try c.decodeIfPresent(Bool.self, forKey: .ferruled) ?? false
        // ძველი/წინასწარ აწყობილი ფარები მოჭერილად იტვირთება.
        tightened = try c.decodeIfPresent(Bool.self, forKey: .tightened) ?? true
    }
}

// MARK: - Phase

public enum Phase: String, Codable, Sendable {
    case single
    case three
}

// MARK: - Board

/// მთლიანი ფარის მდგომარეობა — კომპონენტები + სადენები.
public struct Board: Codable, Sendable {
    public var phase: Phase
    public var components: [Component]
    public var wires: [Wire]

    public init(phase: Phase = .single, components: [Component] = [], wires: [Wire] = []) {
        self.phase = phase
        self.components = components
        self.wires = wires
    }

    public mutating func add(_ component: Component) { components.append(component) }

    /// უნიკალური instance-id შაბლონისთვის: "<templateId>_<n>", სადაც n = ფარზე ამ
    /// შაბლონის მაქს. გამოყენებული სუფიქსი + 1. წაშლა-დამატების შემდეგაც არ
    /// მეორდება (count+1-ისგან განსხვავებით) — id-კოლიზია სადენების ბოლოებსა და
    /// მონიშვნას აფუჭებდა.
    public func nextInstanceID(forTemplate templateId: String) -> String {
        let prefix = templateId + "_"
        let maxUsed = components.compactMap { comp -> Int? in
            guard comp.id.hasPrefix(prefix) else { return nil }
            return Int(comp.id.dropFirst(prefix.count))
        }.max() ?? 0
        return "\(templateId)_\(maxUsed + 1)"
    }

    public mutating func connect(_ a: String, _ b: String, csaMm2: Double,
                                 color: WireColor, cableType: CableType = .copper,
                                 conductorType: ConductorType = .solid, lengthM: Double = 0,
                                 ferruled: Bool = false, tightened: Bool = true) {
        wires.append(Wire(from: a, to: b, csaMm2: csaMm2, color: color,
                          cableType: cableType, conductorType: conductorType,
                          lengthM: lengthM, ferruled: ferruled, tightened: tightened))
    }

    public func component(withPort portID: String) -> Component? {
        components.first { $0.ports.contains { $0.id == portID } }
    }

    public func port(_ portID: String) -> Port? {
        for c in components {
            if let p = c.ports.first(where: { $0.id == portID }) { return p }
        }
        return nil
    }

    public var supply: Component? { components.first { $0.kind == .supply } }
}

// MARK: - Ampacity (კაბელის კვეთა → მაქს. ავტომატი)

public enum Ampacity {
    /// კვეთა (mm²) → დასაშვები მაქსიმალური ავტომატის ნომინალი (A).
    /// თამაშის გამარტივებული წესი (იხ. სპეციფიკაცია).
    public static let table: [(csa: Double, maxA: Double)] = [
        (1.5, 16), (2.5, 20), (4, 25), (6, 32), (10, 40)
    ]

    public static func maxBreaker(forCsa csa: Double) -> Double {
        // ზუსტი დამთხვევა, ან უახლოესი ქვედა კვეთა.
        let sorted = table.sorted { $0.csa < $1.csa }
        var result = sorted.first?.maxA ?? 0
        for row in sorted where csa >= row.csa - 0.001 {
            result = row.maxA
        }
        return result
    }

    /// კაბელის მასალის გათვალისწინებით (ალუმინი დერეიტდება).
    public static func maxBreaker(forCsa csa: Double, cable: CableType) -> Double {
        maxBreaker(forCsa: csa) * cable.ampacityFactor
    }
}
