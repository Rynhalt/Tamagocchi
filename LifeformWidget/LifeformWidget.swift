import AppIntents
import FamilyControls
import ManagedSettings
import SwiftUI
import WidgetKit

private enum GrowmiWidgetTheme {
    static let backgroundBase = Color(red: 0.972, green: 0.931, blue: 0.905)
    static let background = LinearGradient(
        colors: [
            backgroundBase,
            backgroundBase
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let card = Color.white.opacity(0.80)
    static let primaryGreen = Color(red: 0.34, green: 0.62, blue: 0.47)
    static let accentGreen = Color(red: 0.63, green: 0.82, blue: 0.70)
    static let leafGreen = Color(red: 0.47, green: 0.73, blue: 0.54)
    static let skyBlue = Color(red: 0.77, green: 0.89, blue: 0.96)
    static let warmOrange = Color(red: 0.92, green: 0.72, blue: 0.50)
    static let warningRed = Color(red: 0.84, green: 0.37, blue: 0.31)
    static let textPrimary = Color(red: 0.14, green: 0.19, blue: 0.16)
    static let textSecondary = Color(red: 0.40, green: 0.47, blue: 0.43)
    static let debugBorder = Color(red: 0.55, green: 0.78, blue: 0.66)
}

private let lifeformAppGroupID = "group.com.marcus.Growmi"
private let lifeformWidgetStateKey = "LifeformWidgetState"
private let lifeformTimerEndDateKey = "LifeformWidgetTimerEndDate"
private let lifeformTimerDurationKey = "LifeformWidgetTimerDurationMinutes"
private let lifeformSelectionKey = "LifeformTimerSelectionData"
private let lifeformScreenTimeMinutesKey = "GrowMiApproxScreenTimeMinutes"

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

enum CharacterKind: String, Codable {
    case green
    case blue
    case red

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
}

enum CustomItem: String, Codable, Hashable {
    case sunglasses
    case roundGlasses
    case squareGlasses

    var assetName: String {
        switch self {
        case .sunglasses:
            return "glasses_normal"
        case .roundGlasses:
            return "glasses_round"
        case .squareGlasses:
            return "glasses_square"
        }
    }
}

struct LifeformWidgetStateSnapshot: Codable, Hashable {
    let authorizationStatusText: String
    let authorizationMessage: String
    let selectionMessage: String
    let selectedApps: Int
    let selectedCategories: Int
    let selectedWebDomains: Int
    let stepCount: Int
    let showReport: Bool
    let selectedCharacter: CharacterKind
    let selectedCustomItem: CustomItem
    let screenTimeMinutes: Double

    init(
        authorizationStatusText: String,
        authorizationMessage: String,
        selectionMessage: String,
        selectedApps: Int,
        selectedCategories: Int,
        selectedWebDomains: Int,
        stepCount: Int,
        showReport: Bool,
        selectedCharacter: CharacterKind,
        selectedCustomItem: CustomItem = .sunglasses,
        screenTimeMinutes: Double = 0
    ) {
        self.authorizationStatusText = authorizationStatusText
        self.authorizationMessage = authorizationMessage
        self.selectionMessage = selectionMessage
        self.selectedApps = selectedApps
        self.selectedCategories = selectedCategories
        self.selectedWebDomains = selectedWebDomains
        self.stepCount = stepCount
        self.showReport = showReport
        self.selectedCharacter = selectedCharacter
        self.selectedCustomItem = selectedCustomItem
        self.screenTimeMinutes = screenTimeMinutes
    }

    enum CodingKeys: String, CodingKey {
        case authorizationStatusText
        case authorizationMessage
        case selectionMessage
        case selectedApps
        case selectedCategories
        case selectedWebDomains
        case stepCount
        case showReport
        case selectedCharacter
        case selectedCustomItem
        case screenTimeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            authorizationStatusText: try container.decode(String.self, forKey: .authorizationStatusText),
            authorizationMessage: try container.decode(String.self, forKey: .authorizationMessage),
            selectionMessage: try container.decode(String.self, forKey: .selectionMessage),
            selectedApps: try container.decode(Int.self, forKey: .selectedApps),
            selectedCategories: try container.decode(Int.self, forKey: .selectedCategories),
            selectedWebDomains: try container.decode(Int.self, forKey: .selectedWebDomains),
            stepCount: try container.decode(Int.self, forKey: .stepCount),
            showReport: try container.decode(Bool.self, forKey: .showReport),
            selectedCharacter: try container.decode(CharacterKind.self, forKey: .selectedCharacter),
            selectedCustomItem: try container.decodeIfPresent(CustomItem.self, forKey: .selectedCustomItem) ?? .sunglasses,
            screenTimeMinutes: try container.decodeIfPresent(Double.self, forKey: .screenTimeMinutes) ?? 0
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authorizationStatusText, forKey: .authorizationStatusText)
        try container.encode(authorizationMessage, forKey: .authorizationMessage)
        try container.encode(selectionMessage, forKey: .selectionMessage)
        try container.encode(selectedApps, forKey: .selectedApps)
        try container.encode(selectedCategories, forKey: .selectedCategories)
        try container.encode(selectedWebDomains, forKey: .selectedWebDomains)
        try container.encode(stepCount, forKey: .stepCount)
        try container.encode(showReport, forKey: .showReport)
        try container.encode(selectedCharacter, forKey: .selectedCharacter)
        try container.encode(selectedCustomItem, forKey: .selectedCustomItem)
        try container.encode(screenTimeMinutes, forKey: .screenTimeMinutes)
    }

    static let placeholder = LifeformWidgetStateSnapshot(
        authorizationStatusText: "未確認",
        authorizationMessage: "データを待ってるよ",
        selectionMessage: "まだ何も選ばれてないよ",
        selectedApps: 0,
        selectedCategories: 0,
        selectedWebDomains: 0,
        stepCount: 0,
        showReport: false,
        selectedCharacter: .blue,
        selectedCustomItem: .sunglasses,
        screenTimeMinutes: 0
    )

    var selectedItemCount: Int {
        selectedApps + selectedCategories + selectedWebDomains
    }

    var physicalScore: Double {
        min(1.0, Double(stepCount) / 10_000.0)
    }

    var digitalPenalty: Double {
        min(1.0, screenTimeMinutes / 240.0)
    }

    var digitalStatusText: String {
        switch (authorizationStatusText, screenTimeMinutes > 0) {
        case ("Approved", true):
            return "スマホ負担あり"
        case ("Approved", false):
            return "許可だけ済み"
        default:
            return "スクリーンタイム未許可"
        }
    }

    var screenTimeDisplayText: String {
        formattedScreenTime(minutes: screenTimeMinutes)
    }

    var physicalTag: String {
        if stepCount >= 10_000 {
            return "元気いっぱい"
        } else if stepCount >= 5_000 {
            return "目がさめてる"
        } else if stepCount > 0 {
            return "成長中"
        } else {
            return "休んでる"
        }
    }

    var moodText: String {
        if digitalPenalty >= 0.7 {
            return "ちょっと疲れ気味"
        } else if physicalScore >= 0.45 {
            return "成長中"
        } else {
            return "ひとやすみ"
        }
    }

    var overallScore: Int {
        let score = (physicalScore * 70.0) + ((1.0 - digitalPenalty) * 30.0)
        return Int(max(0, min(100, score)).rounded())
    }

    func updating(screenTimeMinutes: Double) -> LifeformWidgetStateSnapshot {
        LifeformWidgetStateSnapshot(
            authorizationStatusText: authorizationStatusText,
            authorizationMessage: authorizationMessage,
            selectionMessage: selectionMessage,
            selectedApps: selectedApps,
            selectedCategories: selectedCategories,
            selectedWebDomains: selectedWebDomains,
            stepCount: stepCount,
            showReport: showReport,
            selectedCharacter: selectedCharacter,
            selectedCustomItem: selectedCustomItem,
            screenTimeMinutes: screenTimeMinutes
        )
    }
}

private struct LifeformTimerState: Hashable {
    let durationMinutes: Int
    let endDate: Date?

