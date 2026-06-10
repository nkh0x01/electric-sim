//
//  MainMenuView.swift
//  ElectricSim
//
//  ახალი root — სამი თანაბარი რეჟიმი: სწავლება / კარიერა / Sandbox.
//

import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var store: EntitlementStore
    @EnvironmentObject var game: GameState
    @Binding var path: [String]
    @State private var showSettings = false
    @State private var showAbout = false

    var body: some View {
        List {
            Section {
                modeRow(title: "სწავლება",
                        subtitle: "გაკვეთილები და სავარჯიშო დონეები",
                        systemImage: "graduationcap.fill", color: .brand,
                        id: "menu-learn") { path.append("learn") }
                modeRow(title: "კარიერა",
                        subtitle: "შეასრულე სამუშაოები, აიწიე წოდებაში",
                        systemImage: "briefcase.fill", color: .orange,
                        id: "menu-career") { path.append("career") }
                modeRow(title: "დიაგნოსტიკა",
                        subtitle: "იპოვე და გაასწორე დეფექტი აწყობილ ფარში",
                        systemImage: "stethoscope", color: .red,
                        id: "menu-faults") { path.append("faults") }
                modeRow(title: "Sandbox",
                        subtitle: "თავისუფალი აწყობა შეზღუდვის გარეშე",
                        systemImage: "hammer.fill", color: .blue,
                        id: "menu-sandbox") { path.append("sandbox") }
            } header: {
                Text("აირჩიე რეჟიმი")
            }

            // პარამეტრები და „ჩვენ შესახებ“ — პირდაპირ მენიუში (არა მხოლოდ ⚙️-ში),
            // იგივე სტილით როგორც რეჟიმის რიგები.
            Section {
                modeRow(title: "პარამეტრები",
                        subtitle: "ხმა, შესყიდვები, პროგრესი",
                        systemImage: "gearshape.fill", color: .gray,
                        id: "menu-settings") { showSettings = true }
                modeRow(title: "ჩვენ შესახებ",
                        subtitle: "აპლიკაცია, ბრენდი და ბმულები",
                        systemImage: "info.circle.fill", color: .teal,
                        id: "menu-about") { showAbout = true }
            }

            // ტექსტური კრედიტი (ბმულის გარეშე — არ არის რეკლამა). ბმულები მხოლოდ „შესახებ“-ში.
            Section {
                Text("Tsili.ge — იყიდე ქართული წარმოება")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("ელექტრიკოსის სიმულატორი")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityIdentifier("settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(store).environmentObject(game)
        }
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AboutView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("დახურვა") { showAbout = false }
                        }
                    }
            }
        }
    }

    private func modeRow(title: String, subtitle: String,
                         systemImage: String, color: Color, id: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
