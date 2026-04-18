# Tamagocchi Design Framework

## 1. Purpose

This document defines the technical plan for evolving the current starter SwiftUI/SwiftData app into the core Lifeform experience described in `README.md`.

The app should:
- Represent one evolving creature per user.
- Convert real-world signals into latent traits.
- Persist creature state, history, and authorization state.
- Keep the UI passive and interpretive rather than game-like.

## 2. Current State

The codebase currently contains:
- A minimal `SwiftUI` app entry point.
- A placeholder `Item` model stored in `SwiftData`.
- A starter `ContentView` that lists and inserts timestamped rows.

That is enough for local persistence, but not enough for the product concept. The next step is to replace the placeholder data model with domain models and services that reflect creature state and sensor-driven inputs.

## 3. Product Goals

### Core goals
- One lifeform, never a collection.
- Passive progression from real-world behavior.
- Clear state changes without exposing noisy raw metrics.
- Privacy-aware data handling.
- Minimal interaction and low notification pressure.

### Non-goals
- No social feed.
- No gacha or collection loop.
- No explicit optimization dashboard.
- No continuous foreground tracking if a lower-power system API is sufficient.

## 4. Recommended Architecture

Use a layered architecture with explicit protocol boundaries.

### Layers
1. Presentation layer
   - SwiftUI screens and view models.
   - Shows creature state, history, and permission prompts.

2. Domain layer
   - Trait calculation.
   - Evolution logic.
   - Serendipity and mutation rules.
   - Input normalization.

3. Infrastructure layer
   - HealthKit, CoreLocation, FamilyControls, DeviceActivity, and optional Bluetooth integration.
   - Persistence using SwiftData.
   - Background refresh and authorization management.

4. Platform layer
   - Actual Apple frameworks and entitlements.
   - Request/response wrappers around system APIs.

## 5. Proposed Data Model

Replace the placeholder `Item` model with domain entities that describe the creature and its history.

### Models
- `LifeformProfile`
  - Stable identity for the user's single creature.
  - Holds species seed, name, birth date, and visual archetype.

- `TraitSnapshot`
  - One normalized set of trait values for a given time window.
  - Fields: `physical`, `social`, `exploration`, `digital`.

- `LifeformState`
  - Derived visible state for the current creature form.
  - Fields: size, vitality, mutation flags, morphology tags, rarity score.

- `ActivitySample`
  - Abstracted event from sensors or APIs.
  - Fields: source, timestamp, value, confidence, context.

- `LocationVisit`
  - Normalized place event from Core Location.
  - Fields: coordinate summary, novelty score, duration, repeat count.

- `AuthorizationState`
  - Tracks access for HealthKit, location, and Screen Time APIs.

- `EvolutionEvent`
  - Records why the creature changed.
  - Fields: trigger type, score delta, applied mutation, timestamp.

### SwiftData shape
The current `SwiftData` container can remain the persistence primitive, but the schema should expand to the above models.

Suggested container boundary:
- One `ModelContainer` for all app state.
- One shared `ModelContext` through the environment.
- Optional migration plan once the placeholder `Item` model is removed.

## 6. Domain APIs

Define small protocols so the app can be tested without real sensors.

```swift
protocol ActivityIngesting {
    func refreshDailyActivity() async throws -> [ActivitySample]
}

protocol LocationTrackingProviding {
    func requestAuthorization() async
    func startMonitoring() async
    func currentVisits() async throws -> [LocationVisit]
}

protocol ScreenTimeProviding {
    func requestAuthorization() async throws
    func currentUsageSignals() async throws -> [ActivitySample]
}

protocol TraitScoring {
    func score(samples: [ActivitySample], visits: [LocationVisit]) -> TraitSnapshot
}

protocol EvolutionApplying {
    func evolve(profile: LifeformProfile, traits: TraitSnapshot) -> LifeformState
}

protocol LifeformRepository {
    func loadProfile() async throws -> LifeformProfile?
    func saveProfile(_ profile: LifeformProfile) async throws
    func save(snapshot: TraitSnapshot) async throws
    func save(state: LifeformState) async throws
    func save(event: EvolutionEvent) async throws
}
```

These protocols create clean seams for unit tests and for future backend or mock implementations.

## 7. Apple API Layer

Use the following Apple frameworks for the MVP.

### HealthKit
Use HealthKit for movement signals.

Key APIs:
- `HKHealthStore`
- `HKQuantityTypeIdentifier.stepCount`
- `HKStatisticsQueryDescriptor` or `HKStatisticsCollectionQueryDescriptor`
- `requestAuthorization(toShare:read:)`

Design notes:
- Read daily step count as the primary movement signal.
- Normalize steps into a physical score, not a raw public metric.
- Avoid forcing the app into a workout-style model unless later needed.

### Core Location
Use Core Location for novelty and repeat-visit detection.

Key APIs:
- `CLLocationManager`
- `startMonitoringVisits()`
- `locationManager(_:didVisit:)`
- `locationManagerDidChangeAuthorization(_:)`
- `startMonitoringSignificantLocationChanges()` if visit monitoring is unavailable or insufficient

