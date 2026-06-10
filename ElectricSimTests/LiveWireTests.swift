//
//  LiveWireTests.swift
//  ElectricSimTests
//
//  Live-wire უსაფრთხოების ლოგიკის ტესტები — ცოცხალი ნაწილის ამოცნობა,
//  რედაქტირების დაბლოკვა ჩართულ ფარზე და შოკის ჯარიმის დათვლა.
//

import XCTest
@testable import ElectricSimCore

final class LiveWireTests: XCTestCase {

    /// მხოლოდ კვების წყაროიანი ფარი (ცოცხალი L გამოსავალი).
    private func supplyBoard() -> Board {
        var b = Board(phase: .single)
        b.add(ComponentFactory.supply(id: "supply", phase: .single))
        return b
    }

    // 1) ჯარიმა = ჯილდოს 10%, floor 0.
    func testShockPenaltyIsTenPercentFlooredAtZero() {
        XCTAssertEqual(LiveWire.shockPenalty(reward: 100), 10)
        XCTAssertEqual(LiveWire.shockPenalty(reward: 250), 25)
        XCTAssertEqual(LiveWire.shockPenalty(reward: 0), 0)
        XCTAssertEqual(LiveWire.shockPenalty(reward: -40), 0)
    }

    // 2) ანალიზის შემდეგ კვების წყარო ცოცხალია (L hot), PE — არა.
    func testSupplyOutputIsLive() {
        let board = supplyBoard()
        let analysis = CircuitSolver().analyze(board)
        let supply = board.components.first { $0.id == "supply" }!
        XCTAssertTrue(LiveWire.isComponentLive(analysis, supply), "კვების წყარო ცოცხალია")
        let lPort = supply.ports.first { $0.conductor == .L }!
        XCTAssertTrue(LiveWire.isPortLive(analysis, lPort.id), "L გამოსავალი ცოცხალია")
        if let pe = supply.ports.first(where: { $0.conductor == .PE }) {
            XCTAssertFalse(LiveWire.isPortLive(analysis, pe.id), "PE არ არის ფაზა → არა ცოცხალი")
        }
    }

    // 3) რედაქტირება იბლოკება მხოლოდ ჩართულ ფარზე + ცოცხალ ფეხზე.
    func testEditBlockedOnlyWhenEnergizedAndTouchingLive() {
        let board = supplyBoard()
        let analysis = CircuitSolver().analyze(board)
        let supply = board.components.first { $0.id == "supply" }!
        let lPort = supply.ports.first { $0.conductor == .L }!.id
        let pePort = supply.ports.first { $0.conductor == .PE }!.id

        // ჩართული + ცოცხალი → დაბლოკილია (შოკი)
        XCTAssertTrue(LiveWire.isEditBlocked(energized: true, analysis: analysis, touchingPorts: [lPort]))
        // გამორთული → არასდროს ბლოკავს (თავისუფალი რედაქტირება)
        XCTAssertFalse(LiveWire.isEditBlocked(energized: false, analysis: analysis, touchingPorts: [lPort]))
        // ჩართული, მაგრამ არა-ცოცხალი ფეხი (PE) → არ ბლოკავს
        XCTAssertFalse(LiveWire.isEditBlocked(energized: true, analysis: analysis, touchingPorts: [pePort]))
        // nil ანალიზი (გამორთული) → არ ბლოკავს
        XCTAssertFalse(LiveWire.isEditBlocked(energized: true, analysis: nil, touchingPorts: [lPort]))
    }
}
