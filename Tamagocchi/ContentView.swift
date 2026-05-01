//
//  ContentView.swift
//  Tamagocchi
//
//  Created by Marcus Chang on 2026/04/18.
//

import DeviceActivity
import FamilyControls
import HealthKit
import Foundation
import WidgetKit
import SwiftUI

private let lifeformAppGroupID = "group.com.marcus.Growmi"
private let lifeformWidgetStateKey = "LifeformWidgetState"
private let lifeformSelectionKey = "LifeformTimerSelectionData"

enum CharacterKind: String, CaseIterable, Codable, Identifiable {
    case green
    case blue
    case red

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .red:
            return "Red"
        }
    }
}

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

private extension CharacterKind {
    var appBackgroundColors: [Color] {
        switch self {
        case .green:
            return [
                Color(red: 0.972, green: 0.931, blue: 0.905),
                Color(red: 0.952, green: 0.954, blue: 0.908)
            ]
        case .blue:
            return [
                Color(red: 0.836, green: 0.900, blue: 0.943),
                Color(red: 0.804, green: 0.878, blue: 0.931)
            ]
        case .red:
            return [
                Color(red: 0.989, green: 0.878, blue: 0.800),
                Color(red: 0.981, green: 0.846, blue: 0.760)
            ]
        }
    }

    var appAccentColor: Color {
        switch self {
        case .green:
            return GrowmiTheme.primaryGreen
        case .blue:
            return Color(red: 0.34, green: 0.62, blue: 0.92)
        case .red:
            return Color(red: 0.93, green: 0.55, blue: 0.72)
        }
    }

    var appLineColor: Color {
        switch self {
        case .green:
            return Color(red: 0.55, green: 0.78, blue: 0.66)
        case .blue:
            return Color(red: 0.42, green: 0.65, blue: 0.87)
        case .red:
            return Color(red: 0.88, green: 0.54, blue: 0.66)
        }
    }

    var appBackgroundBaseColor: Color {
        switch self {
        case .green:
            return Color(red: 0.972, green: 0.931, blue: 0.905)
        case .blue:
            return Color(red: 0.836, green: 0.900, blue: 0.943)
        case .red:
            return Color(red: 0.989, green: 0.878, blue: 0.800)
        }
    }

    var smallDisplayName: String {
        switch self {
        case .green:
            return "green_small"
        case .blue:
            return "blue_small"
        case .red:
            return "red_small"
        }
    }
}

private func localizedAuthorizationStatusText(_ text: String) -> String {
    switch text {
    case "Not Determined":
        return "未確認"
    case "Denied":
        return "許可なし"
    case "Approved":
        return "許可済み"
    default:
        return "不明"
    }
}

private enum AppSection: String, CaseIterable, Identifiable {
    case home
    case history
    case characters
    case apps
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings:
            return "設定"
        case .apps:
            return "アプリ"
        case .characters:
            return "キャラ"
        case .history:
            return "履歴"
        case .home:
            return "ホーム"
        }
    }

    var iconName: String {
        switch self {
        case .settings:
            return "gearshape"
        case .apps:
            return "square.grid.2x2"
        case .characters:
            return "face.smiling"
        case .history:
            return "clock.arrow.circlepath"
        case .home:
            return "house"
        }
    }
}

struct ContentView: View {
    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    private let healthStore = HKHealthStore()

    @State private var authorizationMessage = "まだリクエストのお願いはしてないよ"
    @State private var selection = FamilyActivitySelection()
    @State private var isPresented = false
    @State private var selectionMessage = "まだ何も選ばれてないよ"
    @State private var showReport = false
    @State private var stepCountMessage = "歩数はまだ読み込まれてないよ"
    @State private var selectedCharacter: CharacterKind = .blue
    @State private var selectedSection: AppSection = .home

