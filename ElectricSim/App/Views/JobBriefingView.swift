//
//  JobBriefingView.swift
//  ElectricSim
//
//  Career — სამუშაოს ბრიფინგი: კლიენტი, ლოკაცია, აღწერა, საჭირო კომპონენტები,
//  ჯილდო. „დაიწყე“ ხსნის workbench-ს.
//

import SwiftUI

struct JobBriefingView: View {
    @EnvironmentObject var game: GameState
    @EnvironmentObject var store: EntitlementStore
    let jobID: String
    @Binding var path: [String]
    @State private var showPaywall = false

    private var job: Job? { game.job(byID: jobID) }

    var body: some View {
        Group {
            if let job {
                List {
                    Section("დამკვეთი") {
                        labeled("კლიენტი", job.customerName)
                        labeled("ლოკაცია", job.location)
                    }
                    Section("დავალება") {
                        Text(job.jobBrief).font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                    Section("საჭირო კომპონენტები") {
                        ForEach(job.requiredComponents, id: \.self) { id in
                            Label(game.template(id)?.name ?? id, systemImage: "shippingbox")
                                .font(.callout)
                        }
                    }
                    Section("ჯილდო") {
                        Label("\(job.xpReward) XP", systemImage: "star.fill").foregroundStyle(.orange)
                        Label("\(job.cashReward) ₾", systemImage: "banknote").foregroundStyle(.green)
                    }
                    Section {
                        Button {
                            start(job)
                        } label: {
                            Label("დაიწყე", systemImage: "play.fill")
                                .frame(maxWidth: .infinity).font(.headline)
                        }
                        .buttonStyle(.borderedProminent).tint(.brand)
                        .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                        .accessibilityIdentifier("job-start")
                    }
                }
                .navigationTitle(job.georgianTitle)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Text("სამუშაო ვერ მოიძებნა.").foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView().environmentObject(store) }
    }

    private func start(_ job: Job) {
        if game.career.isProLocked(job, isPro: store.isPro) { showPaywall = true; return }
        // ბრიფინგს ვანაცვლებთ workbench-ით (უკან → დაფა).
        if path.isEmpty { path = ["jobwork:\(job.id)"] }
        else { path[path.count - 1] = "jobwork:\(job.id)" }
    }

    private func labeled(_ k: String, _ v: String) -> some View {
        HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v) }
            .font(.callout)
    }
}
