import Charts
import DeviceActivity
import SwiftUI

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

            return ActivitySummary(
                totalMinutes: totalActivityDuration / 60,
                segmentCount: segmentCount,
                categorySummaries: categorySummaries.values.sorted { $0.totalMinutes > $1.totalMinutes }
            )
        } catch {
            return ActivitySummary(
                totalMinutes: 0,
                segmentCount: 0,
                categorySummaries: []
            )
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