    var body: some View {
        ZStack {
            LinearGradient(
                colors: selectedCharacter.appBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            currentSectionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavigationBar(
                selectedSection: $selectedSection,
                selectedCharacter: selectedCharacter
            )
        }
        .onChange(of: selection) { _, newSelection in
            selectionMessage = "アプリ \(newSelection.applicationTokens.count) 件、カテゴリ \(newSelection.categoryTokens.count) 件、Web \(newSelection.webDomainTokens.count) 件が選ばれたよ。"
            syncSelectionToSharedStorage()
            syncWidgetStateToWidget()
        }
        .onChange(of: selectedCharacter) { _, _ in
            syncWidgetStateToWidget()
        }
        .onAppear {
            loadSelectionFromSharedStorage()
            syncWidgetStateToWidget()
        }
    }

    @ViewBuilder
    private var currentSectionView: some View {
        switch selectedSection {
        case .home:
            CreaturePage(
                stepCount: parsedStepCount,
                selectedItemCount: selectedItemCount,
                authorizationStatusText: authorizationStatusText,
                stepCountMessage: stepCountMessage,
                selectionMessage: selectionMessage,
                physicalLevel: physicalLevel,
                digitalPenalty: digitalPenalty,
                physicalTag: physicalTag,
                digitalStatusText: digitalStatusText,
                selectedCharacter: selectedCharacter
            )
        case .history:
            MetricsPage(
                stepCount: parsedStepCount,
                selectedItemCount: selectedItemCount,
                authorizationStatusText: authorizationStatusText,
                physicalLevel: physicalLevel,
                digitalPenalty: digitalPenalty,
                screenTimeHoursAvailable: screenTimeHoursAvailable,
                physicalTag: physicalTag,
                digitalStatusText: digitalStatusText,
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
                isPresented: $isPresented,
                selection: $selection,
                showReport: showReport
            )
        case .characters:
            PlaceholderSectionView(title: "キャラ")
        case .apps:
            PlaceholderSectionView(title: "アプリ")
        case .settings:
            DebugPage(
                authorizationStatusText: authorizationStatusText,
                authorizationMessage: authorizationMessage,
                selectionMessage: selectionMessage,
                selectedApps: selection.applicationTokens.count,
                selectedCategories: selection.categoryTokens.count,
                selectedWebDomains: selection.webDomainTokens.count,
                showReport: showReport,
                stepCountMessage: stepCountMessage,
                selectedCharacter: $selectedCharacter,
                reportContext: reportContext,
                reportFilter: reportFilter
            )
        }
    }

    private var selectedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private var digitalPenalty: Double {
        min(1.0, Double(selectedItemCount) / 10.0)
    }

    private var screenTimeHoursAvailable: Double {
        max(0, 24.0 - (digitalPenalty * 10.0))
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
            return "元気いっぱい！"
        } else if steps >= 5_000 {
            return "目がさめてる"
        } else if steps > 0 {
            return "成長中"
        } else {
            return "休んでる"
        }
    }

    private var digitalStatusText: String {
        switch (isScreenTimeApproved, hasScreenTimeSelection) {
        case (true, true):
            return "スマホ負担あり"
        case (true, false):
            return "許可だけ済み"
        default:
            return "スクリーンタイム未許可"
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
            authorizationMessage = "許可のお願いが完了したよ"
            syncWidgetStateToWidget()
        } catch {
            authorizationMessage = "許可に失敗したよ: \(error.localizedDescription)"
            syncWidgetStateToWidget()
        }
    }

    @MainActor
    private func loadTodayStepCount() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            stepCountMessage = "この端末ではヘルスケアデータを使えないよ"
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