Design notes:
- Prefer visits for low-power background behavior.
- Convert location data into coarse context only.
- Store a stable, privacy-safe abstraction such as region hash or visit bucket instead of precise raw coordinates when possible.

### Screen Time
Use Screen Time APIs to measure usage and support the inverse reward loop.

Key APIs:
- `FamilyControls.AuthorizationCenter`
- `FamilyActivitySelection`
- `DeviceActivityCenter`
- `ManagedSettings`

Design notes:
- Request authorization early, but only when the user reaches the feature.
- Treat denial as a supported state, not a failure.
- Store usage as time windows and suppression scores rather than app-by-app dashboards unless the design later requires it.

### Optional Bluetooth / Proximity
If encounter detection is added later, keep it optional.

Possible APIs to evaluate later:
- `CoreBluetooth` for low-level discovery.
- `NearbyInteraction` if a precise proximity model is ever needed.

Design notes:
- Only add if privacy and battery impact are acceptable.
- Anonymous encounter metadata should stay local and opaque.

## 8. Feature Pipeline

### Ingestion pipeline
1. Collect raw signals from Apple frameworks.
2. Convert each signal into normalized `ActivitySample` or `LocationVisit` records.
3. Aggregate over a time window such as hourly or daily.
4. Produce a `TraitSnapshot`.
5. Apply evolution rules to derive `LifeformState`.
6. Persist the new state and append an `EvolutionEvent`.
7. Render the creature based on the derived state.

### Trait mapping
- `Physical`
  - Steps, movement, and activity intensity.
- `Social`
  - Anonymous encounter frequency and repeat encounter stability.
- `Exploration`
  - Novel location ratio, route diversity, deviation from routine.
- `Digital`
  - Screen time, late-night usage, and usage streaks.

## 9. Evolution Rules

The evolution engine should be deterministic with controlled randomness.

### Inputs
- Recent trait values.
- Long-term history.
- Novelty triggers.
- Usage suppression state.

### Outputs
- Visual morphology tags.
- Growth stage.
- Mutation marker.
- Confidence or rarity score.

### Rule shape
- High physical score increases strength and size.
- High exploration increases diversity and adaptive geometry.
- High social novelty unlocks mutation events.
- High digital usage suppresses growth and can deform the creature.

### Important constraint
The engine should not expose direct numeric stats in the UI. Users should infer state through appearance and behavior.

## 10. View Structure

### Proposed screens
- `CreatureHomeView`
  - Main creature display.
  - Current form and subtle animation.

- `GrowthHistoryView`
  - Timeline of evolution events.
  - No raw analytics dashboard.

- `PermissionsView`
  - Explains and requests HealthKit, Location, and Screen Time permissions.

- `SettingsView`
  - Name, privacy controls, reset, and debug options.

### State flow
- App launch loads persisted profile and authorization state.
- If permissions are missing, show `PermissionsView`.
- Otherwise show `CreatureHomeView`.
- Background refresh updates domain state and invalidates the visible creature form.

## 11. Persistence Strategy

### SwiftData
Use SwiftData for:
- Creature profile.
- Trait snapshots.
- Evolution events.
- Authorization state.
- Cached normalized inputs.

### Storage rules
- Persist derived state separately from raw source events.
- Keep raw sensor data limited and short-lived.
- Prefer coarse abstractions over exact location history.
- Add a migration plan before replacing the placeholder model in production data.

## 12. Privacy and Safety

- Request permissions only when needed.
- Give the user a clear reason for each entitlement.
- Store only the minimum data necessary to drive evolution.
- Use coarse location summaries instead of unnecessary precision.
- Handle all permission denials as supported states.

## 13. Implementation Order

1. Replace `Item` with domain models.
2. Add repository and trait-scoring protocols.
3. Build a stub `CreatureHomeView` with static state.
4. Add HealthKit ingestion.
5. Add Core Location visit tracking.
6. Add Screen Time authorization and signal capture.
7. Wire the evolution engine to persisted snapshots.
8. Replace placeholder UI with creature-centric rendering.

## 14. Milestone Definition

### MVP complete when
- One creature loads from persistent state.
- HealthKit contributes a daily physical score.
- Location visits contribute an exploration score.
- Screen Time contributes a digital suppression score.
- The creature visibly changes when scores change.

### Later phase
- Optional encounter detection.
- More expressive mutation system.
- Better visual theming.
- Debug instrumentation for model tuning.

## 15. Open Questions

- Should the first release target self-monitoring only, or also family-controlled Screen Time use cases?
- Should the app store any raw location traces at all, or only visit summaries?
- Should creature evolution happen continuously, or on a daily cadence?
- Should the UI include a minimal debug mode for development builds only?

## 16. Summary

The app should evolve from a timestamp list into a passive creature system with a small, explicit API surface:
- ingest signals,
- normalize into traits,
- score evolution,
- persist state,
- render a single creature.

That structure keeps the implementation testable, privacy-aware, and aligned with the original concept.
