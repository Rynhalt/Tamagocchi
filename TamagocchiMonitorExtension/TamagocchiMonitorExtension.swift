import DeviceActivity
import Foundation
import os
import WidgetKit

private let appGroupID = "group.com.marcus.Growmi"
private let approxScreenTimeMinutesKey = "GrowMiApproxScreenTimeMinutes"
private let digitalStrainLevelKey = "GrowMiDigitalStrainLevel"
private let digitalStrainUpdatedAtKey = "GrowMiDigitalStrainUpdatedAt"
private let lastThresholdEventKey = "GrowMiLastThresholdEvent"
private let monitorActivityName = DeviceActivityName("growmi.daily")
private let monitorLogger = Logger(
    subsystem: "com.marcus.Tamagocchi",
    category: "ScreenTimeMonitorExtension"
)

private func digitalStrainLevel(for minutes: Int) -> String {
    switch minutes {
    case 0..<30:
        return "calm"
    case 30..<60:
        return "mild"
    case 60..<120:
        return "strained"
    default:
        return "exhausted"
    }
}

private func persistApproximateScreenTime(minutes: Int, thresholdEvent: String) {
    guard let defaults = UserDefaults(suiteName: appGroupID) else {
        monitorLogger.error("Monitor failed to open App Group defaults")
        return
    }

    let existingMinutes = defaults.double(forKey: approxScreenTimeMinutesKey)
    let nextMinutes = max(existingMinutes, Double(minutes))
    guard nextMinutes >= existingMinutes else {
        monitorLogger.notice("Monitor kept existing minutes: \(existingMinutes, privacy: .public)")
        return
    }

    let updatedAt = Date().timeIntervalSince1970
    let level = digitalStrainLevel(for: Int(nextMinutes))

    defaults.set(nextMinutes, forKey: approxScreenTimeMinutesKey)
    defaults.set(level, forKey: digitalStrainLevelKey)
    defaults.set(updatedAt, forKey: digitalStrainUpdatedAtKey)
    defaults.set(thresholdEvent, forKey: lastThresholdEventKey)

    monitorLogger.notice("Monitor wrote minutes: \(Int(nextMinutes), privacy: .public)")
    monitorLogger.notice("Monitor wrote level: \(level, privacy: .public)")
    monitorLogger.notice("Monitor wrote updatedAt: \(Date(timeIntervalSince1970: updatedAt), privacy: .public)")
    monitorLogger.notice("Monitor wrote event: \(thresholdEvent, privacy: .public)")

    WidgetCenter.shared.reloadTimelines(ofKind: "LifeformWidget")
    monitorLogger.notice("Monitor requested widget timeline reload")
}

private func eventMinutes(from event: DeviceActivityEvent.Name) -> Int? {
    let rawValue = event.rawValue
    guard let lastComponent = rawValue.split(separator: ".").last,
          let minutes = Int(lastComponent) else {
        return nil
    }

    return minutes
}

private func isSameCalendarDay(_ lhs: Date, as rhs: Date = Date()) -> Bool {
    Calendar.current.isDate(lhs, inSameDayAs: rhs)
}

final class TamagocchiMonitorExtension: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        guard activity == monitorActivityName else {
            return
        }

        monitorLogger.notice("Monitor intervalDidStart for activity: \(activity.rawValue, privacy: .public)")

        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            monitorLogger.error("Monitor failed to open App Group defaults at interval start")
            return
        }

        let updatedAt = defaults.double(forKey: digitalStrainUpdatedAtKey)
        guard updatedAt > 0 else {
            monitorLogger.notice("Monitor interval start found no existing state")
            return
        }

        let lastUpdatedDate = Date(timeIntervalSince1970: updatedAt)
        guard !isSameCalendarDay(lastUpdatedDate) else {
            monitorLogger.notice("Monitor kept same-day state at interval start")
            return
        }

        defaults.removeObject(forKey: approxScreenTimeMinutesKey)
        defaults.removeObject(forKey: digitalStrainLevelKey)
        defaults.removeObject(forKey: lastThresholdEventKey)
        persistApproximateScreenTime(minutes: 0, thresholdEvent: "intervalDidStart-reset")
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity == monitorActivityName else {
            return
        }

        monitorLogger.notice("Monitor eventDidReachThreshold: \(event.rawValue, privacy: .public)")

        guard let minutes = eventMinutes(from: event) else {
            monitorLogger.error("Monitor could not parse threshold event: \(event.rawValue, privacy: .public)")
            return
        }

        persistApproximateScreenTime(minutes: minutes, thresholdEvent: event.rawValue)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)

        guard activity == monitorActivityName else {
            return
        }

        monitorLogger.notice("Monitor intervalDidEnd for activity: \(activity.rawValue, privacy: .public)")
    }
}