            stepCountMessage = "今日の歩数は \(Int(stepCount)) 歩だよ"
            syncWidgetStateToWidget()
        } catch {
            stepCountMessage = "歩数の読み込みに失敗したよ: \(error.localizedDescription)"
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
            showReport: showReport,
            selectedCharacter: selectedCharacter
        )

        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
              let data = try? JSONEncoder().encode(widgetState) else {
            return
        }

        defaults.set(data, forKey: lifeformWidgetStateKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func syncSelectionToSharedStorage() {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
              let data = try? JSONEncoder().encode(selection) else {
            return
        }

        defaults.set(data, forKey: lifeformSelectionKey)
    }

    private func loadSelectionFromSharedStorage() {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
              let data = defaults.data(forKey: lifeformSelectionKey),
              let storedSelection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }

        selection = storedSelection
        selectionMessage = "アプリ \(storedSelection.applicationTokens.count) 件、カテゴリ \(storedSelection.categoryTokens.count) 件、Web \(storedSelection.webDomainTokens.count) 件が選ばれたよ。"
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
    let selectedCharacter: CharacterKind
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
    let selectedCharacter: CharacterKind

    private var overallScore: Int {
        let physicalScore = min(1.0, physicalLevel / 10_000.0)
        let score = (physicalScore * 70.0) + ((1.0 - digitalPenalty) * 30.0)
        return Int(max(0, min(100, score)).rounded())
    }

    private var estimatedDistanceKilometers: Double {
        Double(stepCount) * 0.0007
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(selectedCharacter.displayName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, alignment: .top)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.88), location: 0.10),
                            .init(color: .white, location: 0.18),
                            .init(color: .white, location: 0.82),
                            .init(color: .white.opacity(0.88), location: 0.90),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            HStack(alignment: .center, spacing: 6) {
                VStack(spacing: 10) {
                    AppDataPill(
                        iconName: "figure.walk",
                        iconColor: GrowmiTheme.primaryGreen,
                        title: "歩数",
                        value: "\(stepCount.formatted())歩",
                        borderColor: selectedCharacter.appLineColor
                    )

                    AppDataPill(
                        iconName: "shoeprints.fill",
                        iconColor: Color(red: 0.31, green: 0.58, blue: 0.96),
                        title: "移動距離",
                        value: "\(estimatedDistanceKilometers.formatted(.number.precision(.fractionLength(1))))km",
                        borderColor: selectedCharacter.appLineColor
                    )
                }

                AppScoreCard(
                    score: overallScore,
                    accentColor: selectedCharacter.appAccentColor
                )

                VStack(spacing: 10) {
                    AppDataPill(
                        iconName: "clock",
                        iconColor: GrowmiTheme.warmOrange,
                        title: "SNS利用時間",
                        value: "0分",
                        borderColor: selectedCharacter.appLineColor
                    )

                    AppDataPill(
                        iconName: "heart.fill",
                        iconColor: Color(red: 0.93, green: 0.55, blue: 0.72),
                        title: "すれ違い",
                        value: "0人",
                        borderColor: selectedCharacter.appLineColor
                    )
                }
            }
            .padding(.horizontal, 18)
            .offset(y: 6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct AppScoreCard: View {
    let score: Int
    let accentColor: Color

    private var normalizedScore: Double {
        Double(score) / 100.0
    }

    var body: some View {
        ZStack {
            OpenCircleArc()
                .stroke(Color.white.opacity(0.72), style: StrokeStyle(lineWidth: 11, lineCap: .round))

            OpenCircleArc(progress: normalizedScore)
                .stroke(
                    LinearGradient(
                        colors: [
                            accentColor,
                            Color(red: 0.90, green: 0.78, blue: 0.20),
                            Color(red: 0.96, green: 0.55, blue: 0.20)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )

            VStack(spacing: 3) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GrowmiTheme.warmOrange)

                Text("\(score)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)

                Text("/100")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textSecondary)
                    .offset(y: -4)
            }

            HStack(spacing: 6) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("のんびり")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.12))
            )
            .offset(y: 68)
        }
        .frame(width: 156, height: 136)
    }
}

private struct AppDataPill: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let value: String
    let borderColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textSecondary)

                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 116, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}

private struct OpenCircleArc: Shape {
    var progress: Double = 1.0

    func path(in rect: CGRect) -> Path {
        let clamped = max(0.0, min(1.0, progress))
        let startAngle = Angle.degrees(145)
        let endAngle = Angle.degrees(395)
        let currentAngle = Angle.degrees(145 + (250 * clamped))
        let radius = (min(rect.width, rect.height) / 2) - 8
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: progress >= 1.0 ? endAngle : currentAngle,
            clockwise: false
        )
        return path
    }
}

private struct PlaceholderSectionView: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BottomNavigationBar: View {
    @Binding var selectedSection: AppSection
    let selectedCharacter: CharacterKind

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    ForEach([AppSection.home, .history]) { section in
                        navigationItem(for: section)
                    }

                    Color.clear
                        .frame(width: 92)

