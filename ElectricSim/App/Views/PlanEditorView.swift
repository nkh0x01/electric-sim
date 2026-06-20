//
//  PlanEditorView.swift
//  ElectricSim
//
//  მონტაჟის დიზაინერი (Floor Plan / Installation Designer) — Phase 1 UI.
//  ერთი ოთახი ბადეზე, დატვირთვების განთავსება, ერთი კაბელის ტრასა, შემოწმება.
//  იგივე SwiftUI ხელსაწყოები რაც WorkbenchView-ში: ZStack / .position / Path /
//  ჟესტები. ვალიდაცია — ProjectCompiler → არსებული CircuitSolver.
//

import SwiftUI

// MARK: - დემო კატალოგი (Phase 1: ერთი პროექტი)

/// მსუბუქი „დონის" გარსი მონტაჟის პროექტისთვის — კამპანიის/გეთინგის UI-ში ჩასმისთვის.
struct PlanLevel: Identifiable {
    let id: String
    let title: String
    let brief: String
    let project: InstallationProject
}

enum PlanCatalog {
    /// ერთი დემო — საცხოვრებელი ოთახის განათების წრედი (წინასწარ აწყობილი).
    static let demo: PlanLevel = {
        let loads = [
            LoadPoint(id: "lamp_a", templateId: "lamp_60", kind: .lamp, at: GridPoint(5, 2)),
            LoadPoint(id: "lamp_b", templateId: "lamp_60", kind: .lamp, at: GridPoint(8, 2)),
            LoadPoint(id: "lamp_c", templateId: "lamp_60", kind: .lamp, at: GridPoint(11, 2))
        ]
        let run = [GridPoint(1, 6), GridPoint(1, 2), GridPoint(5, 2),
                   GridPoint(8, 2), GridPoint(11, 2)]
        let circuit = PlanCircuit(id: "c_light", name: "განათება", kind: .lighting,
                                  loadIDs: ["lamp_a", "lamp_b", "lamp_c"], run: run,
                                  csaMm2: 1.5, breakerRatingA: 10, breakerCurve: .B)
        let room = PlanRoom(id: "living", name: "მისაღები", origin: GridPoint(0, 0),
                            width: 15, height: 9)
        let project = InstallationProject(
            id: "plan_demo_living", title: "მისაღების განათება",
            grid: GridSpec(cols: 16, rows: 10, cellMeters: 0.5),
            room: room, panelAt: GridPoint(1, 6), loads: loads, circuit: circuit)
        return PlanLevel(id: "plan_demo_living", title: "მისაღების განათება",
                         brief: "განათავსე ნათურები, გაიყვანე ერთი წრედი ფარამდე და შეამოწმე IEC-ზე.",
                         project: project)
    }()

    static func level(byID id: String) -> PlanLevel? { id == demo.id ? demo : nil }
}

// MARK: - სია (კამპანიის UI-ში ჩასმა)

struct PlanListView: View {
    @Binding var path: [String]

    var body: some View {
        List {
            Section {
                Button { path.append("plan:\(PlanCatalog.demo.id)") } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "house.fill").font(.title2)
                            .foregroundStyle(Color.brand).frame(width: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PlanCatalog.demo.title).font(.headline)
                            Text(PlanCatalog.demo.brief).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("plan-lvl_\(PlanCatalog.demo.id)")
            } header: {
                Text("მონტაჟის პროექტები")
            } footer: {
                Text("Phase 1 — ერთი ოთახი, ერთი წრედი. შემდეგ ფაზებში: მრავალი წრედი, კედლები, ფარზე გადატანა.")
            }
        }
        .navigationTitle("მონტაჟის დიზაინერი")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - რედაქტორი

private enum PlanTool: String, CaseIterable {
    case placeLoad, run
    var label: String { self == .placeLoad ? "დატვირთვა" : "ტრასა" }
}

/// შედეგის გასახსნელი ყუთი — `.sheet(item:)`-ისთვის (stale nil result-ის თავიდან
/// ასაცილებლად, რაც `.sheet(isPresented:)`-თან ხდებოდა).
private struct PlanResultBox: Identifiable {
    let id = UUID()
    let result: SimulationResult
}

/// დატვირთვის ხელმისაწვდომი ტიპები (Phase 1 პალიტრა).
private struct LoadOption: Identifiable {
    let id: String          // templateId
    let kind: ComponentKind
    let title: String
    let symbol: String
}

struct PlanEditorView: View {
    @EnvironmentObject var game: GameState
    @Binding var path: [String]

    @State private var project: InstallationProject
    @State private var tool: PlanTool = .placeLoad
    @State private var selectedLoad: String
    @State private var loadSeq = 0
    @State private var presented: PlanResultBox?