    static let inactive = LifeformTimerState(durationMinutes: 0, endDate: nil)

    var isRunning: Bool {
        guard let endDate else {
            return false
        }
        return endDate > Date()
    }

    var remainingSeconds: Int {
        guard let endDate else {
            return 0
        }
        return max(0, Int(ceil(endDate.timeIntervalSinceNow)))
    }

    var remainingText: String {
        let seconds = remainingSeconds
        let minutes = seconds / 60
        let remainder = seconds % 60

        if minutes > 0 {
            return String(format: "%d:%02d", minutes, remainder)
        } else {
            return String(format: "0:%02d", remainder)
        }
    }

    var statusText: String {
        if isRunning {
            return "タイマー中"
        } else if durationMinutes > 0 {
            return "いつでも開始できるよ"
        } else {
            return "まだ始まってないよ"
        }
    }

    var progress: Double {
        guard durationMinutes > 0 else {
            return 0
        }
        let totalSeconds = Double(durationMinutes * 60)
        return max(0, min(1, 1 - (Double(remainingSeconds) / totalSeconds)))
    }

    var countdownRange: ClosedRange<Date>? {
        guard let endDate, isRunning else {
            return nil
        }

        return Date.now...endDate
    }
}

private enum LifeformTimerStore {
    static func load() -> LifeformTimerState {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID) else {
            return .inactive
        }

        let duration = defaults.integer(forKey: lifeformTimerDurationKey)
        let endDate = defaults.object(forKey: lifeformTimerEndDateKey) as? Date

        guard let endDate, endDate > Date() else {
            clear(in: defaults)
            return .inactive
        }

        return LifeformTimerState(durationMinutes: duration, endDate: endDate)
    }

    static func start(minutes: Int) {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID) else {
            return
        }

        let endDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        defaults.set(minutes, forKey: lifeformTimerDurationKey)
        defaults.set(endDate, forKey: lifeformTimerEndDateKey)
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID) else {
            return
        }

        clear(in: defaults)
    }

    private static func clear(in defaults: UserDefaults) {
        defaults.removeObject(forKey: lifeformTimerDurationKey)
        defaults.removeObject(forKey: lifeformTimerEndDateKey)
    }
}

