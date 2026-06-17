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

    /// 3-ფაზიანი სავარცხელი: კბილები ბრუნავს L1/L2/L3 და solver მათ *ცალკე*
    /// ქსელებად აჯგუფებს — ფაზა-ფაზა მოკლედება არ ხდება, ხოლო თითო ფაზის
    /// კვება მთელ თავის ჯგუფს ანათებს (rotating distribution).
    func testThreePhaseCombKeepsPhasesSeparate() {
        var b = Board(phase: .three)
        b.add(ComponentFactory.supply(id: "supply", phase: .three))
        b.add(ComponentFactory.mainSwitch(id: "main", phase: .three))
        // 6 ერთპოლუსიანი ავტომატი (L-შესასვლელი); სავარცხელი ანაწილებს ფაზებს
        for i in 0..<6 { b.add(ComponentFactory.mcb(id: "mcb\(i)", ratingA: 10)) }
        for i in 0..<6 { b.add(ComponentFactory.lamp(id: "lamp\(i)")) }
        b.add(ComponentFactory.comb(id: "comb", teeth: 6, phase: .three))

        // შემომავალი: supply → main (სამივე ფაზა + N)
        for c in ["L1", "L2", "L3", "N"] {
            b.connect("supply.\(c)", "main.\(c)in", csaMm2: 6, color: .brown)
        }
        // სავარცხელი ჯდება ავტომატებზე: tooth i → mcb_i.in (ბრუნვა L1,L2,L3,L1,L2,L3)
        for i in 0..<6 { b.connect("comb.\(i)", "mcb\(i).in", csaMm2: 10, color: .brown, tightened: true) }
        // მხოლოდ 3 კვება — თითო ფაზა ერთხელ; სავარცხელი დანარჩენებს ანაწილებს
        b.connect("main.L1out", "mcb0.in", csaMm2: 10, color: .brown)
        b.connect("main.L2out", "mcb1.in", csaMm2: 10, color: .black)
        b.connect("main.L3out", "mcb2.in", csaMm2: 10, color: .grey)
        // დატვირთვები: თითო ავტომატის გამოსასვლელი → ნათურის L; N/PE საერთო
        for i in 0..<6 {
            b.connect("mcb\(i).out", "lamp\(i).L", csaMm2: 1.5, color: .brown)
            b.connect("main.Nout", "lamp\(i).N", csaMm2: 1.5, color: .blue)
            b.connect("supply.PE", "lamp\(i).PE", csaMm2: 1.5, color: .yellowGreen)
        }

        let r = CircuitSolver().solve(b, energize: true)
        XCTAssertFalse(r.issues.contains { $0.code == .shortPhasePhase },
                       "ფაზები ცალკეა — სავარცხელი L1/L2/L3-ს არ ამოკლებს")
        XCTAssertEqual(r.loadStates.filter(\.isPowered).count, 6,
                       "სამივე ფაზის კვება სავარცხელით 6-ვე ნათურამდე ნაწილდება")
    }

    /// ბაგ-რეგრესია: ერთ ფაზა-ჯგუფში ორი სხვადასხვა ფაზის შეყვანა = მოკლედება.
    /// (mcb0 და mcb3 ერთ L1-ჯგუფშია; თუ mcb3-ს L2-ით ვკვებავთ → ფაზა-ფაზა short.)
    func testThreePhaseCombMisfeedShorts() {
        var b = Board(phase: .three)
        b.add(ComponentFactory.supply(id: "supply", phase: .three))
        b.add(ComponentFactory.mainSwitch(id: "main", phase: .three))
        for i in 0..<4 { b.add(ComponentFactory.mcb(id: "mcb\(i)", ratingA: 10)) }
        b.add(ComponentFactory.comb(id: "comb", teeth: 4, phase: .three))
        for c in ["L1", "L2", "L3", "N"] { b.connect("supply.\(c)", "main.\(c)in", csaMm2: 6, color: .brown) }
        for i in 0..<4 { b.connect("comb.\(i)", "mcb\(i).in", csaMm2: 10, color: .brown, tightened: true) }
        // mcb0 (tooth0=L1) ← L1; mcb3 (tooth3=L1, იმავე ჯგუფში) ← L2 ❌
        b.connect("main.L1out", "mcb0.in", csaMm2: 10, color: .brown)
        b.connect("main.L2out", "mcb3.in", csaMm2: 10, color: .black)
        let r = CircuitSolver().solve(b, energize: true)
        XCTAssertTrue(r.issues.contains { $0.code == .shortPhasePhase },
                      "ერთ comb-ფაზაში L1+L2 → ფაზა-ფაზა მოკლედება")
    }

    /// comb_3p შაბლონი + ახალი 3-ფაზიანი დონე იტვირთება და ბორდის ფაზით
    /// ინსტანცირებისას სავარცხელი მართლა 3-ფაზიანი ხდება.
    func testThreePhaseCombLevelLoads() throws {
        let templates = try GameData.loadTemplates()
        let t = try XCTUnwrap(templates["comb_3p"])
        XCTAssertEqual(t.kind, .comb)
        // 3-ფაზიან ბორდზე ინსტანცირება → კბილები ბრუნავს L1/L2/L3
        let inst = t.makeComponent(instanceID: "comb_3p_1", phase: .three)
        XCTAssertEqual(Array(inst.ports.prefix(3)).map(\.conductor), [.L1, .L2, .L3])

        let levels = try GameData.loadLevels()
        let lv = try XCTUnwrap(levels.first { $0.id == "lvl_panel_3ph_comb" })
        XCTAssertEqual(lv.phase, .three)
        XCTAssertTrue(lv.isPanelAssembly)
        XCTAssertTrue(lv.palette.contains { $0.templateId == "comb_3p" })
        // დონის პალიტრის ყველა შაბლონი არსებობს
        for e in lv.palette { XCTAssertNotNil(templates[e.templateId], "ნაკლული: \(e.templateId)") }
    }

    /// 3-ფაზიანი სავარცხელის ფაბრიკა: კბილები მართლა ბრუნავს L1/L2/L3.
    func testThreePhaseCombFactoryRotates() {
        let comb = ComponentFactory.comb(id: "c", teeth: 7, phase: .three)
        let conds = comb.ports.map(\.conductor)
        XCTAssertEqual(conds, [.L1, .L2, .L3, .L1, .L2, .L3, .L1])
        XCTAssertTrue(comb.name.contains("3-ფაზიანი"))
        // ერთფაზიანი უცვლელია — ყველა კბილი L
        let one = ComponentFactory.comb(id: "c1", teeth: 4)
        XCTAssertEqual(Set(one.ports.map(\.conductor)), [.L])
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

    // MARK: ბერკეტი — ხელით ჩართვა/გამორთვა (per-device open/closed)

    /// გამორთული ავტომატი ღია კონტაქტია — მისი დატვირთვა ქრება; ჩართვისას ბრუნდება.
    func testOpenBreakerCutsDownstreamCurrent() {
        func build(mcbOpen: Bool) -> SimulationResult {
            var b = Board(phase: .single)
            b.add(ComponentFactory.supply(id: "supply"))
            var mcb = ComponentFactory.mcb(id: "mcb1", ratingA: 10)
            mcb.isOpen = mcbOpen
            b.add(mcb)
            b.add(ComponentFactory.lamp(id: "lamp1"))
            b.connect("supply.L", "mcb1.in", csaMm2: 1.5, color: .brown)
            b.connect("mcb1.out", "lamp1.L", csaMm2: 1.5, color: .brown)
            b.connect("supply.N", "lamp1.N", csaMm2: 1.5, color: .blue)
            b.connect("supply.PE", "lamp1.PE", csaMm2: 1.5, color: .yellowGreen)
            return CircuitSolver().solve(b, energize: true)
        }
        XCTAssertEqual(build(mcbOpen: false).loadStates.filter(\.isPowered).count, 1,
                       "ჩართული ავტომატი — ნათურა ანთია")
        XCTAssertEqual(build(mcbOpen: true).loadStates.filter(\.isPowered).count, 0,
                       "გამორთული ავტომატი — დენი არ გადის, ნათურა ჩამქრალია")
        // toggleable სიმრავლე
        XCTAssertTrue(ComponentKind.mcb.isToggleable)
        XCTAssertTrue(ComponentKind.rcd.isToggleable)
        XCTAssertTrue(ComponentKind.mainSwitch.isToggleable)
        XCTAssertFalse(ComponentKind.lamp.isToggleable)
        XCTAssertFalse(ComponentKind.busbar.isToggleable)
    }

    /// გამორთული ფეხი ცოცხალი აღარ არის (live-wire უსაფრთხოება — ანალიზიც პატივს სცემს).
    func testOpenBreakerKillsDownstreamLive() {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "supply"))
        var mcb = ComponentFactory.mcb(id: "mcb1", ratingA: 10)
        mcb.isOpen = true
        b.add(mcb)
        b.connect("supply.L", "mcb1.in", csaMm2: 1.5, color: .brown)
        let solver = CircuitSolver()
        XCTAssertTrue(solver.isLive(b, "mcb1.in"), "შესასვლელი ფაზაზეა (კვების მხარე)")
        XCTAssertFalse(solver.isLive(b, "mcb1.out"), "გამორთულის გამოსასვლელი მკვდარია")
    }

    // MARK: კარადა (Enclosure) — ფიზიკური მოდელი (v1.1 Pro Panel)

    /// სტანდარტული ზომები სწორ რიგებსა და per-row მოდულებს იძლევა.
    func testEnclosureSizesProduceCorrectRowsAndCapacity() {
        XCTAssertEqual(EnclosureSize.m12.rows, 1); XCTAssertEqual(EnclosureSize.m12.modulesPerRow, 12)
        XCTAssertEqual(EnclosureSize.m18.rows, 1); XCTAssertEqual(EnclosureSize.m18.modulesPerRow, 18)
        XCTAssertEqual(EnclosureSize.m24.rows, 2); XCTAssertEqual(EnclosureSize.m24.modulesPerRow, 12)
        XCTAssertEqual(EnclosureSize.m36.rows, 3); XCTAssertEqual(EnclosureSize.m36.modulesPerRow, 12)
        XCTAssertEqual(EnclosureSize.m48.rows, 4); XCTAssertEqual(EnclosureSize.m48.modulesPerRow, 12)
        // ჯამური ტევადობა = ზომა
        for s in EnclosureSize.allCases { XCTAssertEqual(s.rows * s.modulesPerRow, s.rawValue) }
    }

    func testSmallestFittingEnclosure() {
        XCTAssertEqual(EnclosureSize.smallestFitting(modules: 5), .m12)
        XCTAssertEqual(EnclosureSize.smallestFitting(modules: 12), .m12)
        XCTAssertEqual(EnclosureSize.smallestFitting(modules: 13), .m18)
        XCTAssertEqual(EnclosureSize.smallestFitting(modules: 20, minRows: 2), .m24)
        XCTAssertEqual(EnclosureSize.smallestFitting(modules: 1, minRows: 4), .m48)
    }

    /// ცემების (knockout) გახსნა/დახურვა მდგომარეობა.
    func testKnockoutOpenCloseState() {
        var enc = Enclosure(size: .m24, mount: .flush)
        let k = enc.availableKnockouts.first { $0.edge == .top }!
        XCTAssertFalse(enc.isOpen(k))
        enc.toggle(k); XCTAssertTrue(enc.isOpen(k))
        enc.toggle(k); XCTAssertFalse(enc.isOpen(k))
        // ზედა + ქვედა კიდე ცემებს შეიცავს (მინიმუმ)
        XCTAssertTrue(enc.availableKnockouts.contains { $0.edge == .top })
        XCTAssertTrue(enc.availableKnockouts.contains { $0.edge == .bottom })
    }

    /// Level → კარადა: explicit ზომა; არსებული დონეები railCount-იდან (რეგრესია).
    func testLevelResolvedEnclosure() throws {
        let levels = try GameData.loadLevels()
        // არსებული პანელ-დონეები — რიგები ემთხვევა ძველ railCount-ს (უცვლელი)
        XCTAssertEqual(levels.first { $0.id == "lvl_panel_basic" }?.resolvedRailCount, 2)
        XCTAssertEqual(levels.first { $0.id == "lvl_panel_basic" }?.resolvedEnclosure.rows, 2)
        XCTAssertEqual(levels.first { $0.id == "lvl_sandbox_1ph" }?.resolvedEnclosure.size, .m48)
        XCTAssertEqual(levels.first { $0.id == "lvl_tutorial" }?.resolvedEnclosure.rows, 1)
        // tutorial (არა-panelAssembly) → surface; panelAssembly default → flush
        XCTAssertEqual(levels.first { $0.id == "lvl_tutorial" }?.resolvedEnclosure.mount, .surface)
        XCTAssertEqual(levels.first { $0.id == "lvl_panel_basic" }?.resolvedEnclosure.mount, .flush)
    }

    /// ცარიელი მოდული: ფეხების გარეშე, ელექტრულად ინერტული, solver-ი უგულებელყოფს.
    func testBlankModuleIsElectricallyInert() throws {
        XCTAssertEqual(ComponentKind.blank.moduleWidthUnits, 1)
        XCTAssertFalse(ComponentKind.blank.isLoad)
        XCTAssertFalse(ComponentKind.blank.isSource)
        XCTAssertFalse(ComponentKind.blank.isConnector)
        XCTAssertFalse(ComponentKind.blank.isSeriesDevice)
        let blank = ComponentFactory.blank(id: "blank1")
        XCTAssertTrue(blank.ports.isEmpty)

        // ნათურის წრე + ცარიელი მოდული გვერდით → წრე უცვლელად მუშაობს
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "supply"))
        b.add(ComponentFactory.mcb(id: "mcb1", ratingA: 10))
        b.add(ComponentFactory.lamp(id: "lamp1"))
        b.add(ComponentFactory.blank(id: "blank1"))   // ინერტული შემავსებელი
        b.connect("supply.L", "mcb1.in", csaMm2: 1.5, color: .brown)
        b.connect("mcb1.out", "lamp1.L", csaMm2: 1.5, color: .brown)
        b.connect("supply.N", "lamp1.N", csaMm2: 1.5, color: .blue)
        b.connect("supply.PE", "lamp1.PE", csaMm2: 1.5, color: .yellowGreen)
        let r = CircuitSolver().solve(b, energize: true)
        XCTAssertEqual(r.loadStates.filter(\.isPowered).count, 1, "ცარიელი მოდული წრეს არ ცვლის")

        // შაბლონი იტვირთება და auxiliary-შია
        let templates = try GameData.loadTemplates()
        let t = try XCTUnwrap(templates["blank_1"])
        XCTAssertEqual(t.kind, .blank)
        XCTAssertEqual(ComponentCategory.forKind(.blank), .auxiliary)
    }

    /// რიგის ტევადობა: მოდულების ჯამური სიგანე ვერ აღემატება modulesPerRow-ს.
    func testRowCapacityRule() {
        let enc = Enclosure(size: .m12)   // 1 რიგი × 12 სლოტი
        XCTAssertTrue(enc.rowHasRoom(usedSlots: 10, adding: 2))   // 12 ≤ 12 ✓
        XCTAssertFalse(enc.rowHasRoom(usedSlots: 11, adding: 2))  // 13 > 12 ✗
        XCTAssertTrue(enc.rowHasRoom(usedSlots: 0, adding: 12))
        XCTAssertFalse(enc.rowHasRoom(usedSlots: 0, adding: 13))
        // 2 ერთეულიანი მთავარი + 10 × 1 ერთეულიანი ავტომატი = 12 → სავსე
        let m = ComponentKind.mainSwitch.moduleWidthUnits   // 2
        let mcb = ComponentKind.mcb.moduleWidthUnits        // 1
        XCTAssertEqual(m + 10 * mcb, 12)
        XCTAssertFalse(enc.rowHasRoom(usedSlots: 12, adding: mcb))  // მე-11 ავტომატი აღარ ეტევა
    }

    /// მრავალპოლუსიანი ავტომატი: სიგანე = პოლუსები, ფეხები პოლუსებზე, 1P უცვლელი.
    func testMultiPoleMCB() {
        let m1 = ComponentFactory.mcb(id: "m1", ratingA: 16, curve: .C, poles: 1)
        XCTAssertEqual(m1.moduleWidthUnits, 1)
        XCTAssertNotNil(m1.port(side: .input, conductor: .L), "1P — ძველი in/out ფეხები (.L)")
        XCTAssertNotNil(m1.port(side: .output, conductor: .L))

        let m2 = ComponentFactory.mcb(id: "m2", ratingA: 32, curve: .C, poles: 2)
        XCTAssertEqual(m2.poles, 2)
        XCTAssertEqual(m2.moduleWidthUnits, 2, "2P → 2 სლოტი")
        XCTAssertEqual(m2.ports.count, 4, "L in/out + N in/out")

        let m3 = ComponentFactory.mcb(id: "m3", ratingA: 25, curve: .C, poles: 3)
        XCTAssertEqual(m3.moduleWidthUnits, 3, "3P → 3 სლოტი")
        XCTAssertEqual(m3.ports.count, 6, "L1/L2/L3 in/out")

        // asset-სიგანეები: SPD/relay = 2 სლოტი
        XCTAssertEqual(ComponentKind.spd.moduleWidthUnits, 2)
        XCTAssertEqual(ComponentKind.relay.moduleWidthUnits, 2)

        // 2P/3P შაბლონები იტვირთება
        let templates = try! GameData.loadTemplates()
        XCTAssertEqual(templates["mcb_2p_c32"]?.poles, 2)
        XCTAssertEqual(templates["mcb_3p_c25"]?.poles, 3)
    }

    /// ჭკვიანი რელე: 2-პოლუსიანი (L+N), toggleable; გამორთვისას დატვირთვა ქრება.
    func testSmartRelayTwoPoleToggle() {
        XCTAssertTrue(ComponentKind.smartRelay.isToggleable)
        let templates = try! GameData.loadTemplates()
        let t = try! XCTUnwrap(templates["smart_relay"])
        let sr = t.makeComponent(instanceID: "sr1", phase: .single)
        XCTAssertEqual(sr.poles, 2, "2-პოლუსიანი (L+N)")
        XCTAssertNotNil(sr.port(side: .input, conductor: .L))
        XCTAssertNotNil(sr.port(side: .input, conductor: .N))
        XCTAssertNotNil(sr.port(side: .output, conductor: .L))

        func lamp(srOpen: Bool) -> Int {
            var b = Board(phase: .single)
            b.add(ComponentFactory.supply(id: "supply"))
            var relay = t.makeComponent(instanceID: "sr1", phase: .single)
            relay.isOpen = srOpen
            b.add(relay)
            b.add(ComponentFactory.lamp(id: "lamp1"))
            b.connect("supply.L", "sr1.Lin", csaMm2: 1.5, color: .brown)
            b.connect("sr1.Lout", "lamp1.L", csaMm2: 1.5, color: .brown)
            b.connect("supply.N", "sr1.Nin", csaMm2: 1.5, color: .blue)
            b.connect("sr1.Nout", "lamp1.N", csaMm2: 1.5, color: .blue)
            b.connect("supply.PE", "lamp1.PE", csaMm2: 1.5, color: .yellowGreen)
            return CircuitSolver().solve(b, energize: true).loadStates.filter(\.isPowered).count
        }
        XCTAssertEqual(lamp(srOpen: false), 1, "ჩართული რელე — ნათურა ანთია")
        XCTAssertEqual(lamp(srOpen: true), 0, "გამორთული რელე — ორივე პოლუსი იხსნება, ნათურა ქრება")
    }

    /// 4-პოლუსიანი ავტომატი: L1/L2/L3+N, სიგანე 4.
    func testFourPoleMCB() {
        let m4 = ComponentFactory.mcb(id: "m4", ratingA: 25, curve: .C, poles: 4)
        XCTAssertEqual(m4.poles, 4)
        XCTAssertEqual(m4.moduleWidthUnits, 4)
        XCTAssertEqual(Set(m4.ports.map(\.conductor)), [.L1, .L2, .L3, .N])
        XCTAssertEqual(m4.ports.count, 8)   // 4 in + 4 out
        let t = try! GameData.loadTemplates()["mcb_4p_c25"]
        XCTAssertEqual(t?.poles, 4)
    }

    /// მოდულის სიგანე სლოტებში (კარადის ტევადობის გათვლისთვის).
    func testModuleWidthUnits() {
        XCTAssertEqual(ComponentKind.mcb.moduleWidthUnits, 1)
        XCTAssertEqual(ComponentKind.rcd.moduleWidthUnits, 2)
        XCTAssertEqual(ComponentKind.rcbo.moduleWidthUnits, 2)
        XCTAssertEqual(ComponentKind.mainSwitch.moduleWidthUnits, 2)
        XCTAssertEqual(ComponentKind.mpcb.moduleWidthUnits, 3)
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
