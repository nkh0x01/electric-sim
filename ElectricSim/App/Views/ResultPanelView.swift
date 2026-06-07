//
//  ResultPanelView.swift
//  ElectricSim
//
//  სიმულაციის შედეგის პანელი — ქართული ახსნით.
//

import SwiftUI

struct ResultPanelView: View {
    let result: SimulationResult
    let passed: Bool
    let level: Level
    var hasNext: Bool = false
    var onNext: (() -> Void)?
    var onBackToMenu: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: headerIcon)
                            .font(.largeTitle)
                            .foregroundStyle(headerColor)
                        VStack(alignment: .leading) {
                            Text(headerTitle).font(.headline)
                            Text(headerSubtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                if !result.loadStates.isEmpty {
                    Section("დატვირთვები") {
                        ForEach(result.loadStates) { st in
                            HStack {
                                Image(systemName: st.isPowered ? "lightbulb.fill" : (st.trip != nil ? "bolt.slash.fill" : "lightbulb"))
                                    .foregroundStyle(st.isPowered ? .yellow : (st.trip != nil ? .red : .secondary))
                                VStack(alignment: .leading) {
                                    Text(st.id).font(.subheadline)
                                    if let trip = st.trip {
                                        Text(trip.georgian).font(.caption).foregroundStyle(.red)
                                    } else if st.shockRisk {
                                        Text("⚠️ შოკის რისკი").font(.caption).foregroundStyle(.orange)
                                    } else if st.isPowered {
                                        Text("მუშაობს — \(st.currentA, specifier: "%.2f") A")
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else {
                                        Text("არ მუშაობს").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                }

                if passed {
                    Section {
                        Button {
                            if hasNext { onNext?() } else { onBackToMenu?() }
                        } label: {
                            Label(hasNext ? "next_level" : "back_to_menu",
                                  systemImage: hasNext ? "arrow.right.circle.fill" : "house.fill")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.brand)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                if result.issues.isEmpty {
                    Section {
                        Label("შენიშვნები არ არის — სუფთა მონტაჟი!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Section("შენიშვნები და ახსნა") {
                        ForEach(result.issues) { issue in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: issue.severity.icon)
                                    .foregroundStyle(issue.severity.color)
                                Text(issue.message)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("შედეგი")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("დახურვა") { dismiss() }
                }
            }
        }
    }

    private var headerIcon: String {
        if passed { return "trophy.fill" }
        return result.passed ? "checkmark.circle.fill" : "xmark.octagon.fill"
    }
    private var headerColor: Color {
        if passed { return .yellow }
        return result.passed ? .green : .red
    }
    private var headerTitle: String {
        if passed { return "დონე დასრულდა! 🎉" }
        return result.passed ? "ვალიდაცია წარმატებით გაიარა" : "ნაპოვნია შეცდომები"
    }
    private var headerSubtitle: String {
        if passed { return level.goal.description }
        return result.passed
            ? "მონტაჟი სწორია. დარწმუნდი რომ ყველა საჭირო დატვირთვა აანთდა."
            : "\(result.errors.count) შეცდომა, \(result.warnings.count) გაფრთხილება. ნახე ახსნა ქვემოთ."
    }
}