private func startTimerSession(minutes: Int) {
    LifeformTimerStore.start(minutes: minutes)
    applyScreenTimeShieldIfPossible()
    WidgetCenter.shared.reloadTimelines(ofKind: "LifeformWidget")
}

private func applyScreenTimeShieldIfPossible() {
    guard let selection = loadSharedFamilyActivitySelection() else {
        return
    }

    let store = ManagedSettingsStore()
    store.shield.applications = selection.applicationTokens
    store.shield.applicationCategories = .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens
}

private func loadSharedFamilyActivitySelection() -> FamilyActivitySelection? {
    guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
          let data = defaults.data(forKey: lifeformSelectionKey),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
        return nil
    }

    return selection
}

struct StartTenMinuteTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "10分タイマー"
    static var description = IntentDescription("10分のタイマーを開始します。")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            startTimerSession(minutes: 10)
        }
        return .result()
    }
}

struct StartTwentyMinuteTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "20分タイマー"
    static var description = IntentDescription("20分のタイマーを開始します。")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            startTimerSession(minutes: 20)
        }
        return .result()
    }
}

struct StartThirtyMinuteTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "30分タイマー"
    static var description = IntentDescription("30分のタイマーを開始します。")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            startTimerSession(minutes: 30)
        }
        return .result()
    }
}

private struct CharacterPalette {
    let backgroundColors: [Color]
    let backgroundBase: Color
    let lineColor: Color
    let accentColor: Color
}

private struct CustomItemImage: View {
    let item: CustomItem

    var body: some View {
        Image(item.assetName)
            .resizable()
            .scaledToFit()
    }
}

private struct LifeformWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LifeformWidgetStateSnapshot
    let timerState: LifeformTimerState
}

private struct LifeformWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LifeformWidgetEntry {
        LifeformWidgetEntry(date: .now, snapshot: .placeholder, timerState: .inactive)
    }

    func getSnapshot(in context: Context, completion: @escaping (LifeformWidgetEntry) -> Void) {
        completion(LifeformWidgetEntry(date: .now, snapshot: loadSnapshot(), timerState: LifeformTimerStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeformWidgetEntry>) -> Void) {
        let timerState = LifeformTimerStore.load()
        let entry = LifeformWidgetEntry(date: .now, snapshot: loadSnapshot(), timerState: timerState)
        let policy: TimelineReloadPolicy = timerState.isRunning ? .after(Date().addingTimeInterval(1)) : .never
        completion(Timeline(entries: [entry], policy: policy))
    }

    private func loadSnapshot() -> LifeformWidgetStateSnapshot {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
              let data = defaults.data(forKey: lifeformWidgetStateKey),
              let snapshot = try? JSONDecoder().decode(LifeformWidgetStateSnapshot.self, from: data) else {
            return .placeholder
        }

        let screenTimeMinutes = defaults.double(forKey: lifeformScreenTimeMinutesKey)
        return snapshot.updating(screenTimeMinutes: screenTimeMinutes)
    }
}

@main
struct LifeformWidgetBundle: WidgetBundle {
    var body: some Widget {
        LifeformWidget()
    }
}

