import Foundation
import HealthKit

/// Apple Health integration: reads the recovery and body metrics the coach uses,
/// and saves finished sessions as strength-training workouts.
struct HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.bodyMass), HKQuantityType(.height), HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRate), HKQuantityType(.vo2Max), HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned), HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType(), HKCharacteristicType(.dateOfBirth),
        ]
    }

    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    /// Shows the Health permission sheet (only the first time; afterwards it returns immediately).
    func requestAccess() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    // MARK: Reading

    func snapshot() async -> HealthSnapshot {
        var snap = HealthSnapshot()
        guard isAvailable else { return snap }
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Calendar.current.startOfDay(for: now)) ?? now

        snap.weightKg = await latest(.bodyMass, unit: .gramUnit(with: .kilo))
        if let metres = await latest(.height, unit: .meter()) { snap.heightCm = metres * 100 }
        snap.vo2Max = await latest(.vo2Max, unit: HKUnit(from: "ml/kg*min"))
        snap.restingHeartRate = await average(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()),
                                              from: weekAgo, to: now)
        if let steps = await sum(.stepCount, unit: .count(), from: weekAgo, to: now) { snap.dailySteps = steps / 7 }
        if let energy = await sum(.activeEnergyBurned, unit: .kilocalorie(), from: weekAgo, to: now) {
            snap.dailyActiveEnergy = energy / 7
        }
        snap.sleepHours = await averageSleepHours(from: weekAgo, to: now)
        snap.workoutsLast7Days = await workoutCount(from: weekAgo, to: now)
        if let birth = try? store.dateOfBirthComponents(), let date = Calendar.current.date(from: birth) {
            snap.age = Calendar.current.dateComponents([.year], from: date, to: now).year
        }
        return snap
    }

    /// Average heart rate between two times, e.g. over a workout recorded by an Apple Watch.
    func averageHeartRate(from start: Date, to end: Date) async -> Double? {
        await average(.heartRate, unit: HKUnit.count().unitDivided(by: .minute()), from: start, to: end)
    }

    private func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(id))],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1)
        let samples = try? await descriptor.result(for: store)
        return samples?.first?.quantity.doubleValue(for: unit)
    }

    private func average(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async -> Double? {
        let range = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: range),
            options: .discreteAverage)
        let stats = try? await descriptor.result(for: store)
        return stats?.averageQuantity()?.doubleValue(for: unit)
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date) async -> Double? {
        let range = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: range),
            options: .cumulativeSum)
        let stats = try? await descriptor.result(for: store)
        return stats?.sumQuantity()?.doubleValue(for: unit)
    }

    private func averageSleepHours(from start: Date, to end: Date) async -> Double? {
        let range = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: range)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: store), !samples.isEmpty else { return nil }
        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
        ]
        // Merge overlapping intervals so a watch and a phone both recording don't double-count.
        let intervals = samples.filter { asleep.contains($0.value) }
            .map { (start: $0.startDate, end: $0.endDate) }
            .sorted { $0.start < $1.start }
        guard var current = intervals.first else { return nil }
        var total: TimeInterval = 0
        var nights: Set<Date> = []
        for interval in intervals.dropFirst() {
            if interval.start <= current.end {
                current.end = max(current.end, interval.end)
            } else {
                total += current.end.timeIntervalSince(current.start)
                nights.insert(Calendar.current.startOfDay(for: current.end))
                current = interval
            }
        }
        total += current.end.timeIntervalSince(current.start)
        nights.insert(Calendar.current.startOfDay(for: current.end))
        return total / 3600 / Double(max(nights.count, 1))
    }

    private func workoutCount(from start: Date, to end: Date) async -> Int? {
        let range = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(range)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        return try? await descriptor.result(for: store).count
    }

    // MARK: Writing

    /// Saves a finished session to Apple Health as a traditional strength training workout.
    func save(_ session: WorkoutSession) async -> Bool {
        guard isAvailable, let end = session.endedAt, end > session.startedAt else { return false }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        do {
            try await builder.beginCollection(at: session.startedAt)
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "Spotter",
                HKMetadataKeyIndoorWorkout: true,
            ])
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            return true
        } catch {
            return false
        }
    }
}
