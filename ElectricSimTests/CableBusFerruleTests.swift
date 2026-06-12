//
//  CableBusFerruleTests.swift
//  ElectricSimTests
//
//  ქართული კაბელის სახელი, N/PE სალტეები (junction nodes) და მრავალწვერა
//  კაბელის ბუნიკის (ferrule) წესი ხრახნიან კლემაში.
//

import XCTest
@testable import ElectricSimCore

final class CableBusFerruleTests: XCTestCase {

    private func portID(_ comp: Component, _ cond: Conductor, side: PortSide? = nil) -> String {
        comp.ports.first { $0.conductor == cond && (side == nil || $0.side == side) }!.id
    }

    // MARK: Part 2 — ქართული კაბელის სახელი
    func testGeorgianCableName() {
        XCTAssertEqual(ConductorType.solid.cableName(csaMm2: 1.5), "ხისტი კაბელი 1.5მმ² (NYM)")
        XCTAssertEqual(ConductorType.stranded.cableName(csaMm2: 2.5), "მრავალწვერა კაბელი 2.5მმ² (PVS)")
        XCTAssertEqual(ConductorType.solid.cableName(csaMm2: 4), "ხისტი კაბელი 4მმ² (NYM)")
    }

    // MARK: Part 3 — PE/N სალტეები junction nodes-ად (მიწა/ნული გადადის)
    func testPEBusEarthsAndNBusCarriesNeutral() {
        var b = Board(phase: .single)
        let supply = ComponentFactory.supply(id: "supply")
        let lamp = ComponentFactory.lamp(id: "lamp")                 // requiresPE = true
        let peb = ComponentFactory.busbar(id: "peb", conductor: .PE, slots: 4)
        let nb = ComponentFactory.busbar(id: "nb", conductor: .N, slots: 4)
        b.add(supply); b.add(lamp); b.add(peb); b.add(nb)

        // L: lamp → supply
        b.connect(portID(lamp, .L), portID(supply, .L), csaMm2: 1.5, color: .brown)
        // N: lamp → N-bus → supply N
        b.connect(portID(lamp, .N), nb.ports[0].id, csaMm2: 1.5, color: .blue)
        b.connect(nb.ports[1].id, portID(supply, .N), csaMm2: 1.5, color: .blue)
        // PE: lamp → PE-bus → supply PE
        b.connect(portID(lamp, .PE), peb.ports[0].id, csaMm2: 1.5, color: .yellowGreen)
        b.connect(peb.ports[1].id, portID(supply, .PE), csaMm2: 1.5, color: .yellowGreen)

        let r = CircuitSolver().solve(b)
        XCTAssertFalse(r.contains(.missingPE), "PE-სალტეთი მიწა მიერთებულია — missingPE არ უნდა იყოს")
        XCTAssertFalse(r.contains(.openCircuit), "N-სალტეთი ნული მიერთებულია — წრედი დასრულებულია")
    }

    /// კონტროლი: PE-სალტეს გარეშე (PE არ მიერთებული) — missingPE ჩნდება.
    func testMissingPEWhenNoPEBus() {
        var b = Board(phase: .single)
        let supply = ComponentFactory.supply(id: "supply")
        let lamp = ComponentFactory.lamp(id: "lamp")
        b.add(supply); b.add(lamp)
        b.connect(portID(lamp, .L), portID(supply, .L), csaMm2: 1.5, color: .brown)
        b.connect(portID(lamp, .N), portID(supply, .N), csaMm2: 1.5, color: .blue)
        // PE დაუკავშირებელი
        XCTAssertTrue(CircuitSolver().solve(b).contains(.missingPE))
    }

    // MARK: Part 4 — ბუნიკის წესი
    func testStrandedIntoScrewTerminalNeedsFerrule() {
        var b = Board(phase: .single)
        let supply = ComponentFactory.supply(id: "supply")
        let mcb = ComponentFactory.mcb(id: "mcb", ratingA: 16)
        b.add(supply); b.add(mcb)
        let supplyL = portID(supply, .L)
        let mcbIn = portID(mcb, .L, side: .input)

        // მრავალწვერა, ბუნიკის გარეშე → შეცდომა + შეტყობინება
        b.connect(supplyL, mcbIn, csaMm2: 2.5, color: .brown, conductorType: .stranded)
        let r1 = CircuitSolver().solve(b)
        XCTAssertTrue(r1.contains(.missingFerrule), "მრავალწვერა + ხრახნიანი კლემა ბუნიკის გარეშე → შეცდომა")
        XCTAssertTrue(r1.issues.contains { $0.code == .missingFerrule && $0.message.contains("ბუნიკი") },
                      "შეტყობინებაში უნდა იყოს „ბუნიკი“")
        XCTAssertTrue(r1.issues.contains { $0.code == .missingFerrule && $0.message.contains("ავტომატის") },
                      "შეტყობინება უნდა ეხებოდეს ავტომატის კლემას")

        // ბუნიკით → შეცდომა აღარ არის
        var b2 = b
        b2.wires[0].ferruled = true
        XCTAssertFalse(CircuitSolver().solve(b2).contains(.missingFerrule), "ბუნიკით → წესი დაცულია")
    }