struct LifeformWidget: Widget {
    let kind = "LifeformWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LifeformWidgetProvider()) { entry in
            LifeformWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("ライフフォーム")
        .description("毎日のようすで育つ、ひとつの生きもの。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}

private struct LifeformWidgetEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: LifeformWidgetEntry

    var body: some View {
        ZStack {
            backgroundLayer

            switch widgetFamily {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            case .systemLarge:
                largeLayout
            default:
                mediumLayout
            }
        }
        .containerBackground(for: .widget) {
            backgroundLayer
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: palette.backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var currentCharacter: CharacterKind {
        entry.snapshot.selectedCharacter
    }

    private var characterImageName: String {
        switch currentCharacter {
        case .green:
            return "Green"
        case .blue:
            return "Blue"
        case .red:
            return "Red"
        }
    }

    private var palette: CharacterPalette {
        switch currentCharacter {
        case .green:
            return CharacterPalette(
                backgroundColors: [
                    Color(red: 0.972, green: 0.931, blue: 0.905),
                    Color(red: 0.952, green: 0.954, blue: 0.908)
                ],
                backgroundBase: Color(red: 0.972, green: 0.931, blue: 0.905),
                lineColor: Color(red: 0.55, green: 0.78, blue: 0.66),
                accentColor: GrowmiWidgetTheme.primaryGreen
            )
        case .blue:
            return CharacterPalette(
                backgroundColors: [
                    Color(red: 0.836, green: 0.900, blue: 0.943),
                    Color(red: 0.804, green: 0.878, blue: 0.931)
                ],
                backgroundBase: Color(red: 0.836, green: 0.900, blue: 0.943),
                lineColor: Color(red: 0.42, green: 0.65, blue: 0.87),
                accentColor: Color(red: 0.34, green: 0.62, blue: 0.92)
            )
        case .red:
            return CharacterPalette(
                backgroundColors: [
                    Color(red: 0.989, green: 0.878, blue: 0.800),
                    Color(red: 0.981, green: 0.846, blue: 0.760)
                ],
                backgroundBase: Color(red: 0.989, green: 0.878, blue: 0.800),
                lineColor: Color(red: 0.88, green: 0.54, blue: 0.66),
                accentColor: Color(red: 0.93, green: 0.55, blue: 0.72)
            )
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(GrowmiWidgetTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(GrowmiWidgetTheme.debugBorder.opacity(0.75), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
    }

    private enum CreatureSceneMode {
        case medium
        case large
    }

    private struct CreatureSceneView: View {
        let snapshot: LifeformWidgetStateSnapshot
        let characterImageName: String
        let palette: CharacterPalette
        let mode: CreatureSceneMode
        let strainDescriptor: String
        let creatureSummary: String
        let estimatedDistanceKilometers: Double

        var body: some View {
            switch mode {
            case .medium:
                mediumScene
            case .large:
                largeScene
            }
        }

        private var mediumScene: some View {
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height

                ZStack {
                    HStack {
                        Spacer()

                        ZStack(alignment: .top) {
                            Image(characterImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: width * 0.5, height: height)

                            CustomItemImage(item: snapshot.selectedCustomItem)
                                .frame(width: width * 0.13, height: width * 0.13)
                                .offset(
                                    x: snapshot.selectedCharacter.glassesPreviewOffset.width * 0.8,
                                    y: snapshot.selectedCharacter.glassesPreviewOffset.height * 1.12
                                )
                        }
                        .offset(x: +20, y: 0)
                        .mask {
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: .white.opacity(0.01), location: 0.10),
                                        .init(color: .white.opacity(0.10), location: 0.16),
                                        .init(color: .white.opacity(0.90), location: 0.22),
                                        .init(color: .white, location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                            .overlay(alignment: .leading) {
                                LinearGradient(
                                    stops: [
                                        .init(color: palette.backgroundBase, location: 0.0),
                                        .init(color: palette.backgroundBase.opacity(0.98), location: 0.30),
                                        .init(color: palette.backgroundBase.opacity(0.65), location: 0.62),
                                        .init(color: palette.backgroundBase.opacity(0.0), location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: width * 0.08)
                            }
                    }

                    Path { path in
                        let topInset = height * 0.9
                        let bottomInset = height * 0.9
                        let verticalX = width * 0.35
                        let horizontalStartX = verticalX + (width * 0.05)
                        let horizontalEndX = width * 0.6
                        let firstHorizontalY = height * 0.35
                        let secondHorizontalY = height * 0.65

                        path.move(to: CGPoint(x: verticalX, y: topInset))
                        path.addLine(to: CGPoint(x: verticalX, y: height - bottomInset))

                        path.move(to: CGPoint(x: horizontalStartX, y: firstHorizontalY))
                        path.addLine(to: CGPoint(x: horizontalEndX, y: firstHorizontalY))

                        path.move(to: CGPoint(x: horizontalStartX, y: secondHorizontalY))
                        path.addLine(to: CGPoint(x: horizontalEndX, y: secondHorizontalY))
                    }
                    .stroke(palette.lineColor.opacity(0.6), style: StrokeStyle(
                            lineWidth: 1,
                            dash: [4, 4]
                        )
                    )

                    MediumScoreCard(
                        snapshot: snapshot,
                        accentColor: palette.accentColor,
                        borderColor: palette.lineColor
                    )
                        .frame(width: width * 0.20)
                        .offset(x: -(width * 0.32), y: 5)

                    VStack(alignment: .leading, spacing: height * 0.08) {
                        MediumStatRow(
                            iconName: "figure.walk",
                            iconColor: GrowmiWidgetTheme.primaryGreen,
                            iconSize: 20,
                            title: "歩数",
                            value: "\(snapshot.stepCount)歩"
                        )
                        .offset(x: 5, y: -3)
                        MediumStatRow(
                            iconName: "clock",
                            iconColor: GrowmiWidgetTheme.warmOrange,
                            iconSize: 18,
                            title: "SNS利用時間",
                            value: snapshot.screenTimeDisplayText
                        )
                            .offset(x: 5, y: 0)
                        MediumStatRow(
                            iconName: "heart.fill",
                            iconColor: Color(red: 0.93, green: 0.55, blue: 0.72),
                            iconSize: 18,
                            title: "すれ違い",
                            value: "0人"
                        )
                            .offset(x: 5, y: 5)
                    }
                    .frame(width: width * 0.30, alignment: .leading)
                    .offset(x: width * 0.02, y: 0)
                }
            }
        }

        private var largeScene: some View {
            GeometryReader { geometry in
                VStack(spacing: 6) {
                    ZStack(alignment: .topLeading) {
                        Color.clear

                        MediumScoreCard(
                            snapshot: snapshot,
                            accentColor: palette.accentColor,
                            borderColor: palette.lineColor
                        )
                            .frame(width: geometry.size.width * 0.5)
                            .offset(x: 0, y: 60)
                            .zIndex(1)
                            .scaleEffect(1.4)

                    ZStack(alignment: .top) {
                        Image(characterImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.75)

                        CustomItemImage(item: snapshot.selectedCustomItem)
                            .frame(width: geometry.size.width * 0.19, height: geometry.size.width * 0.19)
                            .offset(
                                x: snapshot.selectedCharacter.glassesPreviewOffset.width * 1.2,
                                y: snapshot.selectedCharacter.glassesPreviewOffset.height * 1.58
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 40, y: 5)
                    .mask {
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0.0),
                                        .init(color: .white.opacity(0.0), location: 0.12),
                                        .init(color: .white.opacity(0.08), location: 0.20),
                                        .init(color: .white.opacity(0.72), location: 0.34),
                                        .init(color: .white, location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                            .overlay(alignment: .leading) {
                                LinearGradient(
                                    stops: [
                                        .init(color: palette.backgroundBase, location: 0.0),
                                        .init(color: palette.backgroundBase.opacity(1.0), location: 0.52),
                                        .init(color: palette.backgroundBase.opacity(0.88), location: 0.74),
                                        .init(color: palette.backgroundBase.opacity(0.0), location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: geometry.size.width * 0.22)
                            }
                            .overlay(alignment: .bottom) {
                                LinearGradient(
                                    stops: [
                                        .init(color: palette.backgroundBase.opacity(0.0), location: 0.0),
                                        .init(color: palette.backgroundBase.opacity(0.16), location: 0.78),
                                        .init(color: palette.backgroundBase.opacity(0.50), location: 0.93),
                                        .init(color: palette.backgroundBase.opacity(0.76), location: 1.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: geometry.size.height * 0.055)
                            }

                        LinearGradient(
                            stops: [
                                .init(color: palette.backgroundBase, location: 0.0),
                                .init(color: palette.backgroundBase.opacity(1.0), location: 0.52),
                                .init(color: palette.backgroundBase.opacity(0.62), location: 0.80),
                                .init(color: palette.backgroundBase.opacity(0.0), location: 1.0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.23, height: geometry.size.height * 0.62)
                        .offset(x: geometry.size.width * 0.27, y: geometry.size.height * 0.08)
                        .zIndex(0.5)
                        .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: geometry.size.width * 0.03),
                            GridItem(.flexible(), spacing: geometry.size.width * 0.03)
                        ],
                        spacing: 6
                    ) {
                        LargePillCard(borderColor: palette.lineColor, fillColor: palette.backgroundBase) {
                            MediumStatRow(
                                iconName: "figure.walk",
                                iconColor: GrowmiWidgetTheme.primaryGreen,
                                iconSize: 20,
                                title: "歩数",
                                value: "\(snapshot.stepCount.formatted())歩"
                            )
                        }

                        LargePillCard(borderColor: palette.lineColor, fillColor: palette.backgroundBase) {
                            MediumStatRow(
                                iconName: "clock",
                                iconColor: GrowmiWidgetTheme.warmOrange,
                                iconSize: 17,
                                title: "SNS利用時間",
                                value: snapshot.screenTimeDisplayText
                            )
                        }

                        LargePillCard(borderColor: palette.lineColor, fillColor: palette.backgroundBase) {
                            MediumStatRow(
                                iconName: "heart.fill",
                                iconColor: Color(red: 0.93, green: 0.55, blue: 0.72),
                                iconSize: 17,
                                title: "すれ違い",
                                value: "0人"
                            )
                        }

                        LargePillCard(borderColor: palette.lineColor, fillColor: palette.backgroundBase) {
                            MediumStatRow(
                                iconName: "shoeprints.fill",
                                iconColor: Color(red: 0.31, green: 0.58, blue: 0.96),
                                iconSize: 16,
                                title: "移動距離",
                                value: "\(estimatedDistanceKilometers.formatted(.number.precision(.fractionLength(1))))km"
                            )
                        }
                    }
                    .frame(maxWidth: geometry.size.width * 0.88)
                    .offset(y: -15)
                }
            }
        }
    }

    private var smallLayout: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.backgroundBase.opacity(0.98),
                            palette.backgroundColors.last ?? palette.backgroundBase
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(palette.lineColor.opacity(0.35), lineWidth: 1)
                )

            if entry.timerState.isRunning {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(palette.lineColor.opacity(0.24), lineWidth: 10)

                        Circle()
                            .trim(from: 0, to: entry.timerState.progress)
                            .stroke(
                                AngularGradient(
                                    colors: [
                                        palette.accentColor,
                                        palette.lineColor,
                                        palette.accentColor.opacity(0.82)
                                    ],
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        Group {
                            if let interval = entry.timerState.countdownRange {
                                Text(timerInterval: interval, countsDown: true)
                            } else {
                                Text("0:00")
                            }
                        }
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 84, height: 84, alignment: .center)
                    }
                    .frame(width: 118, height: 118)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(12)
            } else {
                VStack(spacing: 8) {
                    Spacer(minLength: 0)

                    VStack(spacing: 8) {
                        timerButton(title: "10分", intent: StartTenMinuteTimerIntent())
                        timerButton(title: "20分", intent: StartTwentyMinuteTimerIntent())
                        timerButton(title: "30分", intent: StartThirtyMinuteTimerIntent())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
                .padding(.top, 6)
            }
        }
    }

    @ViewBuilder
    private func timerButton<Intent: AppIntent>(title: String, intent: Intent) -> some View {
        Button(intent: intent) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.62))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(palette.lineColor.opacity(0.30), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var mediumLayout: some View {
        CreatureSceneView(
            snapshot: entry.snapshot,
            characterImageName: characterImageName,
            palette: palette,
            mode: .medium,
            strainDescriptor: strainDescriptor,
            creatureSummary: creatureSummary,
            estimatedDistanceKilometers: estimatedDistanceKilometers
        )
    }

    private var largeLayout: some View {
        CreatureSceneView(
            snapshot: entry.snapshot,
            characterImageName: characterImageName,
            palette: palette,
            mode: .large,
            strainDescriptor: strainDescriptor,
            creatureSummary: creatureSummary,
            estimatedDistanceKilometers: estimatedDistanceKilometers
        )
    }

    private var blueSmallLayout: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.34), lineWidth: 1)
                )
                .padding(14)

            VStack(spacing: 8) {
                Text("Blue")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.20, green: 0.39, blue: 0.58))

                GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .compact, characterKind: .blue)

                Text(entry.snapshot.moodText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textSecondary)
            }
            .padding(.vertical, 12)
        }
    }

    private var redSmallLayout: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.24))
                .frame(width: 128, height: 128)
                .blur(radius: 2)

            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("Red")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.71, green: 0.28, blue: 0.46))

                GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .compact, characterKind: .red)
                    .scaleEffect(0.95)

