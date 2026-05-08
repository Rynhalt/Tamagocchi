import Charts
import DeviceActivity
import Foundation
import os
import SwiftUI
import WidgetKit

private let lifeformAppGroupID = "group.com.marcus.Growmi"
private let lifeformScreenTimeMinutesKey = "LifeformScreenTimeMinutes"
private let lifeformScreenTimeUpdatedAtKey = "LifeformScreenTimeUpdatedAt"
private let screenTimeLogger = Logger(
    subsystem: "com.marcus.Tamagocchi",
    category: "ScreenTimeReportExtension"
)

private func persistTotalScreenTime(_ minutes: Double) {
    guard let defaults = UserDefaults(suiteName: lifeformAppGroupID) else {
        screenTimeLogger.error("Extension failed to open App Group defaults")
        return
    }

    let updatedAt = Date().timeIntervalSince1970
    screenTimeLogger.notice("Extension opened App Group defaults")
    defaults.set(minutes, forKey: lifeformScreenTimeMinutesKey)
    defaults.set(updatedAt, forKey: lifeformScreenTimeUpdatedAtKey)
    let rereadMinutes = defaults.double(forKey: lifeformScreenTimeMinutesKey)
    let rereadUpdatedAt = defaults.double(forKey: lifeformScreenTimeUpdatedAtKey)
    screenTimeLogger.notice("Extension wrote minutes: \(minutes, privacy: .public)")
    screenTimeLogger.notice("Extension wrote updatedAt: \(Date(timeIntervalSince1970: updatedAt), privacy: .public)")
    screenTimeLogger.notice("Extension reread minutes: \(rereadMinutes, privacy: .public)")
    screenTimeLogger.notice("Extension reread updatedAt: \(Date(timeIntervalSince1970: rereadUpdatedAt), privacy: .public)")
    WidgetCenter.shared.reloadTimelines(ofKind: "LifeformWidget")
    screenTimeLogger.notice("Extension requested widget timeline reload")
}

extension AsyncSequence {
    func collect() async throws -> [Element] {
        var elements: [Element] = []

        for try await element in self {
            elements.append(element)
        }

        return elements
    }
}

@main
struct TamagocchiReportExtension: DeviceActivityReportExtension {
    @DeviceActivityReportBuilder
    var body: some DeviceActivityReportScene {
        SummaryReportScene()
    }
}

extension DeviceActivityReport.Context {
    static let summary = Self("summary")
}

struct ActivitySummary: Hashable {
    let totalMinutes: Double
    let segmentCount: Int
    let categorySummaries: [CategorySummary]
}

struct CategorySummary: Hashable, Identifiable {
    let title: String
    var totalMinutes: Double
    var applicationCount: Int
    var webDomainCount: Int

    var id: String {
        title
    }
}

struct SummaryReportScene: DeviceActivityReportScene {
    typealias Configuration = ActivitySummary
    typealias Content = SummaryReportView

    let context: DeviceActivityReport.Context = .summary

    let content: (ActivitySummary) -> SummaryReportView = { configuration in
        SummaryReportView(summary: configuration)
    }

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivitySummary {
        do {
            var totalActivityDuration: TimeInterval = 0
            var segmentCount = 0
            var categorySummaries: [String: CategorySummary] = [:]

            let devices = try await data.collect()
            screenTimeLogger.notice("Extension devices: \(devices.count, privacy: .public)")

            for deviceData in devices {
                let segments = try await deviceData.activitySegments.collect()
                segmentCount += segments.count

                for segment in segments {
                    totalActivityDuration += segment.totalActivityDuration

                    let categories = try await segment.categories.collect()

                    for category in categories {
                        let title = String(describing: category.category)
                        let applicationCount = try await category.applications.collect().count
                        let webDomainCount = try await category.webDomains.collect().count
                        let totalMinutes = category.totalActivityDuration / 60

                        if var existing = categorySummaries[title] {
                            existing.totalMinutes += totalMinutes
                            existing.applicationCount += applicationCount
                            existing.webDomainCount += webDomainCount
                            categorySummaries[title] = existing
                        } else {
                            categorySummaries[title] = CategorySummary(
                                title: title,
                                totalMinutes: totalMinutes,
                                applicationCount: applicationCount,
                                webDomainCount: webDomainCount
                            )
                        }
                    }
                }
            }

            screenTimeLogger.notice("Extension segmentCount: \(segmentCount, privacy: .public)")
            screenTimeLogger.notice("Extension totalActivityDuration: \(totalActivityDuration, privacy: .public)")

            let summary = ActivitySummary(
                totalMinutes: totalActivityDuration / 60,
                segmentCount: segmentCount,
                categorySummaries: categorySummaries.values.sorted { $0.totalMinutes > $1.totalMinutes }
            )

            screenTimeLogger.notice("Extension totalMinutes: \(summary.totalMinutes, privacy: .public)")
            persistTotalScreenTime(summary.totalMinutes)
            return summary
        } catch {
            screenTimeLogger.error("Extension failed to compute summary: \(error.localizedDescription, privacy: .public)")
            let summary = ActivitySummary(
                totalMinutes: 0,
                segmentCount: 0,
                categorySummaries: []
            )

            screenTimeLogger.notice("Extension totalMinutes: \(summary.totalMinutes, privacy: .public)")
            persistTotalScreenTime(summary.totalMinutes)
            return summary
        }
    }
}

struct SummaryReportView: View {
    let summary: ActivitySummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Report loaded")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Summary")
                        .font(.subheadline.weight(.semibold))

                    Text("Segments: \(summary.segmentCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("Total minutes: \(summary.totalMinutes, specifier: "%.1f")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if summary.categorySummaries.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Use the selected apps during the chosen interval to see a report here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Chart(summary.categorySummaries) { category in
                        BarMark(
                            x: .value("Category", category.title),
                            y: .value("Minutes", category.totalMinutes)
                        )
                        .foregroundStyle(.blue)
                    }
                    .frame(height: 260)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category Breakdown")
                            .font(.subheadline.weight(.semibold))

                        ForEach(summary.categorySummaries) { category in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(category.title)
                                        .font(.footnote.weight(.semibold))
                                    Spacer()
                                    Text("\(category.totalMinutes, specifier: "%.1f") min")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Text("\(category.applicationCount) app entries, \(category.webDomainCount) web domain entries")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}
