// swift-tools-version:5.9
//
//  Package.swift — ElectricSimCore
//
//  წრედის ამომხსნელის (solver) დამოუკიდებელი, ტესტირებადი მოდული.
//  გაშვება:  swift test
//
//  აპლიკაცია (SwiftUI) ცალკე იხსნება Xcode-ში: ElectricSim.xcodeproj
//

import PackageDescription

let package = Package(
    name: "ElectricSimCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "ElectricSimCore", targets: ["ElectricSimCore"])
    ],
    targets: [
        .target(
            name: "ElectricSimCore",
            path: "ElectricSim/Core",
            resources: [
                .process("Data")
            ]
        ),
        .testTarget(
            name: "ElectricSimCoreTests",
            dependencies: ["ElectricSimCore"],
            path: "ElectricSimTests"
        )
    ]
)