                Capsule()
                    .fill(Color.white.opacity(0.62))
                    .frame(width: 72, height: 22)
                    .overlay {
                        Text("\(entry.snapshot.overallScore)%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.71, green: 0.28, blue: 0.46))
                    }
            }
            .padding(.vertical, 10)
        }
    }

    private var blueMediumLayout: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Blue")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.20, green: 0.39, blue: 0.58))

                MetricCard(
                    title: "歩数",
                    value: "\(entry.snapshot.stepCount.formatted())歩",
                    detail: entry.snapshot.physicalTag,
                    ringProgress: entry.snapshot.physicalScore,
                    style: .growth
                )

                MetricCard(
                    title: "SNS負担",
                    value: strainDescriptor,
                    detail: creatureSummary,
                    ringProgress: 1.0 - entry.snapshot.digitalPenalty,
                    style: .neutral
                )
            }

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.white.opacity(0.24))
                GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .medium, characterKind: .blue)
                    .offset(y: -4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(16)
    }

    private var redMediumLayout: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Red")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.71, green: 0.28, blue: 0.46))
                    Text("きょうのごきげん")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                }
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.58))
                    .frame(width: 64, height: 28)
                    .overlay {
                        Text("\(entry.snapshot.overallScore)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.71, green: 0.28, blue: 0.46))
                    }
            }

            HStack(spacing: 10) {
                GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .medium, characterKind: .red)
                    .frame(width: 118, height: 118)

                VStack(spacing: 8) {
                    MetricCard(
                        title: "歩数",
                        value: "\(entry.snapshot.stepCount.formatted())歩",
                        detail: "移動距離 \(estimatedDistanceKilometers.formatted(.number.precision(.fractionLength(1))))km",
                        ringProgress: entry.snapshot.physicalScore,
                        style: .growth
                    )

                    MetricCard(
                        title: "ムード",
                        value: entry.snapshot.moodText,
                        detail: entry.snapshot.digitalStatusText,
                        ringProgress: 1.0 - (entry.snapshot.digitalPenalty * 0.6),
                        style: .strain
                    )
                }
            }
        }
        .padding(16)
    }

    private var blueLargeLayout: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Blue")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.20, green: 0.39, blue: 0.58))
                    Text("クールに成長を追うタイプ")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                }
                Spacer()
                MediumScoreCard(snapshot: entry.snapshot)
                    .frame(width: 92)
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.white.opacity(0.24))
                    GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .large, characterKind: .blue)
                        .scaleEffect(1.05)
                }

                VStack(spacing: 8) {
                    MetricCard(
                        title: "歩数",
                        value: "\(entry.snapshot.stepCount.formatted())歩",
                        detail: entry.snapshot.physicalTag,
                        ringProgress: entry.snapshot.physicalScore,
                        style: .growth
                    )

                    MetricCard(
                        title: "デジタル負担",
                        value: strainDescriptor,
                        detail: entry.snapshot.digitalStatusText,
                        ringProgress: 1.0 - entry.snapshot.digitalPenalty,
                        style: .neutral
                    )

                    MetricCard(
                        title: "移動距離",
                        value: "\(estimatedDistanceKilometers.formatted(.number.precision(.fractionLength(1))))km",
                        detail: creatureSummary,
                        ringProgress: min(1.0, estimatedDistanceKilometers / 8.0),
                        style: .growth
                    )
                }
            }
        }
        .padding(16)
    }

    private var redLargeLayout: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Red")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.71, green: 0.28, blue: 0.46))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(entry.snapshot.moodText)
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.71, green: 0.28, blue: 0.46))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.58)))
            }

            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color.white.opacity(0.18))

                GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .large, characterKind: .red)
                    .scaleEffect(1.08)
                    .offset(x: -8, y: -4)

                VStack(spacing: 8) {
                    LargePillCard {
                        MediumStatRow(
                            iconName: "figure.walk",
                            iconColor: GrowmiWidgetTheme.primaryGreen,
                            iconSize: 18,
                            title: "歩数",
                            value: "\(entry.snapshot.stepCount.formatted())歩"
                        )
                    }

                    LargePillCard {
                        MediumStatRow(
                            iconName: "heart.fill",
                            iconColor: Color(red: 0.93, green: 0.55, blue: 0.72),
                            iconSize: 17,
                            title: "ムード",
                            value: entry.snapshot.moodText
                        )
                    }
                }
                .frame(width: 150)
                .padding(12)
            }

            HStack(spacing: 8) {
                MetricCard(
                    title: "成長",
                    value: entry.snapshot.physicalTag,
                    detail: creatureSummary,
                    ringProgress: entry.snapshot.physicalScore,
                    style: .growth
                )

                MetricCard(
                    title: "バランス",
                    value: "\(entry.snapshot.overallScore)",
                    detail: entry.snapshot.digitalStatusText,
                    ringProgress: Double(entry.snapshot.overallScore) / 100.0,
                    style: .strain
                )
            }
        }
        .padding(16)
    }

    private var strainDescriptor: String {
        switch entry.snapshot.digitalPenalty {
        case 0.0..<0.25:
            return "ひかえめ"
        case 0.25..<0.6:
            return "ふつう"
        default:
            return "つよめ"
        }
    }

    private var creatureSummary: String {
        if entry.snapshot.digitalPenalty >= 0.7 {
            return "歩くと助かるけど、スマホ負担が少し強めだよ。"
        } else if entry.snapshot.physicalScore >= 0.5 {
            return "今日の歩きで、Growmiはちょっと元気。"
        } else {
            return "Growmiは自然が大好き!"
        }
    }

    private var estimatedDistanceKilometers: Double {
        Double(entry.snapshot.stepCount) * 0.0007
    }

}

