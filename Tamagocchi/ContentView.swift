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
private let lifeformScreenTimeMinutesKey = "LifeformScreenTimeMinutes"
private let lifeformScreenTimeUpdatedAtKey = "LifeformScreenTimeUpdatedAt"
private let growmiApproxScreenTimeMinutesKey = "GrowMiApproxScreenTimeMinutes"
private let growmiApproxScreenTimeUpdatedAtKey = "GrowMiDigitalStrainUpdatedAt"
private let growmiDigitalStrainLevelKey = "GrowMiDigitalStrainLevel"
private let growmiLastThresholdEventKey = "GrowMiLastThresholdEvent"
private let growmiDailyMonitorActivityName = DeviceActivityName("growmi.daily")
private let growmiDailyThresholdCeilingMinutes = 1_440

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

    var transparentDisplayName: String {
        switch self {
        case .green:
            return "green_trans"
        case .blue:
            return "blue_trans"
        case .red:
            return "red_trans"
        }
    }
    
    var glassesPreviewOffset: CGSize {
        switch self {
        case .green:
            return CGSize(width: 0, height: 64)
        case .blue:
            return CGSize(width: -3, height: 64)
        case .red:
            return CGSize(width: -1, height: 64)
        }
    }

    func moodImageName(for score: Int) -> String {
        switch score {
        case ..<33:
            switch self {
            case .green:
                return "Green_sad"
            case .blue:
                return "Blue_sad"
            case .red:
                return "Red_sad"
            }
        case 33...66:
            switch self {
            case .green:
                return "Green"
            case .blue:
                return "Blue"
            case .red:
                return "Red"
            }
        default:
            switch self {
            case .green:
                return "Green_happy"
            case .blue:
                return "Blue_happy"
            case .red:
                return "Red_happy"
            }
        }
    }

    var glassesPreviewOffset: CGSize {
        switch self {
        case .green:
            return CGSize(width: 0, height: 64)
        case .blue:
            return CGSize(width: -3, height: 64)
        case .red:
            return CGSize(width: -1, height: 64)
        }
    }

    var homeGlassesLayout: GlassesOverlayLayout {
        switch self {
        case .green:
            return GlassesOverlayLayout(size: 180, offset: CGSize(width: 0, height: 168))
        case .blue:
            return GlassesOverlayLayout(size: 180, offset: CGSize(width: 0, height: 160))
        case .red:
            return GlassesOverlayLayout(size: 170, offset: CGSize(width: -1, height: 174))
        }
    }
}

