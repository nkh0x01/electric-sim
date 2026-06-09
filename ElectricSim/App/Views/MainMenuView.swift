//
//  MainMenuView.swift
//  ElectricSim
//
//  ახალი root — სამი თანაბარი რეჟიმი: სწავლება / კარიერა / Sandbox.
//

import SwiftUI

struct MainMenuView: View {
    @Binding var path: [String]

    var body: some View {
        List {
            Section {
                modeRow(route: "learn", title: "სწავლება",
                        subtitle: "გაკვეთილები და სავარჯიშო დონეები",
                        systemImage: "graduationcap.fill", color: .brand,
                        id: "menu-learn")
                modeRow(route: "career", title: "კარიერა",
                        subtitle: "შეასრულე სამუშაოები, აიწიე წოდებაში",
                        systemImage: "briefcase.fill", color: .orange,
                        id: "menu-career")
                modeRow(route: "sandbox", title: "Sandbox",
                        subtitle: "თავისუფალი აწყობა შეზღუდვის გარეშე",
                        systemImage: "hammer.fill", color: .blue,
                        id: "menu-sandbox")
            } header: {
                Text("აირჩიე რეჟიმი")
            }

            // ტექსტური კრედიტი (ბმულის გარეშე — არ არის რეკლამა). ბმულები მხოლოდ „შესახებ“-ში.
            Section {
                Text("შექმნილია Gadget-ის მიერ · სპონსორი Tsili.ge")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("ელექტრიკოსის სიმულატორი")
        .navigationBarTitleDisplayMode(.large)
    }

    private func modeRow(route: String, title: String, subtitle: String,
                         systemImage: String, color: Color, id: String) -> some View {
        Button { path.append(route) } label: {
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
