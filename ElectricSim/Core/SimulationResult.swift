//
//  SimulationResult.swift
//  ElectricSim — Core
//
//  სიმულაციის შედეგის მოდელი + ქართული საგანმანათლებლო შეტყობინებები.
//

import Foundation

// MARK: - Severity

public enum IssueSeverity: String, Sendable {
    case error    // შეცდომა — დონე ვერ ჩაითვლება
    case warning  // გაფრთხილება — დასაშვებია, მაგრამ არასწორი პრაქტიკა
    case info     // ინფორმაცია
}

// MARK: - Trip type

public enum TripType: String, Sendable {
    case magnetic // მყისიერი (მოკლე ჩართვა)
    case thermal  // დაყოვნებით (გადატვირთვა)
    case rcd      // დიფ. დაცვა (დენის გაჟონვა)

    public var georgian: String {
        switch self {
        case .magnetic: return "მაგნიტური გაგდება (მოკლე ჩართვა)"
        case .thermal:  return "თერმული გაგდება (გადატვირთვა)"
        case .rcd:      return "RCD გაგდება (დენის გაჟონვა)"
        }
    }
}

// MARK: - Issue code

public enum IssueCode: String, Sendable {
    case missingPE              // დატვირთვას არ აქვს მიწა
    case shortLN                // L–N მოკლე ჩართვა
    case shortLPE               // L–PE მოკლე ჩართვა
    case shortNPE               // N–PE მოკლე ჩართვა
    case shortPhasePhase        // ფაზა–ფაზა მოკლე ჩართვა
    case socketWithoutRCD       // როზეტი RCD-ის გარეშე
    case breakerExceedsCable    // ავტომატის ნომინალი > კაბელის დასაშვები დენი
    case noBreaker              // ხაზი ავტომატის გარეშე
    case polarityReversed       // L და N ადგილებ-არეული
    case openCircuit            // ხაზი არ არის დასრულებული (ნათურა არ ანათებს)
    case missingFerrule         // მრავალწვერა კაბელი ხრახნიან კლემაში ბუნიკის გარეშე
    case looseTerminal          // შეერთებული კლემა მოუჭერელია (screw-down)
    case phaseImbalance         // ფაზების დისბალანსი (3 ფაზა)
    case overload               // გადატვირთვა
    case shortCircuit           // მოკლე ჩართვა (Test რეჟიმი)
    case leakageTrip            // გაჟონვა → RCD გაიგდო
    case shockRisk              // შოკის რისკი (მიწის გარეშე გაჟონვა)
    case noSupply               // კვება არ არის მიერთებული
    // ფარის აწყობა (panel assembly) — რელსზე თანმიმდევრობა/კვება
    case panelMainNotFirst      // მთავარი ამომრთველი არ არის ფარის თავში
    case panelSpdOrder          // SPD არასწორ ადგილასაა (main-სა და RCD-ს შორის უნდა იყოს)
    case panelRcdAfterMcb       // RCD ავტომატების ქვემოთაა (უნდა იყოს მათ წინ)
    case panelBusbarFeed        // ავტომატები სავარცხელი ზოლით არ იკვებება RCD-დან

    public var defaultSeverity: IssueSeverity {
        switch self {
        case .phaseImbalance: return .warning
        case .noBreaker: return .warning
        default: return .error
        }
    }
}

// MARK: - Issue

public struct Issue: Identifiable, Sendable {
    public let id = UUID()
    public let code: IssueCode
    public let severity: IssueSeverity
    public let message: String          // ქართული ახსნა
    public let componentIDs: [String]

    public init(code: IssueCode, severity: IssueSeverity? = nil,
                message: String? = nil, componentIDs: [String] = []) {
        self.code = code
        self.severity = severity ?? code.defaultSeverity
        self.message = message ?? IssueMessages.text(for: code)
        self.componentIDs = componentIDs
    }
}

// MARK: - Load state (per დატვირთვა)

public struct LoadState: Identifiable, Sendable {
    public let id: String          // კომპონენტის id
    public var isPowered: Bool     // მიეწოდება ძაბვა და ანათებს/მუშაობს
    public var currentA: Double    // გამოთვლილი დენი
    public var trip: TripType?     // გაიგდო თუ არა და რატომ
    public var shockRisk: Bool

    public init(id: String, isPowered: Bool, currentA: Double, trip: TripType? = nil, shockRisk: Bool = false) {
        self.id = id
        self.isPowered = isPowered
        self.currentA = currentA
        self.trip = trip
        self.shockRisk = shockRisk
    }
}

// MARK: - Simulation result

public struct SimulationResult: Sendable {
    public var issues: [Issue]
    public var loadStates: [LoadState]
    public var energized: Bool      // ჩაირთო თუ არა ძაბვა (Test რეჟიმი)

    public init(issues: [Issue] = [], loadStates: [LoadState] = [], energized: Bool = false) {
        self.issues = issues
        self.loadStates = loadStates
        self.energized = energized
    }

    /// დარღვევები (error severity).
    public var errors: [Issue] { issues.filter { $0.severity == .error } }
    public var warnings: [Issue] { issues.filter { $0.severity == .warning } }

    /// გავიდა თუ არა ვალიდაცია (შეცდომების გარეშე).
    public var passed: Bool { errors.isEmpty }

    public func state(for componentID: String) -> LoadState? {
        loadStates.first { $0.id == componentID }
    }

