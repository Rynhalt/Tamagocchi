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

struct LifeformWidgetStateSnapshot: Codable, Hashable {
    let authorizationStatusText: String
    let authorizationMessage: String
    let selectionMessage: String
    let selectedApps: Int
    let selectedCategories: Int
    let selectedWebDomains: Int
    let stepCount: Int
    let showReport: Bool

    static let placeholder = LifeformWidgetStateSnapshot(
        authorizationStatusText: "未確認",
        authorizationMessage: "データを待ってるよ",
        selectionMessage: "まだ何も選ばれてないよ",
        selectedApps: 0,
        selectedCategories: 0,
        selectedWebDomains: 0,
        stepCount: 0,
        showReport: false
    )

    var selectedItemCount: Int {
        selectedApps + selectedCategories + selectedWebDomains
    }

    var physicalScore: Double {
        min(1.0, Double(stepCount) / 10_000.0)
    }

    var digitalPenalty: Double {
        min(1.0, Double(selectedItemCount) / 10.0)
    }

    var digitalStatusText: String {
        switch (authorizationStatusText, selectedItemCount > 0) {
        case ("Approved", true):
            return "スマホ負担あり"
        case ("Approved", false):
            return "許可だけ済み"
        default:
            return "スクリーンタイム未許可"
        }
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
}

private struct LifeformWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: LifeformWidgetStateSnapshot
}

private struct LifeformWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LifeformWidgetEntry {
        LifeformWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (LifeformWidgetEntry) -> Void) {
        completion(LifeformWidgetEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LifeformWidgetEntry>) -> Void) {
        let entry = LifeformWidgetEntry(date: .now, snapshot: loadSnapshot())
        completion(Timeline(entries: [entry], policy: .never))
    }

    private func loadSnapshot() -> LifeformWidgetStateSnapshot {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
              let data = defaults.data(forKey: lifeformWidgetStateKey),
              let snapshot = try? JSONDecoder().decode(LifeformWidgetStateSnapshot.self, from: data) else {
            return .placeholder
        }

        return snapshot
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
        GrowmiWidgetTheme.background
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

    private var smallLayout: some View {
        VStack(spacing: 10) {
            Text("Growmi")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                cardBackground

                VStack(spacing: 8) {
                    GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .compact)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack(spacing: 6) {
                        Image(systemName: entry.snapshot.digitalPenalty >= 0.6 ? "leaf.slash" : "leaf.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(entry.snapshot.digitalPenalty >= 0.6 ? GrowmiWidgetTheme.warningRed : GrowmiWidgetTheme.leafGreen)

                        Text(entry.snapshot.moodText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
    }

    private var mediumLayout: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack {
                HStack {
                    Spacer()

                    Image("Green")
                        .resizable()
                        .scaledToFit()
                        .frame(width: width * 0.5, height: height)
                        .offset(x: +20, y: 0)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .white.opacity(0.02), location: 0.08),
                                    .init(color: .white.opacity(0.12), location: 0.14),
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
                                    .init(color: GrowmiWidgetTheme.backgroundBase, location: 0.0),
                                    .init(color: GrowmiWidgetTheme.backgroundBase.opacity(0.98), location: 0.30),
                                    .init(color: GrowmiWidgetTheme.backgroundBase.opacity(0.65), location: 0.62),
                                    .init(color: GrowmiWidgetTheme.backgroundBase.opacity(0.0), location: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: width * 0.14)
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
                .stroke(GrowmiWidgetTheme.debugBorder.opacity(0.6), style: StrokeStyle(
                        lineWidth: 1,
                        dash: [4, 4]
                    )
                )

                MediumScoreCard(snapshot: entry.snapshot)
                    .frame(width: width * 0.20)
                    .offset(x: -(width * 0.32), y: 5)

                VStack(alignment: .leading, spacing: height * 0.08) {
                    MediumStatRow(
                        iconName: "figure.walk",
                        iconColor: GrowmiWidgetTheme.primaryGreen,
                        iconSize: 20,
                        title: "歩数",
                        value: "\(entry.snapshot.stepCount)歩"
                    )
                    .offset(x: 5, y: -3)
                    MediumStatRow(
                        iconName: "clock",
                        iconColor: GrowmiWidgetTheme.warmOrange,
                        iconSize: 18,
                        title: "SNS利用時間",
                        value: "0分"
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

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日のGrowmi")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(GrowmiWidgetTheme.textPrimary)
                Spacer()
                Text(entry.snapshot.moodText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(entry.snapshot.digitalPenalty >= 0.6 ? GrowmiWidgetTheme.warningRed : GrowmiWidgetTheme.leafGreen)
            }

            ZStack {
                cardBackground

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 10) {
                        GrowmiCreatureView(snapshot: entry.snapshot, sizeMode: .large)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Text(creatureSummary)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(GrowmiWidgetTheme.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 10) {
                        MetricCard(
                            title: "運動状況",
                            value: "\(entry.snapshot.stepCount)",
                            detail: "目標の\(Int(entry.snapshot.physicalScore * 100))%",
                            ringProgress: entry.snapshot.physicalScore,
                            style: .growth
                        )

                        MetricCard(
                            title: "SNS疲れ",
                            value: strainDescriptor,
                            detail: "\(entry.snapshot.selectedItemCount)件えらばれてるよ",
                            ringProgress: entry.snapshot.digitalPenalty,
                            style: .strain
                        )

                        MetricCard(
                            title: "選択数",
                            value: "\(entry.snapshot.selectedItemCount)",
                            detail: "アプリ・カテゴリ・Webの合計",
                            ringProgress: min(1.0, Double(entry.snapshot.selectedItemCount) / 10.0),
                            style: .neutral
                        )
                    }
                    .frame(width: 132)
                }
                .padding(14)
            }
        }
        .padding(12)
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
}

private enum GrowmiCreatureSizeMode {
    case compact
    case medium
    case large
}

private struct GrowmiCreatureView: View {
    let snapshot: LifeformWidgetStateSnapshot
    let sizeMode: GrowmiCreatureSizeMode

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
        if snapshot.digitalPenalty > 0.7 {
            return Color(red: 0.50, green: 0.73, blue: 0.58)
        } else if snapshot.digitalPenalty > 0.35 {
            return Color(red: 0.55, green: 0.80, blue: 0.63)
        } else {
            return Color(red: 0.62, green: 0.83, blue: 0.67)
        }
    }

    private var creatureOpacity: Double {
        1.0 - (snapshot.digitalPenalty * 0.15)
    }

    private var accentColor: Color {
        snapshot.digitalPenalty >= 0.6 ? GrowmiWidgetTheme.warningRed : GrowmiWidgetTheme.accentGreen
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
                        colors: [
                            Color(red: 0.96, green: 0.99, blue: 0.98).opacity(0.95),
                            Color(red: 0.84, green: 0.94, blue: 0.96).opacity(0.60)
                        ],
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
                .fill(Color(red: 0.77, green: 0.88, blue: 0.74).opacity(0.20))
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
                    .fill(GrowmiWidgetTheme.leafGreen.opacity(0.7))
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
                            GrowmiWidgetTheme.primaryGreen,
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
                    .font(.system(size: 10, weight: .semibold))
                Text("のんびり")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(GrowmiWidgetTheme.primaryGreen)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(GrowmiWidgetTheme.primaryGreen.opacity(0.12))
            )
            .offset(y: 55)
        }
        .frame(width: 120, height: 100)
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