    func testSolidCableNeedsNoFerrule() {
        var b = Board(phase: .single)
        let supply = ComponentFactory.supply(id: "supply")
        let mcb = ComponentFactory.mcb(id: "mcb", ratingA: 16)
        b.add(supply); b.add(mcb)
        // ხისტი კაბელი ხრახნიან კლემაში → ბუნიკი არ სჭირდება
        b.connect(portID(supply, .L), portID(mcb, .L, side: .input),
                  csaMm2: 2.5, color: .brown, conductorType: .solid)
        XCTAssertFalse(CircuitSolver().solve(b).contains(.missingFerrule))
    }

    // MARK: მოჭერის (screw-down) წესი
    func testLooseTerminalFailsInspection() {
        var b = Board(phase: .single)
        let supply = ComponentFactory.supply(id: "supply")
        let mcb = ComponentFactory.mcb(id: "mcb", ratingA: 16)
        b.add(supply); b.add(mcb)
        // ახალი ინტერაქტიული შეერთება — მოუჭერელი → ინსპექცია იჭრება შეტყობინებით
        b.connect(portID(supply, .L), portID(mcb, .L, side: .input),
                  csaMm2: 2.5, color: .brown, tightened: false)
        let r = CircuitSolver().solve(b)
        XCTAssertTrue(r.contains(.looseTerminal))
        XCTAssertTrue(r.issues.contains { $0.code == .looseTerminal && $0.message.contains("მოჭერილი") })
        XCTAssertFalse(r.passed, "მოუჭერელი კლემა — ინსპექცია უნდა ჩაიჭრას")

        // მოჭერის შემდეგ — წესი დაცულია
        var b2 = b
        b2.wires[0].tightened = true
        XCTAssertFalse(CircuitSolver().solve(b2).contains(.looseTerminal))
    }

    // MARK: სავარცხელი სალტე (comb) — Stage 3