    private let palette: [LoadOption] = [
        LoadOption(id: "lamp_60",     kind: .lamp,           title: "ნათურა",      symbol: "lightbulb.fill"),
        LoadOption(id: "led_panel",   kind: .lamp,           title: "LED პანელი",  symbol: "rectangle.fill"),
        LoadOption(id: "socket_16",   kind: .socket,         title: "როზეტი",      symbol: "poweroutlet.type.f.fill"),
        LoadOption(id: "heater_2000", kind: .heater,         title: "გამახურებელი", symbol: "heater.vertical.fill")
    ]

    init(level: PlanLevel, path: Binding<[String]>) {
        _project = State(initialValue: level.project)
        _path = path
        _selectedLoad = State(initialValue: "lamp_60")
    }

    var body: some View {
        VStack(spacing: 0) {
            planCanvas
            controls
        }
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presented) { box in resultSheet(box.result) }
    }

    // MARK: ტილო (canvas)

    private var planCanvas: some View {
        GeometryReader { geo in
            let cell = floor(min(geo.size.width / CGFloat(project.grid.cols),
                                 geo.size.height / CGFloat(project.grid.rows)))
            let w = cell * CGFloat(project.grid.cols)
            let h = cell * CGFloat(project.grid.rows)
            ZStack(alignment: .topLeading) {
                gridLines(cell: cell, w: w, h: h)
                roomShape(cell: cell)
                runPath(cell: cell)
                panelMarker(cell: cell)
                ForEach(project.loads) { lp in loadIcon(lp, cell: cell) }
            }
            .frame(width: w, height: h)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture(coordinateSpace: .local).onEnded { v in
                handleTap(v.location, cell: cell)
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Color(.systemBackground))
        }
    }