private enum GrowmiCreatureSizeMode {
    case compact
    case medium
    case large
}

private struct GrowmiCreatureView: View {
    let snapshot: LifeformWidgetStateSnapshot
    let sizeMode: GrowmiCreatureSizeMode
    let characterKind: CharacterKind

    private var physicalScale: CGFloat {
        let base = 0.82 + CGFloat(snapshot.physicalScore) * 0.30
        switch sizeMode {
        case .compact:
            return base * 0.88
        case .medium:
            return base
        case .large:
            return base * 1.10
        }
    }

    private var creatureColor: Color {
        switch characterKind {
        case .green:
            if snapshot.digitalPenalty > 0.7 {
                return Color(red: 0.50, green: 0.73, blue: 0.58)
            } else if snapshot.digitalPenalty > 0.35 {
                return Color(red: 0.55, green: 0.80, blue: 0.63)
            } else {
                return Color(red: 0.62, green: 0.83, blue: 0.67)
            }
        case .blue:
            if snapshot.digitalPenalty > 0.7 {
                return Color(red: 0.43, green: 0.63, blue: 0.76)
            } else if snapshot.digitalPenalty > 0.35 {
                return Color(red: 0.47, green: 0.70, blue: 0.84)
            } else {
                return Color(red: 0.59, green: 0.79, blue: 0.91)
            }
        case .red:
            if snapshot.digitalPenalty > 0.7 {
                return Color(red: 0.77, green: 0.49, blue: 0.61)
            } else if snapshot.digitalPenalty > 0.35 {
                return Color(red: 0.88, green: 0.58, blue: 0.70)
            } else {
                return Color(red: 0.95, green: 0.69, blue: 0.78)
            }
        }
    }

