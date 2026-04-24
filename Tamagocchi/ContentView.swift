//
//  ContentView.swift
//  Tamagocchi
//
//  Created by Marcus Chang on 2026/04/18.
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct ContentView: View {
    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    @State private var authorizationMessage: String?
    @State private var selection = FamilyActivitySelection()
    @State private var isPresented = false
    @State private var selectionMessage = "No activity selected yet."
    @State private var reportContext: DeviceActivityReport.Context = .summary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Screen Time Access")
                    .font(.title2.bold())

                Text("Status: \(authorizationStatusText)")
                    .font(.headline)

                if let authorizationMessage {
                    Text(authorizationMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Request Access") {
                    Task {
                        await requestScreenTimeAccess()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Present FamilyActivityPicker") {
                    isPresented = true
                }
                .familyActivityPicker(isPresented: $isPresented, selection: $selection)

                Text(selectionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Report selection")
                        .font(.headline)

                    Text("Apps: \(selection.applicationTokens.count)  Categories: \(selection.categoryTokens.count)  Web domains: \(selection.webDomainTokens.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                reportSection

                VStack(alignment: .leading, spacing: 8) {
                    selectionSectionTitle("Applications")
                    if selection.applicationTokens.isEmpty {
                        Text("No apps selected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    selectionSectionTitle("Categories")
                    if selection.categoryTokens.isEmpty {
                        Text("No categories selected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    selectionSectionTitle("Web Domains")
                    if selection.webDomainTokens.isEmpty {
                        Text("No web domains selected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                            Label(token)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        .onChange(of: selection) { _, newSelection in
            selectionMessage = "Selected \(newSelection.applicationTokens.count) apps, \(newSelection.categoryTokens.count) categories, and \(newSelection.webDomainTokens.count) web domains."
        }
    }

    private var authorizationStatusText: String {
        switch authorizationCenter.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .approved:
            return "Approved"
        @unknown default:
            return "Unknown"
        }
    }

    @MainActor
    private func requestScreenTimeAccess() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationMessage = "Authorization request completed."
        } catch {
            authorizationMessage = "Authorization failed: \(error.localizedDescription)"
        }
    }

    private var reportFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? Date().addingTimeInterval(86_400)
        let interval = DateInterval(start: today, end: tomorrow)

        return DeviceActivityFilter(
            segment: .daily(during: interval),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens
        )
    }

    @ViewBuilder
    private var reportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            selectionSectionTitle("Device Activity Report")

            DeviceActivityReport(reportContext, filter: reportFilter)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.secondary.opacity(0.2), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func selectionSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
    }
}

extension DeviceActivityReport.Context {
    static let summary = Self("summary")
}

#Preview {
    ContentView()
}
