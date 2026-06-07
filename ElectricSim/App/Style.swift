//
//  Style.swift
//  ElectricSim
//
//  ვიზუალური დამხმარეები: სადენის ფერები, კომპონენტის იკონები.
//

import SwiftUI
import UIKit

extension ComponentKind {
    /// Assets-ში ჩასასმელი სურათის სახელი (მაგ. "comp_mcb").
    /// თუ ასეთი იმიჯ-სეტი არსებობს, ბანქოზე ფოტო გამოჩნდება; თუ არა — SF Symbol.
    var assetName: String { "comp_\(rawValue)" }
    var hasArtwork: Bool { UIImage(named: assetName) != nil }
}

extension WireColor {
    /// ეკრანის ფერი (IEC ჰარმონიზებული).
    var swiftUIColor: Color {
        switch self {
        case .yellowGreen: return Color(red: 0.55, green: 0.78, blue: 0.10)
        case .blue:        return Color(red: 0.10, green: 0.45, blue: 0.95)
        case .brown:       return Color(red: 0.55, green: 0.35, blue: 0.18)
        case .black:       return Color(white: 0.12)
        case .grey:        return Color(white: 0.55)
        }
    }
}

extension Conductor {
    var swiftUIColor: Color { WireColor.standard(for: self).swiftUIColor }
}

extension Color {
    /// მთავარი ბრენდის აქცენტი (ლურჯი) — ნავიგაცია/ღილაკები/აქცენტები.
    static let brand = Color(red: 0.16, green: 0.50, blue: 0.96)
    /// „ცოცხალი / ანთებული" — მხოლოდ ენერგიის/ნათების მნიშვნელობით (ყვითელი).
    static let energized = Color(red: 1.0, green: 0.80, blue: 0.0)
}

// ShapeStyle-კონტექსტში (.foregroundStyle(.brand) / .fill(.brand) …) leading-dot-ისთვის.
extension ShapeStyle where Self == Color {
    static var brand: Color { Color.brand }
    static var energized: Color { Color.energized }
}

extension ComponentKind {
    var sfSymbol: String {
        switch self {
        case .supply:     return "bolt.fill"
        case .mainSwitch: return "switch.2"
        case .spd:        return "shield.lefthalf.filled"
        case .rcd:        return "shield.checkerboard"
        case .rcbo:       return "shield.fill"
        case .mcb:        return "powerplug.fill"
        case .busbar:     return "rectangle.grid.1x2"
        case .lamp:       return "lightbulb.fill"
        case .socket:     return "poweroutlet.type.f.fill"
        case .motor:      return "fanblades.fill"
        case .mpcb:       return "shield.lefthalf.filled.badge.checkmark"
        case .contactor:  return "rectangle.connected.to.line.below"
        case .relay:      return "switch.2"
        case .lightSwitch: return "lightswitch.on"
        case .wago:       return "point.3.connected.trianglepath.dotted"
        case .dimmer:     return "lightbulb.led.fill"
        case .boiler:     return "drop.fill"
        case .oven:       return "oven.fill"
        case .heater:     return "heater.vertical.fill"
        case .airConditioner: return "air.conditioner.horizontal.fill"
        case .socket3ph:  return "poweroutlet.type.h.fill"
        case .smartSwitch: return "switch.programmable.fill"
        case .smartRelay: return "wifi.circle.fill"
        case .smartDimmer: return "slider.horizontal.below.sun.max"
        case .smartMeter: return "gauge.with.needle.fill"
        case .fuse:       return "bolt.horizontal.circle.fill"
        case .terminalBlock: return "rectangle.split.3x1.fill"
        case .emergencyStop: return "stop.circle.fill"
        case .selectorSwitch: return "switch.2"
        case .indicatorLight: return "lightbulb.fill"
        case .currentTransformer: return "circle.dashed"
        case .transformer: return "bolt.square.fill"
        case .vfd:        return "waveform.path"
        case .generator:  return "bolt.fill"
        case .solarPanel: return "sun.max.fill"
        case .ups:        return "battery.100.bolt"
        case .inverter:   return "arrow.left.arrow.right"
        case .battery:    return "battery.100"
        }
    }

    var georgianShort: String {
        switch self {
        case .supply:     return "კვება"
        case .mainSwitch: return "მთავარი"
        case .spd:        return "SPD"
        case .rcd:        return "RCD"
        case .rcbo:       return "RCBO"
        case .mcb:        return "ავტომატი"
        case .busbar:     return "ზოლი"
        case .lamp:       return "ნათურა"
        case .socket:     return "როზეტი"
        case .motor:      return "მოტორი"
        case .mpcb:       return "MPCB"
        case .contactor:  return "კონტაქტორი"
        case .relay:      return "რელე"
        case .lightSwitch: return "გამთიშველი"
        case .wago:       return "Wago"
        case .dimmer:     return "დიმერი"
        case .boiler:     return "ბოილერი"
        case .oven:       return "ღუმელი"
        case .heater:     return "გამახურებელი"
        case .airConditioner: return "კონდიციონერი"
        case .socket3ph:  return "3-ფაზ. როზეტი"
        case .smartSwitch: return "Smart ამომრთ."
        case .smartRelay: return "Smart რელე"
        case .smartDimmer: return "Smart დიმერი"
        case .smartMeter: return "Smart მრიცხ."
        case .fuse:       return "დამცველი"
        case .terminalBlock: return "კლემები"
        case .emergencyStop: return "ავარიული"
        case .selectorSwitch: return "გადამრთ."
        case .indicatorLight: return "სიგნ. ნათ."
        case .currentTransformer: return "დენის ტრ."
        case .transformer: return "ტრანსფ."
        case .vfd:        return "VFD"
        case .generator:  return "გენერატ."
        case .solarPanel: return "მზის პან."
        case .ups:        return "UPS"
        case .inverter:   return "ინვერტ."
        case .battery:    return "აკუმ."
        }
    }
}

extension IssueSeverity {
    var color: Color {
        switch self {
        case .error:   return .red
        case .warning: return .orange
        case .info:    return .blue
        }
    }
    var icon: String {
        switch self {
        case .error:   return "xmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }
}