                    ForEach([AppSection.apps, .settings]) { section in
                        navigationItem(for: section)
                    }
                }
                .padding(.horizontal, 22)
                .frame(height: 60)
                .background(selectedCharacter.appBackgroundBaseColor.opacity(0.98))
            }

            navigationItem(for: .characters)
                .offset(y: -16)
        }
        .frame(height: 74)
    }

    @ViewBuilder
    private func navigationItem(for section: AppSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            if section == .characters {
                Image(selectedCharacter.smallDisplayName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .padding(7)
                    .background(
                        Circle()
                            .fill(selectedCharacter.appBackgroundBaseColor)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
                    .frame(width: 76, height: 76)
                    .frame(width: 92)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: section.iconName)
                        .font(.system(size: 21, weight: .semibold))
                    Text(section.title)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(selectedSection == section ? Color(red: 0.10, green: 0.45, blue: 0.95) : Color.black.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MetricsPage: View {
    let stepCount: Int
    let selectedItemCount: Int
    let authorizationStatusText: String
    let physicalLevel: Double
    let digitalPenalty: Double
    let screenTimeHoursAvailable: Double
    let physicalTag: String
    let digitalStatusText: String
    let requestScreenTimeAccess: () -> Void
    let openFamilyActivityPicker: () -> Void
    let toggleReport: () -> Void
    let loadTodaySteps: () -> Void
    @Binding var isPresented: Bool
    @Binding var selection: FamilyActivitySelection
    let showReport: Bool

    private var progressValue: Double {
        min(Double(stepCount) / 10_000.0, 1.0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                PageHeader(
                    title: "今日のようす",
                    subtitle: "歩くほど元気になるよ！スマホを使いすぎると少し疲れるよ。"
                )

                HStack(alignment: .top, spacing: 12) {
                    PhysicalGrowthCard(progressValue: progressValue, stepCount: stepCount)
                        .border(GrowmiTheme.debugBorder, width: 1)

                    DigitalStrainCard(
                        digitalPenalty: digitalPenalty,
                        screenTimeHoursAvailable: screenTimeHoursAvailable
                    )
                        .border(GrowmiTheme.debugBorder, width: 1)
                }

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

                VStack(alignment: .leading, spacing: 10) {
                    MetricRow(title: "歩数", value: "\(stepCount)")
                    MetricRow(title: "選ばれた項目", value: "\(selectedItemCount)")
                    MetricRow(title: "許可状態", value: localizedAuthorizationStatusText(authorizationStatusText))
                    MetricRow(title: "フィットネス", value: physicalTag)
                    MetricRow(title: "SNS疲れ", value: digitalStatusText)
                }
                .border(GrowmiTheme.debugBorder, width: 1)

                Text("歩くほど元気になるよ！スマホを使いすぎると少し疲れるよ。")
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
    @Binding var selectedCharacter: CharacterKind
    let reportContext: DeviceActivityReport.Context
    let reportFilter: DeviceActivityFilter

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                PageHeader(
                    title: "デバッグ",
                    subtitle: "バックエンドの状態を見ながら調整するよ。"
                )

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

                CharacterSelectionPanel(selectedCharacter: $selectedCharacter)
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

private struct CharacterSelectionPanel: View {
    @Binding var selectedCharacter: CharacterKind

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("キャラクター選択")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            Text("デバッグ用に、表示したいキャラクターをここで切り替えるよ。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GrowmiTheme.textSecondary)

            Picker("キャラクター", selection: $selectedCharacter) {
                ForEach(CharacterKind.allCases) { character in
                    Text(character.displayName).tag(character)
                }
            }
            .pickerStyle(.segmented)
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
            MetricChip(title: "歩数", value: "\(stepCount)")
            MetricChip(title: "選択", value: "\(selectedItemCount)")
            MetricChip(title: "状態", value: localizedAuthorizationStatusText(authorizationStatusText))
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
                Text("Growmiのようす")
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
                        MetricChip(title: "歩数", value: "\(stepCount)")
                        MetricChip(title: "選択", value: "\(selectedItemCount)")
                        MetricChip(title: "状態", value: localizedAuthorizationStatusText(authorizationStatusText))
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
            return "元気いっぱい / ぴかぴか"
        case (5_000..<10_000, ..<0.5):
            return "成長中 / いい感じ"
        case (_, 0.5...):
            return "ちょっと疲れ気味 / ざわざわ"
        case (1..<5_000, _):
            return "成長中 / やわらか"
        default:
            return "休んでる / ひとやすみ"
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
//            HStack {
//                Text("")
//                    .font(.system(size: 18, weight: .bold, design: .rounded))
//                    .foregroundStyle(GrowmiTheme.textPrimary)
//                Spacer()
//            }

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

            Text("今日の歩数 \(stepCount) 歩")
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
    let screenTimeHoursAvailable: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
//            HStack {
//                Text("")
//                    .font(.system(size: 18, weight: .bold, design: .rounded))
//                    .foregroundStyle(GrowmiTheme.textPrimary)
//                Spacer()
//            }

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ringTopColor,
                                ringBottomColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.38), lineWidth: 1)
                    )

                Circle()
                    .stroke(Color.red.opacity(0.28), lineWidth: 8)
                    .padding(10)

                ForEach(0..<3, id: \.self) { index in
                    DamageMark(color: .red.opacity(0.75), length: 34 - CGFloat(index) * 6)
                        .rotationEffect(.degrees(Double(index) * 28 - 18))
                        .offset(x: CGFloat(index - 1) * 10, y: CGFloat(index) * 2 - 4)
                }

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.red.opacity(0.88))
            }
            .frame(width: 120, height: 120)
            .frame(maxWidth: .infinity)

            Text(hoursLabel)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

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
            return "スマホの使いすぎで、かなり疲れ気味。"
        } else if digitalPenalty > 0.3 {
            return "選ばれたアプリが増えると、少し負担が出るよ。"
        } else {
            return "負担は少なめ。Growmiは落ち着いてるよ。"
        }
    }

    private var hoursLabel: String {
        String(format: "今日使ったスマホ時間 %.1f時間", max(0, 24.0 - screenTimeHoursAvailable))
    }

    private var warningColor: Color {
        if screenTimeHoursAvailable <= 4 {
            return Color.red.opacity(0.88)
        } else if screenTimeHoursAvailable <= 10 {
            return Color.red.opacity(0.82)
        } else {
            return Color(red: 0.82, green: 0.30, blue: 0.28)
        }
    }

    private var ringTopColor: Color {
        if screenTimeHoursAvailable <= 4 {
            return Color(red: 0.98, green: 0.82, blue: 0.82)
        } else if screenTimeHoursAvailable <= 10 {
            return Color(red: 0.97, green: 0.76, blue: 0.75)
        } else {
            return Color(red: 0.94, green: 0.87, blue: 0.86)
        }
    }

    private var ringBottomColor: Color {
        if screenTimeHoursAvailable <= 4 {
            return Color(red: 0.90, green: 0.36, blue: 0.34)
        } else if screenTimeHoursAvailable <= 10 {
            return Color(red: 0.88, green: 0.42, blue: 0.38)
        } else {
            return Color(red: 0.80, green: 0.46, blue: 0.42)
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
            Text("操作")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                Button(action: requestScreenTimeAccess) {
                    Label("スクリーンタイムの使用をリクエスト", systemImage: "checkmark.shield")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(GrowmiTheme.primaryGreen)

                Button(action: openFamilyActivityPicker) {
                    Label("アプリをえらぶ", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(GrowmiTheme.primaryGreen)
                .familyActivityPicker(isPresented: $isPresented, selection: $selection)

                Button(action: toggleReport) {
                    Label(showReport ? "レポートを隠す" : "レポートを切り替え", systemImage: showReport ? "eye.slash" : "chart.bar.doc.horizontal")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(GrowmiTheme.primaryGreen)

                Button(action: loadTodaySteps) {
                    Label("運動データを読み込む", systemImage: "figure.walk")
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
                Text("状態")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                MetricRow(title: "許可状態", value: localizedAuthorizationStatusText(authorizationStatusText))
                MetricRow(title: "許可メッセージ", value: authorizationMessage)
                MetricRow(title: "選択メッセージ", value: selectionMessage)
                MetricRow(title: "選ばれたアプリ", value: "\(selectedApps)")
                MetricRow(title: "選ばれたカテゴリ", value: "\(selectedCategories)")
                MetricRow(title: "選ばれたWeb", value: "\(selectedWebDomains)")
                MetricRow(title: "レポート表示", value: showReport ? "表示中" : "非表示")
                MetricRow(title: "歩数メッセージ", value: stepCountMessage)
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
            Text("レポート")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            MetricRow(title: "許可", value: localizedAuthorizationStatusText(authorizationStatusText))
            MetricRow(title: "選択", value: selectionMessage)
            MetricRow(title: "体の状態", value: physicalTag)

            Text("レポートの種類：サマリー")
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