private struct GlassesOverlayLayout {
    let size: CGFloat
    let offset: CGSize
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
    case character
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .character:
            return "キャラ"
        case .settings:
            return "設定"
        case .home:
            return "ホーム"
        }
    }

    var iconName: String {
        switch self {
        case .character:
            return "person.crop.square"
        case .settings:
            return "gearshape"
        case .home:
            return "house"
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var authorizationCenter = AuthorizationCenter.shared
    private let healthStore = HKHealthStore()
    private let deviceActivityCenter = DeviceActivityCenter()

    @State private var authorizationMessage = "まだリクエストのお願いはしてないよ"
    @State private var selection = FamilyActivitySelection()
    @State private var isPresented = false
    @State private var selectionMessage = "まだ何も選ばれてないよ"
    @State private var showReport = false
    @State private var stepCountMessage = "歩数はまだ読み込まれてないよ"
    @State private var screenTimeMinutes: Double = 0
    @State private var screenTimeMaxMinutesSoFar: Double = 0
    @State private var screenTimeUpdatedAt: TimeInterval = 0
    @State private var screenTimeReadSucceeded = false
    @State private var didLoadTodayStepCount = false
    @State private var debugScore: Double = 50
    @State private var selectedCharacter: CharacterKind = .blue
    @State private var selectedCustomItem: CustomItem = .sunglasses
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
        .background {
            DeviceActivityReport(reportContext, filter: reportFilter)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            BottomNavigationBar(
                selectedSection: $selectedSection,
                selectedCharacter: selectedCharacter
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: selection) { _, newSelection in
            selectionMessage = "アプリ \(newSelection.applicationTokens.count) 件、カテゴリ \(newSelection.categoryTokens.count) 件、Web \(newSelection.webDomainTokens.count) 件が選ばれたよ。"
            syncSelectionToSharedStorage()
            syncWidgetStateToWidget()
            Task { await refreshAppMetrics() }
        }
        .onChange(of: selectedCharacter) { _, _ in
            syncWidgetStateToWidget()
        }
        .onChange(of: selectedCustomItem) { _, _ in
            syncWidgetStateToWidget()
        }
        .onChange(of: showReport) { _, isShowing in
            guard isShowing else { return }

            Task { await refreshScreenTimeFromReport() }
        }
        .onChange(of: selectedSection) { _, newSection in
            guard newSection == .home else { return }

            Task { await refreshScreenTimeFromReport() }
        }
        .onAppear {
            loadSelectionFromSharedStorage()
            Task { await refreshAppMetrics() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshAppMetrics() }
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
                screenTimeDisplayText: screenTimeDisplayText,
                debugScore: debugScore,
                selectedCharacter: selectedCharacter,
                selectedCustomItem: selectedCustomItem
            )
        case .character:
            CharacterPage(
                selectedCharacter: $selectedCharacter,
                selectedCustomItem: $selectedCustomItem
            )
        case .settings:
            SettingsPage(
                authorizationStatusText: authorizationStatusText,
                authorizationMessage: authorizationMessage,
                selectionMessage: selectionMessage,
                debugScore: debugScore,
                selectedApps: selection.applicationTokens.count,
                selectedCategories: selection.categoryTokens.count,
                selectedWebDomains: selection.webDomainTokens.count,
                showReport: showReport,
                stepCountMessage: stepCountMessage,
                screenTimeDisplayText: screenTimeDisplayText,
                screenTimeMinutes: screenTimeMinutes,
                screenTimeMaxMinutesSoFar: screenTimeMaxMinutesSoFar,
                screenTimeUpdatedAtText: screenTimeUpdatedAtText,
                screenTimeReadStatusText: screenTimeReadStatusText,
                screenTimeReadSucceeded: screenTimeReadSucceeded,
                updateDebugScore: { newValue in
                    debugScore = newValue
                    syncWidgetStateToWidget()
                },
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
                    Task { @MainActor in
                        for delay in [300_000_000, 800_000_000, 1_500_000_000] {
                            try? await Task.sleep(nanoseconds: UInt64(delay))
                            reloadScreenTimeMinutesFromSharedStorage()
                            syncWidgetStateToWidget()
                        }
                    }
                },
                loadTodaySteps: {
                    Task {
                        await loadTodayStepCount()
                    }
                },
                isPresented: $isPresented,
                selection: $selection,
                reportContext: reportContext,
                reportFilter: reportFilter
            )
        }
    }

    private var selectedItemCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    private var screenTimeDisplayText: String {
        formattedScreenTime(minutes: screenTimeMinutes)
    }

    private var screenTimeReadStatusText: String {
        screenTimeReadSucceeded ? "成功" : "失敗"
    }

    private var screenTimeUpdatedAtText: String {
        guard screenTimeUpdatedAt > 0 else {
            return "未更新"
        }

        return Date(timeIntervalSince1970: screenTimeUpdatedAt).formatted(date: .abbreviated, time: .standard)
    }

    @MainActor
    private func refreshScreenTimeFromReport() async {
        reloadScreenTimeMinutesFromSharedStorage()
        syncWidgetStateToWidget()

        for delay in [300_000_000, 800_000_000, 1_500_000_000] {
            try? await Task.sleep(nanoseconds: UInt64(delay))
            reloadScreenTimeMinutesFromSharedStorage()
            syncWidgetStateToWidget()
        }
    }

    @MainActor
    private func loadTodayStepCountIfNeeded() async {
        guard !didLoadTodayStepCount else {
            return
        }

        didLoadTodayStepCount = true
        await loadTodayStepCount()
    }

    @MainActor
    private func reloadScreenTimeMinutesFromSharedStorage() {
        let readTimestamp = Date()

        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID) else {
            screenTimeReadSucceeded = false
            print("[ScreenTime] Main app failed to open App Group defaults at \(readTimestamp)")
            return
        }

        screenTimeReadSucceeded = true
        print("[ScreenTime] Main app opened App Group defaults at \(readTimestamp)")

        let minutes = defaults.double(forKey: growmiApproxScreenTimeMinutesKey)
        let updatedAt = defaults.double(forKey: growmiApproxScreenTimeUpdatedAtKey)
        let strainLevel = defaults.string(forKey: growmiDigitalStrainLevelKey) ?? "calm"
        let thresholdEvent = defaults.string(forKey: growmiLastThresholdEventKey) ?? "none"
        print("[ScreenTime] Main app read minutes: \(minutes)")
        print("[ScreenTime] Main app read strain level: \(strainLevel)")
        print("[ScreenTime] Main app read event: \(thresholdEvent)")

        if updatedAt > 0 {
            print("[ScreenTime] Main app read updatedAt: \(Date(timeIntervalSince1970: updatedAt))")
        } else {
            print("[ScreenTime] Main app found no updatedAt value")
        }

        screenTimeMinutes = minutes
        screenTimeMaxMinutesSoFar = max(screenTimeMaxMinutesSoFar, minutes)
        screenTimeUpdatedAt = updatedAt
    }

    @MainActor
    private func syncScreenTimeMonitoringState() {
        if isScreenTimeApproved, hasScreenTimeSelection {
            startScreenTimeMonitoring()
        } else {
            stopScreenTimeMonitoring()
            clearApproximateScreenTimeSharedState()
        }
    }

    private func startScreenTimeMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for minutes in stride(from: 10, through: growmiDailyThresholdCeilingMinutes, by: 10) {
            let eventName = DeviceActivityEvent.Name("growmi.usage.\(minutes)")
            events[eventName] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes),
                includesPastActivity: true
            )
        }

        do {
            deviceActivityCenter.stopMonitoring([growmiDailyMonitorActivityName])
            try deviceActivityCenter.startMonitoring(growmiDailyMonitorActivityName, during: schedule, events: events)
            print("[Monitor] Started monitoring with \(events.count) thresholds")
        } catch {
            print("[Monitor] Failed to start monitoring: \(error.localizedDescription)")
        }
    }

    private func stopScreenTimeMonitoring() {
        deviceActivityCenter.stopMonitoring([growmiDailyMonitorActivityName])
        print("[Monitor] Stopped monitoring")
    }

    private func clearApproximateScreenTimeSharedState() {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID) else {
            return
        }

        let now = Date().timeIntervalSince1970
        defaults.set(0, forKey: growmiApproxScreenTimeMinutesKey)
        defaults.set(now, forKey: growmiApproxScreenTimeUpdatedAtKey)
        defaults.set("calm", forKey: growmiDigitalStrainLevelKey)
        defaults.set("selection-cleared", forKey: growmiLastThresholdEventKey)
    }

    private func formattedScreenTime(minutes: Double) -> String {
        guard minutes > 0 else {
            return "0分"
        }

        if minutes >= 60 {
            return String(format: "%.1f時間", minutes / 60)
        } else {
            return String(format: "%.0f分", minutes.rounded())
        }
    }

    private var digitalPenalty: Double {
        min(1.0, screenTimeMinutes / 240.0)
    }

    private var normalizedDebugScore: Double {
        max(0, min(100, debugScore))
    }

    private var physicalLevel: Double {
        Double(parsedStepCount)
    }

    private var hasScreenTimeSelection: Bool {
        selectedItemCount > 0
    }

    private var isScreenTimeApproved: Bool {
        authorizationCenter.authorizationStatus == .approved
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
        switch (isScreenTimeApproved, screenTimeMinutes > 0) {
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
            await refreshAppMetrics()
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
            applications: [],
            categories: [],
            webDomains: []
        )
    }

    @MainActor
    private func refreshAppMetrics() async {
        await loadTodayStepCountIfNeeded()
        syncScreenTimeMonitoringState()
        await refreshScreenTimeFromReport()
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
            screenTimeMinutes: screenTimeMinutes,
            showReport: showReport,
            selectedCharacter: selectedCharacter,
            selectedCustomItem: selectedCustomItem
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
    let screenTimeMinutes: Double
    let showReport: Bool
    let selectedCharacter: CharacterKind
    let selectedCustomItem: CustomItem
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
    let screenTimeDisplayText: String
    let debugScore: Double
    let selectedCharacter: CharacterKind
    let selectedCustomItem: CustomItem

    private var currentScore: Int {
        Int(max(0, min(100, debugScore)).rounded())
    }

    private var estimatedDistanceKilometers: Double {
        Double(stepCount) * 0.0007
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Image(selectedCharacter.displayName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .offset(y: 18)
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

                CustomItemIcon(item: selectedCustomItem, size: selectedCharacter.homeGlassesLayout.size, symbolSize: 40)
                    .shadow(color: selectedCustomItem.tint.opacity(0.24), radius: 8, y: 5)
                    .offset(
                        x: selectedCharacter.homeGlassesLayout.offset.width,
                        y: selectedCharacter.homeGlassesLayout.offset.height
                    )
            }

            HStack(alignment: .center, spacing: 10) {
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
                    score: currentScore,
                    accentColor: selectedCharacter.appAccentColor
                )

                VStack(spacing: 10) {
                    AppDataPill(
                        iconName: "clock",
                        iconColor: GrowmiTheme.warmOrange,
                        title: "SNS利用時間",
                        value: screenTimeDisplayText,
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
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 8)
            .offset(y: 24)

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
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)

                Text("/100")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
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
            .offset(y: 60)
        }
        .frame(width: 124, height: 120)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(width: 102, alignment: .leading)
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
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                selectedCharacter.appBackgroundBaseColor.opacity(0.98)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 1)

                    HStack(spacing: 0) {
                        ForEach([AppSection.home, .character, .settings]) { section in
                            navigationItem(for: section)
                        }
                    }
                    .padding(.horizontal, 22)
                    .frame(height: 60)

                    Color.clear
                        .frame(height: bottomInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            }
            .frame(maxWidth: .infinity, maxHeight: 60 + bottomInset)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 60 + 44)
    }

    @ViewBuilder
    private func navigationItem(for section: AppSection) -> some View {
        let isSelected = selectedSection == section
        let foregroundColor = isSelected ? Color(red: 0.10, green: 0.45, blue: 0.95) : Color.black.opacity(0.55)

        Button {
            selectedSection = section
        } label: {
            VStack(spacing: 8) {
                if section == .character {
                    Image(selectedCharacter.smallDisplayName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: section.iconName)
                        .font(.system(size: 21, weight: .semibold))
                }
                Text(section.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsPage: View {
    let authorizationStatusText: String
    let authorizationMessage: String
    let selectionMessage: String
    let debugScore: Double
    let selectedApps: Int
    let selectedCategories: Int
    let selectedWebDomains: Int
    let showReport: Bool
    let stepCountMessage: String
    let screenTimeDisplayText: String
    let screenTimeMinutes: Double
    let screenTimeMaxMinutesSoFar: Double
    let screenTimeUpdatedAtText: String
    let screenTimeReadStatusText: String
    let screenTimeReadSucceeded: Bool
    let updateDebugScore: (Double) -> Void
    let requestScreenTimeAccess: () -> Void
    let openFamilyActivityPicker: () -> Void
    let toggleReport: () -> Void
    let loadTodaySteps: () -> Void
    @Binding var isPresented: Bool
    @Binding var selection: FamilyActivitySelection
    let reportContext: DeviceActivityReport.Context
    let reportFilter: DeviceActivityFilter

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ScreenTimeDebugPanel(
                    authorizationStatusText: authorizationStatusText,
                    screenTimeMinutes: screenTimeMinutes,
                    screenTimeMaxMinutesSoFar: screenTimeMaxMinutesSoFar,
                    screenTimeUpdatedAtText: screenTimeUpdatedAtText,
                    readStatusText: screenTimeReadStatusText,
                    appGroupReadSucceeded: screenTimeReadSucceeded
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("デバッグスコア")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(GrowmiTheme.textPrimary)

                    Text("この値でキャラクターの気分を直接切り替えるよ。")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(GrowmiTheme.textSecondary)

                    Slider(
                        value: Binding(
                            get: { debugScore },
                            set: { updateDebugScore($0) }
                        ),
                        in: 0...100,
                        step: 1
                    )

                    MetricRow(title: "現在値", value: "\(Int(debugScore.rounded()))")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(GrowmiTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("レポート")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(GrowmiTheme.textPrimary)

                    DeviceActivityReport(reportContext, filter: reportFilter)
                        .frame(height: 280)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(GrowmiTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                ActionPanel(
                    requestScreenTimeAccess: requestScreenTimeAccess,
                    openFamilyActivityPicker: openFamilyActivityPicker,
                    toggleReport: toggleReport,
                    loadTodaySteps: loadTodaySteps,
                    isPresented: $isPresented,
                    selection: $selection,
                    showReport: showReport
                )

            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 104)
        }
    }
}

private struct CharacterPage: View {
    @Binding var selectedCharacter: CharacterKind
    @Binding var selectedCustomItem: CustomItem

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                CharacterSelectionPanel(selectedCharacter: $selectedCharacter)
                CharacterCustomizationPanel(
                    selectedCharacter: selectedCharacter,
                    selectedCustomItem: $selectedCustomItem
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 104)
        }
    }
}

private enum CustomItem: String, CaseIterable, Codable, Identifiable {
    case sunglasses
    case roundGlasses
    case squareGlasses

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunglasses:
            return "メガネ"
        case .roundGlasses:
            return "丸メガネ"
        case .squareGlasses:
            return "スクエアメガネ"
        }
    }

    var assetName: String? {
        switch self {
        case .sunglasses:
            return "glasses_normal"
        case .roundGlasses:
            return "glasses_round"
        case .squareGlasses:
            return "glasses_square"
        }
    }

    var symbolName: String {
        switch self {
        case .sunglasses:
            return "sunglasses.fill"
        case .roundGlasses:
            return "eyeglasses"
        case .squareGlasses:
            return "eyeglasses"
        }
    }

    var tint: Color {
        switch self {
        case .sunglasses:
            return Color(red: 0.18, green: 0.20, blue: 0.22)
        case .roundGlasses:
            return Color(red: 0.18, green: 0.20, blue: 0.22)
        case .squareGlasses:
            return Color(red: 0.18, green: 0.20, blue: 0.22)
        }
    }
}

