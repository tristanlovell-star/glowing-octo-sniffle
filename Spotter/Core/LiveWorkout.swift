import Foundation
import HealthKit

/// A live Apple Health workout that runs for the whole gym session (iOS 26 and later), so the
/// workout shows in Fitness as it happens and counts toward the rings minute by minute.
/// On older iOS versions nothing starts here and the session is saved to Health at the end instead.
@MainActor
final class LiveWorkout {
    static let shared = LiveWorkout()

    private let store = HKHealthStore()
    /// Held as `Any` because the live types only exist on iOS 26+.
    private var sessionBox: Any?
    private var builderBox: Any?

    var isRunning: Bool { sessionBox != nil }

    private var configuration: HKWorkoutConfiguration {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        return configuration
    }

    /// Starts the live workout. Returns false if this iOS version can't, or Health refused.
    @discardableResult
    func start(at date: Date) async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), !isRunning else { return isRunning }
        guard #available(iOS 26.0, *) else { return false }
        do {
            let configuration = configuration
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.startActivity(with: date)
            try await builder.beginCollection(at: date)
            sessionBox = session
            builderBox = builder
            return true
        } catch {
            sessionBox = nil
            builderBox = nil
            return false
        }
    }

    /// Picks a live workout back up after the app was closed or crashed mid-session.
    func recover() async {
        guard HKHealthStore.isHealthDataAvailable(), !isRunning else { return }
        guard #available(iOS 26.0, *) else { return }
        let recovered: HKWorkoutSession? = await withCheckedContinuation { continuation in
            store.recoverActiveWorkoutSession { session, _ in
                continuation.resume(returning: session)
            }
        }
        guard let recovered else { return }
        let builder = recovered.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store,
                                                     workoutConfiguration: recovered.workoutConfiguration)
        sessionBox = recovered
        builderBox = builder
    }

    /// Ends the live workout and saves it to Health. Returns true if it was saved.
    func finish(at date: Date) async -> Bool {
        guard #available(iOS 26.0, *),
              let session = sessionBox as? HKWorkoutSession,
              let builder = builderBox as? HKLiveWorkoutBuilder else { return false }
        sessionBox = nil
        builderBox = nil
        session.stopActivity(with: date)
        // The session has to reach "stopped" before the builder can be closed.
        for _ in 0..<30 where session.state != .stopped && session.state != .ended {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        var saved = false
        do {
            try await builder.addMetadata([HKMetadataKeyWorkoutBrandName: "Spotter", HKMetadataKeyIndoorWorkout: true])
            try await builder.endCollection(at: date)
            saved = try await builder.finishWorkout() != nil
        } catch {
            saved = false
        }
        session.end()
        return saved
    }

    /// Ends the live workout without saving anything.
    func discard() {
        guard #available(iOS 26.0, *),
              let session = sessionBox as? HKWorkoutSession,
              let builder = builderBox as? HKLiveWorkoutBuilder else { return }
        sessionBox = nil
        builderBox = nil
        builder.discardWorkout()
        session.end()
    }
}
