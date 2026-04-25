//
//  ContentView.swift
//  Tamagocchi
//
//  Created by Marcus Chang on 2026/04/18.
//

import DeviceActivity
import FamilyControls
import HealthKit
import WidgetKit
import SwiftUI

private let lifeformAppGroupID = "group.com.marcus.Growmi"
private let lifeformWidgetStateKey = "LifeformWidgetState"

enum GrowmiTheme {
    static let backgroundTop = Color(red: 0.97, green: 0.96, blue: 0.92)
    static let backgroundBottom = Color(red: 0.90, green: 0.95, blue: 0.94)
    static let card = Color.white.opacity(0.78)
    static let primaryGreen = Color(red: 0.34, green: 0.62, blue: 0.47)
    static let accentGreen = Color(red: 0.63, green: 0.82, blue: 0.70)
    static let warmOrange = Color(red: 0.92, green: 0.72, blue: 0.50)
    static let textPrimary = Color(red: 0.12, green: 0.18, blue: 0.14)
    static let textSecondary = Color(red: 0.38, green: 0.46, blue: 0.41)
    static let debugBorder = Color(red: 0.55, green: 0.78, blue: 0.66)
}

struct ContentView: View {
    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    private let healthStore = HKHealthStore()

    @State private var authorizationMessage = "No authorization request yet."
    @State private var selection = FamilyActivitySelection()
    @State private var isPresented = false
    @State private var selectionMessage = "No activity selected yet."
    @State private var showReport = false
    @State private var stepCountMessage = "Step count not loaded yet."

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GrowmiTheme.backgroundTop, GrowmiTheme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView {
                CreaturePage(
                    stepCount: parsedStepCount,
                    selectedItemCount: selectedItemCount,
                    authorizationStatusText: authorizationStatusText,
                    stepCountMessage: stepCountMessage,
                    selectionMessage: selectionMessage,
                    physicalLevel: physicalLevel,
                    digitalPenalty: digitalPenalty,
                    physicalTag: physicalTag,
                    digitalStatusText: digitalStatusText
                )

                MetricsPage(
                    stepCount: parsedStepCount,
                    selectedItemCount: selectedItemCount,
                    authorizationStatusText: authorizationStatusText,
                    physicalLevel: physicalLevel,
                    digitalPenalty: digitalPenalty,
                    physicalTag: physicalTag,
                    digitalStatusText: digitalStatusText
                )

                DebugPage(
                    authorizationStatusText: authorizationStatusText,
                    authorizationMessage: authorizationMessage,
                    selectionMessage: selectionMessage,
                    selectedApps: selection.applicationTokens.count,
                    selectedCategories: selection.categoryTokens.count,
                    selectedWebDomains: selection.webDomainTokens.count,
                    showReport: showReport,
                    stepCountMessage: stepCountMessage,
                    isPresented: $isPresented,
                    selection: $selection,
                    requestScreenTimeAccess: {
                        Task {
                            await requestScreenTimeAccess()
                        }
                    },
                    openFamilyActivityPicker: {
                        isPresented = true
                    },
                    toggleReport: {
                        showReport.toggle()
                    },
                    loadTodaySteps: {
                        Task {
                            await loadTodayStepCount()
                        }
                    },
                    reportContext: reportContext,
                    reportFilter: reportFilter
                )
            }
            .tabViewStyle(.page)
        }
        .onChange(of: selection) { _, newSelection in
            selectionMessage = "Selected \(newSelection.applicationTokens.count) apps, \(newSelection.categoryTokens.count) categories, and \(newSelection.webDomainTokens.count) web domains."
            syncWidgetStateToWidget()
        }
        .onAppear {
            syncWidgetStateToWidget()
        }
    }

    private var selectedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private var digitalPenalty: Double {
        min(1.0, Double(selectedItemCount) / 10.0)
    }

    private var hasScreenTimeSelection: Bool {
        selectedItemCount > 0
    }

    private var isScreenTimeApproved: Bool {
        authorizationCenter.authorizationStatus == .approved
    }

    private var physicalLevel: Double {
        Double(parsedStepCount)
    }

    private var parsedStepCount: Int {
        let digits = stepCountMessage.split(whereSeparator: { !$0.isNumber })
        return digits.compactMap { Int($0) }.first ?? 0
    }

    private var physicalTag: String {
        let steps = parsedStepCount

        if steps >= 10_000 {
            return "charged"
        } else if steps >= 5_000 {
            return "awake"
        } else if steps > 0 {
            return "growing"
        } else {
            return "dormant"
        }
    }

    private var digitalStatusText: String {
        switch (isScreenTimeApproved, hasScreenTimeSelection) {
        case (true, true):
            return "influence active"
        case (true, false):
            return "authorized, unselected"
        default:
            return "screen time locked"
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
            syncWidgetStateToWidget()
        } catch {
            authorizationMessage = "Authorization failed: \(error.localizedDescription)"
            syncWidgetStateToWidget()
        }
    }

    @MainActor
    private func loadTodayStepCount() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            stepCountMessage = "Health data is not available on this device."
            return
        }

        let stepType = HKQuantityType(.stepCount)

        do {
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])

            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date().addingTimeInterval(86_400)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay)
            let samplePredicate = HKSamplePredicate.quantitySample(type: stepType, predicate: predicate)
            let query = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)

            let stepCount = try await query.result(for: healthStore)?
                .sumQuantity()?
                .doubleValue(for: .count()) ?? 0

            stepCountMessage = "\(Int(stepCount)) steps today"
            syncWidgetStateToWidget()
        } catch {
            stepCountMessage = "Failed to load steps: \(error.localizedDescription)"
            syncWidgetStateToWidget()
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

    private func syncWidgetStateToWidget() {
        let widgetState = LifeformWidgetStateSnapshot(
            authorizationStatusText: authorizationStatusText,
            authorizationMessage: authorizationMessage,
            selectionMessage: selectionMessage,
            selectedApps: selection.applicationTokens.count,
            selectedCategories: selection.categoryTokens.count,
            selectedWebDomains: selection.webDomainTokens.count,
            stepCount: parsedStepCount,
            showReport: showReport
        )

        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
              let data = try? JSONEncoder().encode(widgetState) else {
            return
        }

        defaults.set(data, forKey: lifeformWidgetStateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct LifeformWidgetStateSnapshot: Codable {
    let authorizationStatusText: String
    let authorizationMessage: String
    let selectionMessage: String
    let selectedApps: Int
    let selectedCategories: Int
    let selectedWebDomains: Int
    let stepCount: Int
    let showReport: Bool
}

private struct CreaturePage: View {
    let stepCount: Int
    let selectedItemCount: Int
    let authorizationStatusText: String
    let stepCountMessage: String
    let selectionMessage: String
    let physicalLevel: Double
    let digitalPenalty: Double
    let physicalTag: String
    let digitalStatusText: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                PageHeader(
                    title: "Growmi",
                    subtitle: "Soft creature, quiet habits, visible state."
                )

                CreatureCard(
                    stepCount: stepCount,
                    selectedItemCount: selectedItemCount,
                    authorizationStatusText: authorizationStatusText,
                    stepCountMessage: stepCountMessage,
                    selectionMessage: selectionMessage,
                    physicalLevel: physicalLevel,
                    digitalPenalty: digitalPenalty,
                    physicalTag: physicalTag,
                    digitalStatusText: digitalStatusText
                )
                .border(GrowmiTheme.debugBorder, width: 1)

                SummaryStrip(
                    stepCount: stepCount,
                    selectedItemCount: selectedItemCount,
                    authorizationStatusText: authorizationStatusText
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct MetricsPage: View {
    let stepCount: Int
    let selectedItemCount: Int
    let authorizationStatusText: String
    let physicalLevel: Double
    let digitalPenalty: Double
    let physicalTag: String
    let digitalStatusText: String

    private var progressValue: Double {
        min(Double(stepCount) / 10_000.0, 1.0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                PageHeader(
                    title: "Today's Growth",
                    subtitle: "Movement feeds Growmi. Excess screen time strains it."
                )

                HStack(alignment: .top, spacing: 12) {
                    PhysicalGrowthCard(progressValue: progressValue, stepCount: stepCount)
                        .border(GrowmiTheme.debugBorder, width: 1)

                    DigitalStrainCard(digitalPenalty: digitalPenalty)
                        .border(GrowmiTheme.debugBorder, width: 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    MetricRow(title: "Steps", value: "\(stepCount)")
                    MetricRow(title: "Selected Items", value: "\(selectedItemCount)")
                    MetricRow(title: "Authorization", value: authorizationStatusText)
                    MetricRow(title: "Physical Tag", value: physicalTag)
                    MetricRow(title: "Digital Status", value: digitalStatusText)
                }
                .border(GrowmiTheme.debugBorder, width: 1)

                Text("Movement feeds Growmi. Excess screen time strains it.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct DebugPage: View {
    let authorizationStatusText: String
    let authorizationMessage: String
    let selectionMessage: String
    let selectedApps: Int
    let selectedCategories: Int
    let selectedWebDomains: Int
    let showReport: Bool
    let stepCountMessage: String
    @Binding var isPresented: Bool
    @Binding var selection: FamilyActivitySelection
    let requestScreenTimeAccess: () -> Void
    let openFamilyActivityPicker: () -> Void
    let toggleReport: () -> Void
    let loadTodaySteps: () -> Void
    let reportContext: DeviceActivityReport.Context
    let reportFilter: DeviceActivityFilter

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                PageHeader(
                    title: "Debug",
                    subtitle: "Backend wiring stays visible while you iterate."
                )

                ActionPanel(
                    requestScreenTimeAccess: requestScreenTimeAccess,
                    openFamilyActivityPicker: openFamilyActivityPicker,
                    toggleReport: toggleReport,
                    loadTodaySteps: loadTodaySteps,
                    isPresented: $isPresented,
                    selection: $selection,
                    showReport: showReport
                )
                .border(GrowmiTheme.debugBorder, width: 1)

                DebugStatusPanel(
                    authorizationStatusText: authorizationStatusText,
                    authorizationMessage: authorizationMessage,
                    selectionMessage: selectionMessage,
                    selectedApps: selectedApps,
                    selectedCategories: selectedCategories,
                    selectedWebDomains: selectedWebDomains,
                    showReport: showReport,
                    stepCountMessage: stepCountMessage
                )
                .border(GrowmiTheme.debugBorder, width: 1)

                if showReport {
                    ReportSection(
                        authorizationStatusText: authorizationStatusText,
                        selectionMessage: selectionMessage,
                        physicalTag: "debug",
                        reportContext: reportContext,
                        reportFilter: reportFilter
                    )
                    .border(GrowmiTheme.debugBorder, width: 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
}

private struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(GrowmiTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SummaryStrip: View {
    let stepCount: Int
    let selectedItemCount: Int
    let authorizationStatusText: String

    var body: some View {
        HStack(spacing: 12) {
            MetricChip(title: "Steps", value: "\(stepCount)")
            MetricChip(title: "Selection", value: "\(selectedItemCount)")
            MetricChip(title: "Auth", value: authorizationStatusText)
        }
    }
}

private struct MetricChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textSecondary)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CreatureCard: View {
    let stepCount: Int
    let selectedItemCount: Int
    let authorizationStatusText: String
    let stepCountMessage: String
    let selectionMessage: String
    let physicalLevel: Double
    let digitalPenalty: Double
    let physicalTag: String
    let digitalStatusText: String

    private var creatureScale: CGFloat {
        1.0 + CGFloat(min(max(physicalLevel / 10_000.0, 0), 1)) * 0.14
    }

    private var brightness: Double {
        1.0 - (digitalPenalty * 0.12)
    }

    private var saturation: Double {
        1.0 - (digitalPenalty * 0.45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Specimen Growmi")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)

                Text(moodText)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.primaryGreen)
            }

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.90, green: 0.96, blue: 0.99),
                        Color(red: 0.85, green: 0.94, blue: 0.90),
                        Color(red: 0.75, green: 0.88, blue: 0.80)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.56, green: 0.72, blue: 0.48),
                                    Color(red: 0.39, green: 0.60, blue: 0.40)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 72)
                        .padding(.horizontal, 20)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    ZStack {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.45, green: 0.67, blue: 0.52),
                                        Color(red: 0.62, green: 0.82, blue: 0.65)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 220 * creatureScale, height: 250 * creatureScale)
                            .saturation(saturation)
                            .brightness(brightness - 1.0)
                            .opacity(1.0 - (digitalPenalty * 0.08))
                            .overlay(
                                Ellipse()
                                    .stroke(Color.white.opacity(0.48), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.12), radius: 16, y: 10)

                        Circle()
                            .fill(Color.white.opacity(0.88))
                            .frame(width: 24, height: 24)
                            .offset(x: -34, y: -34)

                        Circle()
                            .fill(Color.white.opacity(0.88))
                            .frame(width: 24, height: 24)
                            .offset(x: 34, y: -34)

                        Circle()
                            .fill(Color(red: 0.18, green: 0.22, blue: 0.20))
                            .frame(width: 9, height: 9)
                            .offset(x: -32, y: -33)

                        Circle()
                            .fill(Color(red: 0.18, green: 0.22, blue: 0.20))
                            .frame(width: 9, height: 9)
                            .offset(x: 32, y: -33)

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(digitalAccent.opacity(hasScreenTimeSelection ? 0.9 : 0.35))
                            .frame(width: 54, height: 10)
                            .offset(y: 26)

                        if selectedItemCount > 0 {
                            HStack(spacing: 10) {
                                ForEach(0..<min(selectedItemCount, 3), id: \.self) { index in
                                    Circle()
                                        .fill(GrowmiTheme.warmOrange.opacity(0.88))
                                        .frame(width: 12 + CGFloat(index) * 3, height: 12 + CGFloat(index) * 3)
                                }
                            }
                            .offset(x: 76, y: -76)
                        }

                        if digitalPenalty > 0.1 {
                            DamageMark(color: .orange.opacity(0.55), length: 34)
                                .rotationEffect(.degrees(-24))
                                .offset(x: -42, y: -4)

                            DamageMark(color: .red.opacity(0.45), length: 28)
                                .rotationEffect(.degrees(18))
                                .offset(x: 44, y: 16)

                            DamageMark(color: .orange.opacity(0.35), length: 22)
                                .rotationEffect(.degrees(40))
                                .offset(x: 10, y: 56)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                    HStack(spacing: 10) {
                        MetricChip(title: "Steps", value: "\(stepCount)")
                        MetricChip(title: "Selection", value: "\(selectedItemCount)")
                        MetricChip(title: "Auth", value: authorizationStatusText)
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 360, maxHeight: 360, alignment: .topLeading)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var digitalAccent: Color {
        if isScreenTimeApproved && hasScreenTimeSelection {
            return GrowmiTheme.primaryGreen
        } else if isScreenTimeApproved {
            return GrowmiTheme.accentGreen
        } else {
            return Color(red: 0.64, green: 0.70, blue: 0.62)
        }
    }

    private var hasScreenTimeSelection: Bool {
        selectedItemCount > 0
    }

    private var isScreenTimeApproved: Bool {
        authorizationStatusText == "Approved"
    }

    private var moodText: String {
        switch (stepCount, digitalPenalty) {
        case (10_000..., ..<0.3):
            return "charged / blooming"
        case (5_000..<10_000, ..<0.5):
            return "growing / steady"
        case (_, 0.5...):
            return "strained / noisy"
        case (1..<5_000, _):
            return "growing / soft"
        default:
            return "dormant / resting"
        }
    }
}

private struct DamageMark: View {
    let color: Color
    let length: CGFloat

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: length, height: 3)
    }
}

private struct PhysicalGrowthCard: View {
    let progressValue: Double
    let stepCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Physical Growth")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)
                Spacer()
            }

            ZStack {
                Circle()
                    .stroke(GrowmiTheme.accentGreen.opacity(0.3), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        AngularGradient(
                            colors: [GrowmiTheme.primaryGreen, GrowmiTheme.accentGreen, GrowmiTheme.warmOrange],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(GrowmiTheme.primaryGreen)
                    Text("\(Int(progressValue * 100))%")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(GrowmiTheme.textPrimary)
                }
            }
            .frame(width: 120, height: 120)
            .frame(maxWidth: .infinity)

            Text("\(stepCount) steps today")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GrowmiTheme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DigitalStrainCard: View {
    let digitalPenalty: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Digital Strain")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)
                Spacer()
            }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.92, blue: 0.88),
                                Color(red: 0.96, green: 0.84, blue: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                    )

                Circle()
                    .stroke(Color.red.opacity(0.18), lineWidth: 8)
                    .padding(10)

                ForEach(0..<3, id: \.self) { index in
                    DamageMark(color: .red.opacity(0.55), length: 34 - CGFloat(index) * 6)
                        .rotationEffect(.degrees(Double(index) * 28 - 18))
                        .offset(x: CGFloat(index - 1) * 10, y: CGFloat(index) * 2 - 4)
                }

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.75))
            }
            .frame(width: 120, height: 120)
            .frame(maxWidth: .infinity)

            Text(strainText)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GrowmiTheme.textSecondary)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var strainText: String {
        if digitalPenalty > 0.7 {
            return "Excess screen time strains it heavily."
        } else if digitalPenalty > 0.3 {
            return "Restricted app selection adds visible strain."
        } else {
            return "Low strain. Growmi stays calm."
        }
    }
}

private struct ActionPanel: View {
    let requestScreenTimeAccess: () -> Void
    let openFamilyActivityPicker: () -> Void
    let toggleReport: () -> Void
    let loadTodaySteps: () -> Void
    @Binding var isPresented: Bool
    @Binding var selection: FamilyActivitySelection
    let showReport: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: requestScreenTimeAccess) {
                    Label("Request Screen Time Access", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(GrowmiTheme.primaryGreen)

                Button(action: openFamilyActivityPicker) {
                    Label("Open Family Activity Picker", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(GrowmiTheme.primaryGreen)
                .familyActivityPicker(isPresented: $isPresented, selection: $selection)

                Button(action: toggleReport) {
                    Label(showReport ? "Hide Report" : "Toggle Report", systemImage: showReport ? "eye.slash" : "chart.bar.doc.horizontal")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(GrowmiTheme.primaryGreen)

                Button(action: loadTodaySteps) {
                    Label("Load Today's Steps", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(GrowmiTheme.accentGreen)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct DebugStatusPanel: View {
    let authorizationStatusText: String
    let authorizationMessage: String
    let selectionMessage: String
    let selectedApps: Int
    let selectedCategories: Int
    let selectedWebDomains: Int
    let showReport: Bool
    let stepCountMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug State")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                MetricRow(title: "Authorization Status", value: authorizationStatusText)
                MetricRow(title: "Authorization Message", value: authorizationMessage)
                MetricRow(title: "Selection Message", value: selectionMessage)
                MetricRow(title: "Selected Apps", value: "\(selectedApps)")
                MetricRow(title: "Selected Categories", value: "\(selectedCategories)")
                MetricRow(title: "Selected Web Domains", value: "\(selectedWebDomains)")
                MetricRow(title: "Show Report", value: showReport ? "Enabled" : "Hidden")
                MetricRow(title: "Step Count Message", value: stepCountMessage)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ReportSection: View {
    let authorizationStatusText: String
    let selectionMessage: String
    let physicalTag: String
    let reportContext: DeviceActivityReport.Context
    let reportFilter: DeviceActivityFilter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Report")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            MetricRow(title: "Authorization", value: authorizationStatusText)
            MetricRow(title: "Selection", value: selectionMessage)
            MetricRow(title: "Physical", value: physicalTag)

            Text("Report Context: summary")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textSecondary)

            DeviceActivityReport(reportContext, filter: reportFilter)
                .frame(height: 280)
                .border(GrowmiTheme.debugBorder, width: 1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(GrowmiTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(GrowmiTheme.debugBorder.opacity(0.8), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textSecondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GrowmiTheme.accentGreen.opacity(0.65), lineWidth: 1)
        )
    }
}

extension DeviceActivityReport.Context {
    static let summary = Self("summary")
}

#Preview {
    ContentView()
}
