//
//  ProjectCompiler.swift
//  ElectricSim — Core
//
//  „გასაღები ხიდი": მონტაჟის პროექტს თარგმნის Board-ად, რომ უკვე არსებულმა
//  CircuitSolver / PanelAssembly შეამოწმოს — IEC წესების გადაწერის გარეშე.
//
//  Phase 1: ერთფაზა, ერთი წრედი: supply → main → ავტომატი → დატვირთვები.
//  კაბელის ტრასის სიგრძე ეწერება ცხელი/ნული/PE სადენების lengthM-ში, რომ
//  ძაბვის ვარდნა გაზომილ სიგრძეს დაეყრდნოს.
//

import Foundation

public enum ProjectCompiler {

    /// პროექტი → Board. templates-იდან აგებს დატვირთვის კომპონენტებს (powerW…).
    public static func board(from project: InstallationProject,
                             templates: [String: ComponentTemplate]) -> Board {
        var board = Board(phase: project.phase)

        // 1) კვება + მთავარი ამომრთველი
        let supply = ComponentFactory.supply(id: "supply", phase: project.phase)
        let main = ComponentFactory.mainSwitch(id: "main", phase: project.phase)
        board.add(supply)
        board.add(main)

        // 2) წრედის ავტომატი (არჩეული ნომინალით/მახასიათებლით)
        let c = project.circuit
        let mcb = ComponentFactory.mcb(id: "brk_\(c.id)", ratingA: c.breakerRatingA,
                                       curve: c.breakerCurve, poles: 1)
        board.add(mcb)

        // 3) დატვირთვები — შაბლონიდან (თუ აკლია, kind-ის ფაბრიკით fallback)
        var loadComponents: [Component] = []
        for lid in c.loadIDs {
            guard let lp = project.loads.first(where: { $0.id == lid }) else { continue }
            let comp = makeLoad(lp, templates: templates)
            board.add(comp)
            loadComponents.append(comp)
        }

        let runM = project.runLengthM()
        let csa = c.csaMm2
        let cable = c.cableType

        // 4) გაყვანა — incomer (მოკლე) + per-load ტრასა (გაზომილი სიგრძით)
        // supply L/N → main IN; main L OUT → ავტომატი IN
        connect(&board, "supply.L", "main.Lin", csa: csa, cable: cable, lengthM: 0)
        connect(&board, "supply.N", "main.Nin", csa: csa, cable: cable, lengthM: 0)
        connect(&board, "main.Lout", port(mcb, "in"), csa: csa, cable: cable, lengthM: 0)

        // ავტომატი OUT → თითო დატვირთვის L; main N OUT → თითო N; supply PE → თითო PE.
        // ცხელი/ნული/PE სადენებს ერთი და იგივე ტრასის სიგრძე აქვთ (გვერდიგვერდ მიდის).
        let mcbOut = port(mcb, "out")
        for load in loadComponents {
            if let lL = portOf(load, .L) {
                connect(&board, mcbOut, lL, csa: csa, cable: cable, lengthM: runM)
            }
            if let lN = portOf(load, .N) {
                connect(&board, "main.Nout", lN, csa: csa, cable: cable, lengthM: runM)
            }
            if let lPE = portOf(load, .PE) {
                connect(&board, "supply.PE", lPE, csa: csa, cable: cable, lengthM: runM)
            }
        }
        return board
    }

    // MARK: helpers

    private static func makeLoad(_ lp: LoadPoint,
                                 templates: [String: ComponentTemplate]) -> Component {
        if let t = templates[lp.templateId] {
            return t.makeComponent(instanceID: lp.id, phase: .single)
        }
        // fallback — ცნობილი kind-ებისთვის
        switch lp.kind {
        case .lamp:   return ComponentFactory.lamp(id: lp.id)
        case .socket: return ComponentFactory.socket(id: lp.id)
        default:
            return ComponentFactory.appliance(id: lp.id, kind: lp.kind,
                                              name: lp.kind.rawValue, powerW: 2000)
        }
    }

    private static func port(_ comp: Component, _ suffix: String) -> String {
        "\(comp.id).\(suffix)"
    }

    /// დატვირთვის ფეხის id მოცემული გამტარისთვის (loads-ს single-side L/N/PE აქვს).
    private static func portOf(_ comp: Component, _ conductor: Conductor) -> String? {
        comp.ports.first { $0.conductor == conductor }?.id
    }

    private static func connect(_ board: inout Board, _ a: String, _ b: String,
                                csa: Double, cable: CableType, lengthM: Double) {
        // გამტარის ფერი ცხელ/ნულ/PE-ს მიხედვით — solver-ისთვის უმნიშვნელო, UI-სთვის სწორი.
        let conductor = board.port(a)?.conductor ?? board.port(b)?.conductor ?? .L
        board.connect(a, b, csaMm2: csa, color: WireColor.standard(for: conductor),
                      cableType: cable, lengthM: lengthM, tightened: true)
    }
}
