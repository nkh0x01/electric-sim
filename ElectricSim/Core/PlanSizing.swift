//
//  PlanSizing.swift
//  ElectricSim — Core
//
//  წინ-მიმართული (forward) დაზომვა მონტაჟის დიზაინერისთვის: დატვირთვის ჯამი →
//  საჭირო ავტომატი → საჭირო კაბელის კვეთა. `Ampacity.table`-ის ინვერსია —
//  არსებულ წესს არ ცვლის, მხოლოდ რეკომენდაციას აგებს.
//

import Foundation

public enum PlanSizing {
    /// სტანდარტული ავტომატის ნომინალები (A) — ზრდადობით.
    public static let standardBreakers: [Double] = [6, 10, 16, 20, 25, 32, 40, 50, 63]

    /// დატვირთვის დენი (A): I = P / U. ერთფაზა — 230V; სამფაზა — √3·400V.
    public static func currentA(loadSumW: Double, phase: Phase) -> Double {
        guard loadSumW > 0 else { return 0 }
        let u = phase == .three
            ? Double(3).squareRoot() * Electrical.phaseToPhase
            : Electrical.phaseToNeutral
        return loadSumW / u
    }

    /// საჭირო ავტომატი — უმცირესი სტანდარტული ნომინალი, რომელიც დენს ფარავს.
    /// აბრუნებს nil-ს, თუ დენი ყველა სტანდარტულ ნომინალს აჭარბებს.
    public static func requiredBreaker(forLoadSumW loadSumW: Double, phase: Phase) -> Double? {
        let i = currentA(loadSumW: loadSumW, phase: phase)
        guard i > 0 else { return standardBreakers.first }
        return standardBreakers.first { $0 >= i - 0.0001 }
    }

    /// საჭირო უმცირესი კაბელის კვეთა (mm²) მოცემული ავტომატისთვის — პირველი
    /// კვეთა `Ampacity.table`-დან, რომლის maxBreaker ≥ ნომინალი (მასალის დერეიტით).
    /// აბრუნებს nil-ს, თუ ცხრილში შესაფერისი კვეთა არ არის.
    public static func minCSA(forBreaker ratingA: Double, cable: CableType) -> Double? {
        Ampacity.table
            .sorted { $0.csa < $1.csa }
            .first { Ampacity.maxBreaker(forCsa: $0.csa, cable: cable) >= ratingA - 0.0001 }?
            .csa
    }
}