    /// სავარცხელი ხიდავს მომიჯნავე ავტომატების L-შესასვლელებს: mcb2 მხოლოდ
    /// comb-ით იკვებება და მისი ნათურა მაინც ანთია (junction node).
    func testCombBridgesAdjacentBreakerInputs() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "supply"))
        b.add(ComponentFactory.mainSwitch(id: "main"))
        b.add(ComponentFactory.mcb(id: "mcb1", ratingA: 10))
        b.add(ComponentFactory.mcb(id: "mcb2", ratingA: 10))
        b.add(ComponentFactory.lamp(id: "lamp1"))
        b.add(ComponentFactory.lamp(id: "lamp2"))
        b.add(ComponentFactory.comb(id: "comb", teeth: 8))
        // L: კვება → მთავარი → mcb1; mcb2-ის შესასვლელი მხოლოდ სავარცხელითაა ნაკვები
        b.connect("supply.L", "main.Lin", csaMm2: 2.5, color: .brown)
        b.connect("main.Lout", "mcb1.in", csaMm2: 2.5, color: .brown)
        b.connect("comb.0", "mcb1.in", csaMm2: 10, color: .brown)
        b.connect("comb.1", "mcb2.in", csaMm2: 10, color: .brown)
        b.connect("mcb1.out", "lamp1.L", csaMm2: 1.5, color: .brown)
        b.connect("mcb2.out", "lamp2.L", csaMm2: 1.5, color: .brown)
        // N/PE ორივე ნათურას
        b.connect("supply.N", "main.Nin", csaMm2: 2.5, color: .blue)
        b.connect("main.Nout", "lamp1.N", csaMm2: 1.5, color: .blue)
        b.connect("main.Nout", "lamp2.N", csaMm2: 1.5, color: .blue)
        b.connect("supply.PE", "lamp1.PE", csaMm2: 1.5, color: .yellowGreen)
        b.connect("supply.PE", "lamp2.PE", csaMm2: 1.5, color: .yellowGreen)

        let r = CircuitSolver().solve(b, energize: true)
        XCTAssertTrue(r.passed, "შეცდომები: \(r.errors.map(\.code))")
        XCTAssertEqual(r.loadStates.filter(\.isPowered).count, 2,
                       "ორივე ნათურა ანთია — mcb2 სავარცხელით მიეწოდება")
        // ფარის აწყობის ვალიდაციაც იღებს comb-ს მკვებავ ზოლად
        XCTAssertFalse(PanelAssembly.validate(b).contains { $0.code == .panelBusbarFeed },
                       "comb-ით ნაკვები ავტომატები ვალიდურია (panelBusbarFeed არ ჩნდება)")
    }

    /// comb_1p შაბლონი იტვირთება, კონექტორია და უფასო ნაკრებშია.
    func testCombTemplateLoads() throws {
        let templates = try GameData.loadTemplates()
        let t = try XCTUnwrap(templates["comb_1p"])
        XCTAssertEqual(t.kind, .comb)
        XCTAssertTrue(ComponentKind.comb.isConnector)
        XCTAssertTrue(ComponentGating.isBasicFree(.comb), "1-ფაზიანი სავარცხელი უფასოა")
        let comp = t.makeComponent(instanceID: "comb_1p_1", phase: .single)
        XCTAssertEqual(comp.ports.count, 8, "8 კბილი")
    }

    /// კარადის რელსების რაოდენობა: explicit (clamp 2...4) და heuristic.
    func testRailCountResolution() throws {
        let levels = try GameData.loadLevels()
        XCTAssertEqual(levels.first { $0.id == "lvl_panel_basic" }?.resolvedRailCount, 2)
        XCTAssertEqual(levels.first { $0.id == "lvl_panel_full" }?.resolvedRailCount, 3)
        XCTAssertEqual(levels.first { $0.id == "lvl_sandbox_1ph" }?.resolvedRailCount, 4)
        XCTAssertEqual(levels.first { $0.id == "lvl_tutorial" }?.resolvedRailCount, 1,
                       "heuristic: პატარა Learn-პალიტრა → 1 კომპაქტური რელსი")
        let jobs = try GameData.loadJobs()
        XCTAssertEqual(jobs.first { $0.id == "master_hotel_floor_system" }?.makeLevel()
            .resolvedRailCount, 4, "რთული სამუშაო → 4 რელსი")
        XCTAssertEqual(jobs.first { $0.id == "job_first_lamp" }?.makeLevel()
            .resolvedRailCount, 2, "მარტივი სამუშაო → 2 რელსი")
    }

    // MARK: instance-id გენერაცია (კოლიზიის რეგრესია)

    /// წაშლა-დამატების შემდეგ id აღარ მეორდება: nextInstanceID = max სუფიქსი + 1
    /// (count+1 სქემა tid_2-ის დუბლს ქმნიდა: 2 დადება → tid_1 წაშლა → დამატება).
    func testNextInstanceIDNeverCollidesAfterRemoval() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.mcb(id: "mcb_b10_1", ratingA: 10))
        b.add(ComponentFactory.mcb(id: "mcb_b10_2", ratingA: 10))
        b.components.removeAll { $0.id == "mcb_b10_1" }   // შუა ინსტანციის წაშლა
        let next = b.nextInstanceID(forTemplate: "mcb_b10")
        XCTAssertEqual(next, "mcb_b10_3", "max+1 — არსებულ mcb_b10_2-ს არ უნდა დაემთხვეს")
        b.add(ComponentFactory.mcb(id: next, ratingA: 10))
        XCTAssertEqual(Set(b.components.map(\.id)).count, b.components.count,
                       "ფარზე id-ები უნიკალური უნდა იყოს")
        // პრეფიქსით მსგავსი სხვა შაბლონი (mcb_b1 vs mcb_b10) არ ერევა
        XCTAssertEqual(b.nextInstanceID(forTemplate: "mcb_b1"), "mcb_b1_1")
        // არა-რიცხვითი სუფიქსები (prebuilt id-ები, მაგ. "B1") უგულებელყოფილია
        b.add(ComponentFactory.mcb(id: "mcb_b10_x", ratingA: 10))
        XCTAssertEqual(b.nextInstanceID(forTemplate: "mcb_b10"), "mcb_b10_4")
    }

    /// წინასწარ აწყობილი/ძველი ფარები მოჭერილია ნაგულისხმევად (connect/decode default).
    func testDefaultConnectionsAreTightened() throws {
        var b = Board(phase: .single)
        let supply = ComponentFactory.supply(id: "supply")
        let mcb = ComponentFactory.mcb(id: "mcb", ratingA: 16)
        b.add(supply); b.add(mcb)
        b.connect(portID(supply, .L), portID(mcb, .L, side: .input), csaMm2: 2.5, color: .brown)
        XCTAssertTrue(b.wires[0].tightened, "ნაგულისხმევი შეერთება მოჭერილია")
        XCTAssertFalse(CircuitSolver().solve(b).contains(.looseTerminal))

        // ძველი JSON (tightened ველის გარეშე) → მოჭერილად იშიფრება
        let json = """
        {"id":"w1","fromPortID":"a","toPortID":"b","csaMm2":1.5,"color":"brown"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Wire.self, from: json)
        XCTAssertTrue(decoded.tightened)
    }
}
