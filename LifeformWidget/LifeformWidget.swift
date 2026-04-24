import WidgetKit
import SwiftUI

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
        authorizationStatusText: "Not Determined",
        authorizationMessage: "Waiting for data.",
        selectionMessage: "No activity selected yet.",
        selectedApps: 0,
        selectedCategories: 0,
        selectedWebDomains: 0,
        stepCount: 0,
        showReport: false
    )

    var selectedItemCount: Int {
        selectedApps + selectedCategories + selectedWebDomains
    }

    var hasScreenTimeSelection: Bool {
        selectedItemCount > 0
    }

    var physicalLevel: Double {
        Double(stepCount)
    }

    var physicalTag: String {
        if stepCount >= 10_000 {
            return "charged"
        } else if stepCount >= 5_000 {
            return "awake"
        } else if stepCount > 0 {
            return "growing"
        } else {
            return "dormant"
        }
    }

    var digitalStatusText: String {
        switch (authorizationStatusText, hasScreenTimeSelection) {
        case ("Approved", true):
            return "influence active"
        case ("Approved", false):
            return "authorized, unselected"
        default:
            return "screen time locked"
        }
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
        .configurationDisplayName("Lifeform")
        .description("A single evolving creature that reflects behavior.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
            colors: [
                Color(red: 0.06, green: 0.08, blue: 0.07),
                Color(red: 0.12, green: 0.16, blue: 0.12),
                Color(red: 0.18, green: 0.23, blue: 0.17)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderColor: Color {
        Color(red: 0.62, green: 0.86, blue: 0.74)
    }

    private var physicalScale: CGFloat {
        let level = min(max(entry.snapshot.physicalLevel / 12_000, 0), 1)
        return 0.78 + CGFloat(level) * 0.34
    }

    private var smallLayout: some View {
        VStack {
            LifeformCreature(snapshot: entry.snapshot)
                .scaleEffect(physicalScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(borderColor.opacity(0.8))
        }
        .padding(10)
        .border(borderColor.opacity(0.5))
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 10) {
            LifeformCreature(snapshot: entry.snapshot)
                .scaleEffect(physicalScale)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(borderColor.opacity(0.8))

            VStack(alignment: .leading, spacing: 8) {
                MetricBadge(title: "Steps", value: "\(entry.snapshot.stepCount)")
                MetricBadge(title: "Digital", value: entry.snapshot.digitalStatusText)
                MetricBadge(title: "Selection", value: "\(entry.snapshot.selectedItemCount)")
            }
            .frame(width: 94, alignment: .leading)
            .border(borderColor.opacity(0.8))
        }
        .padding(10)
        .border(borderColor.opacity(0.5))
    }

    private var largeLayout: some View {
        HStack(alignment: .center, spacing: 12) {
            LifeformCreature(snapshot: entry.snapshot)
                .scaleEffect(physicalScale * 1.14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(borderColor.opacity(0.8))

            VStack(alignment: .leading, spacing: 10) {
                Text("Lifeform")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .border(borderColor.opacity(0.8))

                MetricBadge(title: "Authorization", value: entry.snapshot.authorizationStatusText)
                MetricBadge(title: "Selection", value: entry.snapshot.selectionMessage)
                MetricBadge(title: "Steps", value: "\(entry.snapshot.stepCount) today")
                MetricBadge(title: "Physical", value: entry.snapshot.physicalTag)
                MetricBadge(title: "Digital", value: entry.snapshot.digitalStatusText)
            }
            .frame(width: 130, alignment: .leading)
            .border(borderColor.opacity(0.8))
        }
        .padding(12)
        .border(borderColor.opacity(0.5))
    }
}

private struct LifeformCreature: View {
    let snapshot: LifeformWidgetStateSnapshot

    private var creatureColor: Color {
        if snapshot.selectedItemCount > 0 {
            return Color(red: 0.45, green: 0.82, blue: 0.68)
        } else if snapshot.stepCount > 0 {
            return Color(red: 0.69, green: 0.82, blue: 0.56)
        } else {
            return Color(red: 0.72, green: 0.72, blue: 0.68)
        }
    }

    private var glowColor: Color {
        snapshot.selectedItemCount > 0
            ? Color(red: 0.52, green: 0.92, blue: 0.78).opacity(0.35)
            : Color.black.opacity(0.18)
    }

    private var coreHeight: CGFloat {
        let normalized = min(max(snapshot.physicalLevel / 12_000, 0), 1)
        return 76 + CGFloat(normalized) * 22
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .fill(glowColor)
                    .frame(width: size * 0.86, height: size * 0.86)
                    .blur(radius: 14)

                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(creatureColor.opacity(0.25))
                    .frame(width: size * 0.66, height: coreHeight)
                    .offset(y: size * 0.1)

                Capsule()
                    .fill(creatureColor)
                    .frame(width: size * 0.42, height: coreHeight)
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: creatureColor.opacity(0.3), radius: 12, y: 8)

                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: -size * 0.08, y: -size * 0.03)

                Circle()
                    .fill(.white.opacity(0.9))
                    .frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: size * 0.08, y: -size * 0.03)

                if snapshot.selectedItemCount > 0 {
                    Circle()
                        .fill(Color(red: 0.22, green: 0.72, blue: 0.62).opacity(0.85))
                        .frame(width: size * 0.13, height: size * 0.13)
                        .offset(x: size * 0.2, y: -size * 0.16)
                        .shadow(color: .white.opacity(0.2), radius: 4)
                }

                if snapshot.stepCount > 0 {
                    Ellipse()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: size * 0.18, height: size * 0.08)
                        .offset(x: -size * 0.16, y: size * 0.18)
                }

                VStack(spacing: 4) {
                    Text(snapshot.physicalTag)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(snapshot.digitalStatusText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                }
                .offset(y: size * 0.24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct MetricBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.65))
                .border(Color.white.opacity(0.35))

            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .border(Color.white.opacity(0.35))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(red: 0.62, green: 0.86, blue: 0.74).opacity(0.7), lineWidth: 1)
        )
    }
}
