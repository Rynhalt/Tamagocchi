//
//  TamagocchiApp.swift
//  Tamagocchi
//
//  Created by Marcus Chang on 2026/04/18.
//

import SwiftUI
import SwiftData
import FamilyControls
import ManagedSettings

private let lifeformAppGroupID = "group.com.marcus.Growmi"
private let lifeformTimerEndDateKey = "LifeformWidgetTimerEndDate"
private let lifeformSelectionKey = "LifeformTimerSelectionData"

final class TimerShieldCoordinator {
    private let store = ManagedSettingsStore()
    private var task: Task<Void, Never>?

    func start() {
        guard task == nil else {
            return
        }

        task = Task { [weak self] in
            while !Task.isCancelled {
                await MainActor.run {
                    self?.syncShieldState()
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    @MainActor
    private func syncShieldState() {
        guard let defaults = UserDefaults(suiteName: lifeformAppGroupID),
              let endDate = defaults.object(forKey: lifeformTimerEndDateKey) as? Date,
              endDate > Date(),
              let selection = loadSelection(from: defaults) else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            return
        }

        store.shield.applications = selection.applicationTokens
        store.shield.applicationCategories = .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens
    }

    private func loadSelection(from defaults: UserDefaults) -> FamilyActivitySelection? {
        guard let data = defaults.data(forKey: lifeformSelectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }

        return selection
    }
}

@main
struct TamagocchiApp: App {
    private let timerShieldCoordinator = TimerShieldCoordinator()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        timerShieldCoordinator.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