    // MARK: - Diagnostic signals (fault-finding)

    /// შეიცავს თუ არა შედეგი მოცემული კოდის შენიშვნას.
    public func contains(_ code: IssueCode) -> Bool {
        issues.contains { $0.code == code }
    }

    /// რომელიმე დამცავი გაიგდო (მაგნიტური/თერმული/RCD).
    public var anyTrip: Bool { loadStates.contains { $0.trip != nil } }

    /// რომელიმე დატვირთვაზე შოკის რისკია.
    public var anyShockRisk: Bool { loadStates.contains { $0.shockRisk } }
}

// MARK: - Georgian messages

public enum IssueMessages {
    public static func text(for code: IssueCode) -> String {
        switch code {
        case .missingPE:
            return "დატვირთვას არ აქვს მიერთებული დამცავი მიწა (PE). კორპუსის დაზიანებისას — დენის დაზიანების რისკი. შეაერთე ყვითელ-მწვანე გამტარი."
        case .shortLN:
            return "მოკლე ჩართვა L–N (ფაზა–ნული). ფაზა და ნული პირდაპირ შეერთებულია — ეს დაუშვებელია. ძაბვის ჩართვისას ავტომატი მყისიერად გაიგდება."
        case .shortLPE:
            return "მოკლე ჩართვა L–PE (ფაზა–მიწა). ფაზა პირდაპირ მიწაზეა — ძალიან საშიშია."
        case .shortNPE:
            return "მოკლე ჩართვა N–PE (ნული–მიწა). ნული და მიწა არ უნდა შეერთდეს დატვირთვის მხარეს (TN-C-S-ში გაყოფა მხოლოდ ფარშია)."
        case .shortPhasePhase:
            return "ფაზა–ფაზა მოკლე ჩართვა (400V). ორი ფაზა პირდაპირ შეერთებულია — დაუშვებელია."
        case .socketWithoutRCD:
            return "როზეტის ხაზი ვალდებულია იყოს RCD-ის (30mA) ქვემოთ. დაამატე RCD ან გამოიყენე RCBO."
        case .breakerExceedsCable:
            return "ავტომატის ნომინალი აღემატება კაბელის დასაშვებ დენს. კაბელი გადახურდება ხანძრამდე. შეამცირე ავტომატი ან გაზარდე კაბელის კვეთა."
        case .noBreaker:
            return "ხაზი დაცული არ არის ავტომატით. დაამატე MCB ან RCBO დატვირთვის წინ."
        case .polarityReversed:
            return "პოლარობა არეულია — L და N ადგილებ-შეცვლილია. ფაზა (ყავისფერი) უნდა მიდიოდეს ფაზის ფეხზე, ნული (ლურჯი) — ნულის ფეხზე."
        case .openCircuit:
            return "ხაზი დაუსრულებელია — წრედი ღიაა. დატვირთვამდე ფაზაც და ნულიც უნდა იყოს მიერთებული."
        case .missingFerrule:
            return "მრავალწვერა კაბელს ხრახნიან კლემაში ბუნიკი (ferrule) სჭირდება. დაამატე ბუნიკი ან გამოიყენე ხისტი კაბელი."
        case .looseTerminal:
            return "კლემა არ არის მოჭერილი — დაშურუპე შეერთება. გეჭიროს კლემაზე ხანგრძლივად ან გამოიყენე ერთიანი მოჭერის ღილაკი."
        case .phaseImbalance:
            return "ფაზების დიდი დისბალანსი. დატვირთვები თანაბრად გაანაწილე L1/L2/L3-ზე."
        case .overload:
            return "გადატვირთვა — დენი აღემატება ავტომატის ნომინალს. ავტომატი თერმულად (დაყოვნებით) გაიგდება."
        case .shortCircuit:
            return "მოკლე ჩართვა — ავტომატი მაგნიტურად (მყისიერად) გაიგდა."
        case .leakageTrip:
            return "დენის გაჟონვა აღემოჩნდა — RCD (30mA) გაიგდო და ხაზი გათიშა. ეს დაცვამ იმუშავა სწორად."
        case .shockRisk:
            return "შოკის რისკი! დენი იჟონება, მაგრამ მიწა (PE) მიერთებული არ არის და RCD ვერ ცნობს გაჟონვას."
        case .noSupply:
            return "კვება (230V) მიერთებული არ არის. დააკავშირე შემომავალი L და N."
        case .panelMainNotFirst:
            return "ფარის თავში (პირველი რელსზე) უნდა იყოს მთავარი ამომრთველი. დაამატე ან გადაიტანე ის ყველაზე მარცხნივ."
        case .panelSpdOrder:
            return "SPD (ზეძაბვის დამცავი) უნდა იყოს მთავარ ამომრთველსა და RCD-ს შორის. გადააადგილე ის სწორ ადგილას."
        case .panelRcdAfterMcb:
            return "RCD უნდა იყოს ავტომატების (MCB) წინ — ზემოთ რელსზე, რომ მათ დაცვა უზრუნველყოს. გადაიტანე RCD ავტომატებამდე."
        case .panelBusbarFeed:
            return "ავტომატები სავარცხელი ზოლით (busbar) უნდა იკვებებოდეს RCD-ის გამოსასვლელიდან. დააკავშირე ზოლი RCD-ის L OUT-თან და ავტომატების შესასვლელები ზოლზე."
        }
    }
}