    private var creatureOpacity: Double {
        1.0 - (snapshot.digitalPenalty * 0.15)
    }

    private var accentColor: Color {
        if snapshot.digitalPenalty >= 0.6 {
            return GrowmiWidgetTheme.warningRed
        }

        switch characterKind {
        case .green:
            return GrowmiWidgetTheme.accentGreen
        case .blue:
            return Color(red: 0.34, green: 0.62, blue: 0.92)
        case .red:
            return Color(red: 0.93, green: 0.55, blue: 0.72)
        }
    }

    private var haloColors: [Color] {
        switch characterKind {
        case .green:
            return [
                Color(red: 0.96, green: 0.99, blue: 0.98).opacity(0.95),
                Color(red: 0.84, green: 0.94, blue: 0.96).opacity(0.60)
            ]
        case .blue:
            return [
                Color(red: 0.95, green: 0.98, blue: 1.0).opacity(0.98),
                Color(red: 0.74, green: 0.88, blue: 0.98).opacity(0.66)
            ]
        case .red:
            return [
                Color(red: 1.0, green: 0.96, blue: 0.98).opacity(0.98),
                Color(red: 0.98, green: 0.82, blue: 0.90).opacity(0.70)
            ]
        }
    }

    private var basePlateColor: Color {
        switch characterKind {
        case .green:
            return Color(red: 0.77, green: 0.88, blue: 0.74).opacity(0.20)
        case .blue:
            return Color(red: 0.71, green: 0.83, blue: 0.96).opacity(0.24)
        case .red:
            return Color(red: 0.96, green: 0.75, blue: 0.84).opacity(0.24)
        }
    }