private struct CharacterSelectionPanel: View {
    @Binding var selectedCharacter: CharacterKind

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("キャラクター選択")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            HStack(spacing: 12) {
                ForEach(CharacterKind.allCases) { character in
                    CharacterChoiceButton(
                        character: character,
                        isSelected: selectedCharacter == character
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedCharacter = character
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(GrowmiTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CharacterChoiceButton: View {
    let character: CharacterKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                character.appAccentColor.opacity(0.24),
                                character.appBackgroundBaseColor.opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle()
                            .stroke(character.appLineColor.opacity(isSelected ? 0.95 : 0.38), lineWidth: isSelected ? 3 : 1)
                    }
                    .shadow(color: character.appAccentColor.opacity(isSelected ? 0.28 : 0.12), radius: isSelected ? 12 : 6, y: 6)

                Image(character.smallDisplayName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .padding(12)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white, character.appAccentColor)
                        .background(Circle().fill(.white))
                        .offset(x: 4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? character.appAccentColor.opacity(0.14) : Color.white.opacity(0.34))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(character.appLineColor.opacity(isSelected ? 0.9 : 0.24), lineWidth: isSelected ? 2 : 1)
            }
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(character.displayName)を選択")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct CharacterCustomizationPanel: View {
    let selectedCharacter: CharacterKind
    @Binding var selectedCustomItem: CustomItem

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("カスタマイズ")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            VStack(spacing: 10) {
                ForEach(CustomItem.allCases) { item in
                    CustomItemRow(
                        item: item,
                        isSelected: selectedCustomItem == item
                    ) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedCustomItem = item
                        }
                    }
                }
            }

            CharacterCustomizationPreview(
                character: selectedCharacter,
                item: selectedCustomItem
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(GrowmiTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CustomItemRow: View {
    let item: CustomItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                CustomItemIcon(item: item, size: 38, symbolSize: 18)

                Text(item.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textPrimary)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(item.tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? item.tint.opacity(0.16) : Color.white.opacity(0.34))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(item.tint.opacity(isSelected ? 0.8 : 0.18), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title)を選択")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct CustomItemIcon: View {
    let item: CustomItem
    let size: CGFloat
    let symbolSize: CGFloat

    var body: some View {
        ZStack {
            if let assetName = item.assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Circle().fill(item.tint)

                Image(systemName: item.symbolName)
                    .font(.system(size: symbolSize, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct CharacterCustomizationPreview: View {
    let character: CharacterKind
    let item: CustomItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            character.appBackgroundBaseColor.opacity(0.52),
                            character.appAccentColor.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(character.appLineColor.opacity(0.24), lineWidth: 1)
                }

            VStack(spacing: 10) {
                ZStack(alignment: .top) {
                    Image(character.transparentDisplayName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 172)
                        .shadow(color: character.appAccentColor.opacity(0.22), radius: 12, y: 8)

                    CustomItemIcon(item: item, size: 76, symbolSize: 28)
                        .shadow(color: item.tint.opacity(0.24), radius: 8, y: 5)
                        .offset(x: character.glassesPreviewOffset.width, y: character.glassesPreviewOffset.height)
                }

                Text("Preview")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiTheme.textSecondary)
            }
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
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
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct ScreenTimeDebugPanel: View {
    let authorizationStatusText: String
    let screenTimeMinutes: Double
    let screenTimeMaxMinutesSoFar: Double
    let screenTimeUpdatedAtText: String
    let readStatusText: String
    let appGroupReadSucceeded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screen Time デバッグ")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiTheme.textPrimary)

            MetricRow(title: "許可状態", value: localizedAuthorizationStatusText(authorizationStatusText))
            MetricRow(title: "共有分数", value: String(format: "%.1f分", screenTimeMinutes))
            MetricRow(title: "最大値", value: String(format: "%.1f分", screenTimeMaxMinutesSoFar))
            MetricRow(title: "最終更新", value: screenTimeUpdatedAtText)
            MetricRow(title: "App Group 読み取り", value: appGroupReadSucceeded ? "成功" : "失敗")
            MetricRow(title: "読み取り状態", value: readStatusText)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(GrowmiTheme.card)
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
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(GrowmiTheme.card)
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
