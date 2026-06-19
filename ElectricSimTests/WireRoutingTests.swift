//
//  WireRoutingTests.swift
//  ElectricSimTests
//
//  ხელით გაყვანის გეომეტრია: შუა-წერტილების persist, 90° vs გლუვი სიგრძე,
//  და უკუთავსებადი (backward-compatible) დეკოდი ძველი ფარებისთვის.
//

import XCTest
@testable import ElectricSimCore

final class WireRoutingTests: XCTestCase {

    private let a = RoutePoint(x: 0, y: 0)
    private let b = RoutePoint(x: 100, y: 0)

    // MARK: სიგრძე — შუა-წერტილების გარეშე base არ იცვლება

    func testNoWaypointsKeepsBaseLength() {
        let len = WireRouting.effectiveLength(baseM: 10, from: a, [], to: b, style: .rightAngle)
        XCTAssertEqual(len, 10, accuracy: 0.0001, "სწორი სადენი base სიგრძეს ინარჩუნებს")
        let smooth = WireRouting.effectiveLength(baseM: 10, from: a, [], to: b, style: .smooth)
        XCTAssertEqual(smooth, 10, accuracy: 0.0001)
    }

    // MARK: 90° — Manhattan სიგრძე ახანგრძლივებს კაბელს

    func testRightAngleWaypointLengthensCable() {
        // A(0,0) → w(50,50) → B(100,0): straight = 100.
        // 90° routed = (|50|+|50|) + (|50|+|50|) = 200 → ratio 2 → 10m → 20m.
        let w = [RoutePoint(x: 50, y: 50)]
        let len = WireRouting.effectiveLength(baseM: 10, from: a, w, to: b, style: .rightAngle)
        XCTAssertEqual(len, 20, accuracy: 0.001, "90° მოღუნვა აორმაგებს ამ გეომეტრიის სიგრძეს")
    }

    // MARK: გლუვი — polyline (სწორი) მანძილი, 90°-ზე მოკლე

    func testSmoothShorterThanRightAngle() {
        let w = [RoutePoint(x: 50, y: 50)]
        let ra = WireRouting.routedLength(from: a, w, to: b, style: .rightAngle)
        let sm = WireRouting.routedLength(from: a, w, to: b, style: .smooth)
        XCTAssertGreaterThan(ra, sm, "90° Manhattan უფრო გრძელია, ვიდრე გლუვი polyline")
        // polyline: 2 × hypot(50,50) ≈ 141.42
        XCTAssertEqual(sm, 2 * (50.0 * 50.0 + 50.0 * 50.0).squareRoot(), accuracy: 0.01)
    }

    // MARK: ნულოვანი/გადაგვარებული — base fallback

    func testZeroLengthEndpointsFallBackToBase() {
        let w = [RoutePoint(x: 5, y: 5)]
        let len = WireRouting.effectiveLength(baseM: 7, from: a, w, to: a, style: .rightAngle)
        XCTAssertEqual(len, 7, accuracy: 0.0001, "გადაგვარებულ ბოლოებზე base-ს ვაბრუნებთ")
    }

    // MARK: Wire — შუა-წერტილები persist round-trip JSON-ში

    func testWireWaypointsCodableRoundTrip() throws {
        var wire = Wire(from: "p1", to: "p2", csaMm2: 2.5, color: .blue, lengthM: 8)
        wire.waypoints = [RoutePoint(x: 12, y: 34), RoutePoint(x: 56, y: 78)]
        wire.routeStyle = .smooth
        let data = try JSONEncoder().encode(wire)
        let back = try JSONDecoder().decode(Wire.self, from: data)
        XCTAssertEqual(back.waypoints, wire.waypoints)
        XCTAssertEqual(back.routeStyle, .smooth)
        XCTAssertEqual(back.baseLengthM, 8, accuracy: 0.0001)
    }

    // MARK: უკუთავსებადი — ძველი JSON (routing ველების გარეშე) იტვირთება

    func testLegacyWireDecodesWithDefaults() throws {
        let legacy = """
        {"id":"w1","fromPortID":"p1","toPortID":"p2","csaMm2":1.5,
         "color":"blue","cableType":"copper","conductorType":"solid",
         "lengthM":6,"ferruled":false,"tightened":true}
        """.data(using: .utf8)!
        let wire = try JSONDecoder().decode(Wire.self, from: legacy)
        XCTAssertTrue(wire.waypoints.isEmpty, "ძველ სადენს შუა-წერტილები არ აქვს")
        XCTAssertEqual(wire.routeStyle, .rightAngle, "default 90°")
        XCTAssertEqual(wire.baseLengthM, 6, accuracy: 0.0001, "base = lengthM ძველ ფარზე")
    }
}