    private var damageCount: Int {
        if snapshot.digitalPenalty < 0.25 {
            return 0
        } else if snapshot.digitalPenalty < 0.6 {
            return 2
        } else {
            return 4
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: haloColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 112, height: 112)
                .overlay(
                    Circle()
                        .stroke(GrowmiWidgetTheme.skyBlue.opacity(0.75), lineWidth: 1)
                )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(basePlateColor)
                .frame(width: 72, height: 28)
                .offset(y: 28)

            Capsule()
                .fill(creatureColor.opacity(creatureOpacity))
                .frame(width: 44, height: 58)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: creatureColor.opacity(0.18), radius: 8, y: 4)
                .scaleEffect(physicalScale)

            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 8, height: 8)
                .offset(x: -8, y: -10)

            Circle()
                .fill(.white.opacity(0.92))
                .frame(width: 8, height: 8)
                .offset(x: 8, y: -10)

            if snapshot.physicalScore > 0.45 {
                Circle()
                    .fill(accentColor.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .offset(x: 14, y: -26)
            }

            ForEach(0..<damageCount, id: \.self) { index in
                DamageMark(
                    color: accentColor.opacity(0.58),
                    length: 18 - CGFloat(index) * 2
                )
                .rotationEffect(.degrees(Double(index) * 22 - 18))
                .offset(x: CGFloat(index - 1) * 10, y: CGFloat(index) * 3 - 4)
            }

            VStack(spacing: 2) {
                Text(snapshot.physicalTag)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textPrimary)

                Text(snapshot.digitalStatusText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .offset(y: 44)
        }
        .frame(width: 112, height: 112)
    }
}

private struct MetricCard: View {
    enum Style {
        case growth
        case strain
        case neutral
    }

    let title: String
    let value: String
    let detail: String
    let ringProgress: Double
    let style: Style

    private var accentColor: Color {
        switch style {
        case .growth:
            return GrowmiWidgetTheme.primaryGreen
        case .strain:
            return GrowmiWidgetTheme.warningRed
        case .neutral:
            return GrowmiWidgetTheme.warmOrange
        }
    }

    private var ringGradient: [Color] {
        switch style {
        case .growth:
            return [
                Color(red: 0.79, green: 0.92, blue: 0.80),
                Color(red: 0.44, green: 0.77, blue: 0.57)
            ]
        case .strain:
            return [
                Color(red: 0.98, green: 0.88, blue: 0.84),
                Color(red: 0.90, green: 0.56, blue: 0.48)
            ]
        case .neutral:
            return [
                Color(red: 0.96, green: 0.92, blue: 0.84),
                Color(red: 0.92, green: 0.76, blue: 0.53)
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.black.opacity(0.05), lineWidth: 6)

                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(1, ringProgress))))
                        .stroke(
                            AngularGradient(
                                colors: ringGradient,
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 14, height: 14)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                        .lineLimit(1)

                    Text(value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
            }

            Text(detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(GrowmiWidgetTheme.card.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GrowmiWidgetTheme.debugBorder.opacity(0.55), lineWidth: 1)
        )
    }
}

private struct MediumStatRow: View {
    let iconName: String
    let iconColor: Color
    let iconSize: CGFloat
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textSecondary)

                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

private struct MediumScoreCard: View {
    let snapshot: LifeformWidgetStateSnapshot
    let accentColor: Color
    let borderColor: Color

    init(
        snapshot: LifeformWidgetStateSnapshot,
        accentColor: Color = GrowmiWidgetTheme.primaryGreen,
        borderColor: Color = GrowmiWidgetTheme.debugBorder
    ) {
        self.snapshot = snapshot
        self.accentColor = accentColor
        self.borderColor = borderColor
    }

    private var normalizedScore: Double {
        Double(snapshot.overallScore) / 100.0
    }

    var body: some View {
        ZStack {
            
            OpenCircleArc()
                .stroke(Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 8, lineCap: .round))

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
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )

            Text("今日のスコア")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                .offset(y: -63)

            Image(systemName: "sun.max.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(GrowmiWidgetTheme.warmOrange)
                .offset(y: -25)

            VStack(spacing: 2) {
                Text("\(snapshot.overallScore)")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                Text("/100")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                    .offset(y: -5)
            }
            .offset(y: 6)

            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 9, weight: .semibold))
                Text("のんびり")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(accentColor.opacity(0.12))
            )
            .offset(y: 55)
        }
        .frame(width: 120, height: 100)
    }
}

private struct LargePillCard<Content: View>: View {
    let borderColor: Color
    let fillColor: Color
    let content: Content

    init(
        borderColor: Color = GrowmiWidgetTheme.debugBorder,
        fillColor: Color = GrowmiWidgetTheme.backgroundBase,
        @ViewBuilder content: () -> Content
    ) {
        self.borderColor = borderColor
        self.fillColor = fillColor
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 20)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 50, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fillColor.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        borderColor.opacity(0.6),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                    )
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
        let radius = (min(rect.width, rect.height) / 2) - 6
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

private struct DamageMark: View {
    let color: Color
    let length: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: length, height: 2)
    }
}