    private func gridLines(cell: CGFloat, w: CGFloat, h: CGFloat) -> some View {
        Path { p in
            for c in 0...project.grid.cols {
                let x = CGFloat(c) * cell
                p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h))
            }
            for r in 0...project.grid.rows {
                let y = CGFloat(r) * cell
                p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
            }
        }
        .stroke(Color.gray.opacity(0.18), lineWidth: 0.5)
    }

    private func roomShape(cell: CGFloat) -> some View {
        let r = project.room
        return RoundedRectangle(cornerRadius: 4)
            .stroke(Color.brown.opacity(0.8), lineWidth: 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.brown.opacity(0.05)))
            .frame(width: CGFloat(r.width) * cell, height: CGFloat(r.height) * cell)
            .offset(x: CGFloat(r.origin.x) * cell, y: CGFloat(r.origin.y) * cell)
            .overlay(alignment: .topLeading) {
                Text(r.name).font(.caption2).foregroundStyle(.secondary)
                    .padding(2)
                    .offset(x: CGFloat(r.origin.x) * cell + 4, y: CGFloat(r.origin.y) * cell + 2)
            }
            .accessibilityElement()
            .accessibilityIdentifier("plan-room")
    }

    private func runPath(cell: CGFloat) -> some View {
        Path { p in
            let pts = project.circuit.run
            guard let first = pts.first else { return }
            p.move(to: center(first, cell: cell))
            for pt in pts.dropFirst() { p.addLine(to: center(pt, cell: cell)) }
        }
        .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        .accessibilityElement()
        .accessibilityIdentifier("plan-run")
    }

    private func panelMarker(cell: CGFloat) -> some View {
        let c = center(project.panelAt, cell: cell)
        return RoundedRectangle(cornerRadius: 3)
            .fill(Color.purple)
            .frame(width: cell * 0.7, height: cell * 0.7)
            .overlay(Image(systemName: "square.grid.2x2.fill").font(.system(size: cell * 0.32))
                .foregroundStyle(.white))
            .position(c)
            .accessibilityElement()
            .accessibilityIdentifier("plan-panel")
    }

    private func loadIcon(_ lp: LoadPoint, cell: CGFloat) -> some View {
        let sym = palette.first { $0.id == lp.templateId }?.symbol ?? "bolt.fill"
        return Circle()
            .fill(Color.yellow.opacity(0.9))
            .frame(width: cell * 0.8, height: cell * 0.8)
            .overlay(Image(systemName: sym).font(.system(size: cell * 0.4)).foregroundStyle(.black))
            .overlay(Circle().stroke(Color.orange, lineWidth: 1.5))
            .position(center(lp.at, cell: cell))
            .accessibilityElement()
            .accessibilityIdentifier("plan-load-\(lp.id)")
    }

    private func center(_ p: GridPoint, cell: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(p.x) + 0.5) * cell, y: (CGFloat(p.y) + 0.5) * cell)
    }

    // MARK: ჟესტი — განთავსება / ტრასა

    private func handleTap(_ loc: CGPoint, cell: CGFloat) {
        let gx = max(0, min(project.grid.cols - 1, Int(loc.x / cell)))
        let gy = max(0, min(project.grid.rows - 1, Int(loc.y / cell)))
        let cellPt = GridPoint(gx, gy)
        switch tool {
        case .placeLoad:
            loadSeq += 1
            let opt = palette.first { $0.id == selectedLoad } ?? palette[0]
            let lp = LoadPoint(id: "u\(loadSeq)", templateId: opt.id, kind: opt.kind, at: cellPt)
            project.loads.append(lp)
            project.circuit.loadIDs.append(lp.id)
        case .run:
            project.circuit.run.append(cellPt)
        }
    }

    // MARK: მართვის ზოლი

    private var controls: some View {
        VStack(spacing: 8) {
            Picker("ხელსაწყო", selection: $tool) {
                ForEach(PlanTool.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("plan-tool")

            if tool == .placeLoad {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(palette) { opt in
                            Button { selectedLoad = opt.id } label: {
                                VStack(spacing: 2) {
                                    Image(systemName: opt.symbol).font(.title3)
                                    Text(opt.title).font(.caption2)
                                }
                                .padding(8)
                                .frame(minWidth: 64)
                                .background(selectedLoad == opt.id ? Color.brand.opacity(0.2) : Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("plan-loadtype-\(opt.id)")
                        }
                    }.padding(.horizontal)
                }
            } else {
                Text("შეეხე ბადეს — ტრასა ფარიდან დატვირთვებამდე გაიწელება.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            Button { validate() } label: {
                Label("შემოწმება (IEC)", systemImage: "checkmark.seal.fill")
                    .frame(maxWidth: .infinity).font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brand)
            .padding(.horizontal)
            .accessibilityIdentifier("plan-validate")
        }
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: ვალიდაცია — ProjectCompiler → არსებული solver

    private func validate() {
        let board = ProjectCompiler.board(from: project, templates: game.templates)
        presented = PlanResultBox(result: CircuitSolver().solve(board, energize: true))
    }

    private func resultSheet(_ result: SimulationResult) -> some View {
        let loadSum = project.loadSumW(templates: game.templates)
        let current = PlanSizing.currentA(loadSumW: loadSum, phase: project.phase)
        let needBreaker = PlanSizing.requiredBreaker(forLoadSumW: loadSum, phase: project.phase)
        let needCSA = PlanSizing.minCSA(forBreaker: project.circuit.breakerRatingA, cable: project.circuit.cableType)
        let runM = project.runLengthM()
        let dropPct = VoltageDrop.percent(currentA: current, lengthM: runM,
                                          csaMm2: project.circuit.csaMm2,
                                          cable: project.circuit.cableType,
                                          threePhase: project.phase == .three)
        let dropLimit = VoltageDrop.limitPct(for: project.circuit.kind == .lighting ? .lamp : .socket)
        let passed = result.passed

        return NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: passed ? "checkmark.seal.fill" : "xmark.octagon.fill")
                            .foregroundStyle(passed ? .green : .red).font(.title)
                        Text(passed ? "წრედი ვალიდურია" : "წრედი ვერ გავიდა")
                            .font(.headline)
                            .accessibilityIdentifier("plan-verdict")
                            .accessibilityValue(passed ? "pass" : "fail")
                    }
                }
                Section("დაზომვა") {
                    row("ჯამური სიმძლავრე", String(format: "%.0f W", loadSum))
                    row("გამოთვლილი დენი", String(format: "%.1f A", current))
                    row("საჭირო ავტომატი", needBreaker.map { String(format: "%.0f A", $0) } ?? "—")
                    row("არჩეული ავტომატი", String(format: "%.0f A", project.circuit.breakerRatingA))
                    row("საჭირო კვეთა", needCSA.map { csaText($0) } ?? "—")
                    row("არჩეული კვეთა", csaText(project.circuit.csaMm2))
                    row("ტრასის სიგრძე", String(format: "%.1f მ", runM))
                    row("ძაბვის ვარდნა", String(format: "%.2f%% (ზღვ. %.0f%%)", dropPct, dropLimit),
                        warn: dropPct > dropLimit)
                }
                if !result.issues.isEmpty {
                    Section("შენიშვნები") {
                        ForEach(result.issues) { issue in
                            Label(issue.message,
                                  systemImage: issue.severity == .error ? "xmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(issue.severity == .error ? .red : .orange)
                        }
                    }
                }
            }
            .navigationTitle("შემოწმება")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("დახურვა") { presented = nil }
                }
            }
        }
    }

    private func row(_ k: String, _ v: String, warn: Bool = false) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).foregroundStyle(warn ? .red : .primary).fontWeight(warn ? .semibold : .regular)
        }
        .font(.subheadline)
    }

    private func csaText(_ csa: Double) -> String {
        let s = csa.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(csa)) : String(format: "%.1f", csa)
        return "\(s) მმ²"
    }
}
