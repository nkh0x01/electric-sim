//
//  FaultBoardView.swift
//  ElectricSim
//
//  დეფექტის-ძებნის რეჟიმში ფარის read-only ჩვენება (zoom/pan), ComponentCardView-ისა
//  და PortFrameKey-ის ხელახალი გამოყენებით. რედაქტირება არ ხდება (მხოლოდ დათვალიერება).
//

import SwiftUI

struct FaultBoardView: View {
    let board: Board
    let result: SimulationResult?

    @State private var portPoints: [String: CGPoint] = [:]
    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinch: CGFloat = 1.0
    @State private var pan: CGSize = .zero
    @GestureState private var panLive: CGSize = .zero

    private let cardsPerRow = 4
    private var rows: [[Component]] {
        let c = board.components
        return stride(from: 0, to: c.count, by: cardsPerRow).map {
            Array(c[$0 ..< min($0 + cardsPerRow, c.count)])
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemBackground)
            content
                .scaleEffect(zoom * pinch, anchor: .topLeading)
                .offset(x: pan.width + panLive.width, y: pan.height + panLive.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .clipped()
        .simultaneousGesture(
            DragGesture()
                .updating($panLive) { v, s, _ in s = v.translation }
                .onEnded { v in pan.width += v.translation.width; pan.height += v.translation.height }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .updating($pinch) { v, s, _ in s = v }
                .onEnded { v in zoom = min(max(zoom * v, 0.3), 3.0) }
        )
        .overlay(alignment: .bottomTrailing) { zoomControls }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(alignment: .top, spacing: 28) {
                    ForEach(rows[r]) { comp in
                        ComponentCardView(
                            component: comp,
                            selectedPort: nil,
                            loadState: result?.state(for: comp.id),
                            isSelected: false,
                            isLive: { _ in false },
                            onTapPort: { _ in },
                            onLongPress: {},
                            onDelete: nil
                        )
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.10))
                        .overlay(alignment: .center) {
                            Rectangle().fill(Color.gray.opacity(0.28)).frame(height: 3)
                        }
                )
            }
        }
        .padding(40)
        .coordinateSpace(name: kBoardSpace)
        .overlay { wireOverlay }
        .onPreferenceChange(PortFrameKey.self) { portPoints = $0 }
    }

    private var wireOverlay: some View {
        ZStack {
            ForEach(board.wires) { wire in
                if let a = portPoints[wire.fromPortID], let b = portPoints[wire.toPortID] {
                    Path { p in p.move(to: a); p.addLine(to: b) }
                        .stroke(wire.color.swiftUIColor,
                                style: StrokeStyle(lineWidth: wire.conductorType == .stranded ? 5 : 4,
                                                   lineCap: .round,
                                                   dash: wire.conductorType == .stranded ? [5, 3] : []))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var zoomControls: some View {
        VStack(spacing: 6) {
            zoomButton("plus.magnifyingglass") { zoom = min(zoom + 0.2, 3.0) }
            zoomButton("minus.magnifyingglass") { zoom = max(zoom - 0.2, 0.3) }
            zoomButton("scope") { zoom = 1.0; pan = .zero }
        }
        .padding(8)
    }

    private func zoomButton(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.title3)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.25)))
        }
    }
}
