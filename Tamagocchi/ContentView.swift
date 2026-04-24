//
//  ContentView.swift
//  Tamagocchi
//
//  Created by Marcus Chang on 2026/04/18.
//

import DeviceActivity
import FamilyControls
import SwiftUI

struct ContentView: View {
    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    @State private var authorizationMessage = "No authorization request yet."
    @State private var selection = FamilyActivitySelection()
    @State private var isPresented = false
    @State private var selectionMessage = "No activity selected yet."
    @State private var showReport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tamagocchi Debug")

            Text("Authorization Status: \(authorizationStatusText)")
            Text("Authorization Message: \(authorizationMessage)")
            Text("Selection Message: \(selectionMessage)")
            Text("Selected Apps: \(selection.applicationTokens.count)")
            Text("Selected Categories: \(selection.categoryTokens.count)")
            Text("Selected Web Domains: \(selection.webDomainTokens.count)")
            Text("Show Report: \(showReport ? \"true\" : \"false\")")

            Button("Request Screen Time Access") {
                Task {
                    await requestScreenTimeAccess()
                }
            }

            Button("Open Family Activity Picker") {
                isPresented = true
            }
            .familyActivityPicker(isPresented: $isPresented, selection: $selection)

            Button("Toggle Report") {
                showReport.toggle()
            }

            if showReport {
                Text("Report Context: summary")
                DeviceActivityReport(reportContext, filter: reportFilter)
                    .frame(height: 280)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
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

    fileprivate var reportContext: DeviceActivityReport.Context {
        .summary
    }

    fileprivate var reportFilter: DeviceActivityFilter {
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
}

extension DeviceActivityReport.Context {
    static let summary = Self("summary")
}

#Preview {
    ContentView()
}
