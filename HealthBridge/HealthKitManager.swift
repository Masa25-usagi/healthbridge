import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var statusMessage = "まだHealthKitに接続していません。"
    @Published var summaryText = "{}"

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()

        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRate)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        return types
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusMessage = "この端末ではHealthKitデータを利用できません。"
            return
        }

        healthStore.requestAuthorization(toShare: [], read: readTypes) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }

                if success {
                    self.statusMessage = "HealthKitの許可を取得しました。"
                    self.fetchTodaySummary()
                } else {
                    self.statusMessage = "HealthKitの許可取得に失敗しました: \(error?.localizedDescription ?? "不明なエラー")"
                }
            }
        }
    }

    func fetchTodaySummary() {
        guard HKHealthStore.isHealthDataAvailable() else {
            statusMessage = "この端末ではHealthKitデータを利用できません。"
            return
        }

        statusMessage = "今日のHealthKitデータを取得中です..."

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let sleepStart = calendar.date(byAdding: .hour, value: -18, to: startOfToday) ?? startOfToday

        let group = DispatchGroup()
        let resultQueue = DispatchQueue(label: "healthbridge.results")

        var steps: Double?
        var activeEnergyKcal: Double?
        var averageHeartRateBpm: Double?
        var restingHeartRateBpm: Double?
        var hrvMs: Double?
        var sleepMinutes: Double?

        group.enter()
        readCumulativeQuantity(identifier: .stepCount, unit: .count(), start: startOfToday, end: now) { value in
            resultQueue.async {
                steps = value
                group.leave()
            }
        }

        group.enter()
        readCumulativeQuantity(identifier: .activeEnergyBurned, unit: .kilocalorie(), start: startOfToday, end: now) { value in
            resultQueue.async {
                activeEnergyKcal = value
                group.leave()
            }
        }

        group.enter()
        readAverageQuantity(identifier: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: startOfToday, end: now) { value in
            resultQueue.async {
                averageHeartRateBpm = value
                group.leave()
            }
        }

        group.enter()
        readAverageQuantity(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), start: startOfToday, end: now) { value in
            resultQueue.async {
                restingHeartRateBpm = value
                group.leave()
            }
        }

        group.enter()
        readAverageQuantity(identifier: .heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), start: startOfToday, end: now) { value in
            resultQueue.async {
                hrvMs = value
                group.leave()
            }
        }

        group.enter()
        readSleepMinutes(start: sleepStart, end: now) { value in
            resultQueue.async {
                sleepMinutes = value
                group.leave()
            }
        }

        group.notify(queue: resultQueue) { [weak self] in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.locale = Locale(identifier: "ja_JP")

            let summary = HealthSummary(
                date: formatter.string(from: now),
                steps: steps,
                activeEnergyKcal: activeEnergyKcal,
                averageHeartRateBpm: averageHeartRateBpm,
                restingHeartRateBpm: restingHeartRateBpm,
                hrvMs: hrvMs,
                sleepMinutes: sleepMinutes
            )
            let json = Self.makePrettyJSON(from: summary)

            Task { @MainActor in
                self?.summaryText = json
                self?.statusMessage = "今日のHealthKitデータを取得しました。"
            }
        }
    }

    private func readCumulativeQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        completion: @escaping (Double?) -> Void
    ) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard error == nil else {
                completion(nil)
                return
            }

            completion(result?.sumQuantity()?.doubleValue(for: unit))
        }

        healthStore.execute(query)
    }

    private func readAverageQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date,
        completion: @escaping (Double?) -> Void
    ) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: predicate,
            options: .discreteAverage
        ) { _, result, error in
            guard error == nil else {
                completion(nil)
                return
            }

            completion(result?.averageQuantity()?.doubleValue(for: unit))
        }

        healthStore.execute(query)
    }

    private func readSleepMinutes(
        start: Date,
        end: Date,
        completion: @escaping (Double?) -> Void
    ) {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: nil
        ) { _, samples, error in
            guard error == nil else {
                completion(nil)
                return
            }

            let sleepSamples = samples as? [HKCategorySample] ?? []
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue
            ]

            let totalSeconds = sleepSamples.reduce(0.0) { total, sample in
                guard asleepValues.contains(sample.value) else { return total }
                return total + sample.endDate.timeIntervalSince(sample.startDate)
            }

            completion(totalSeconds / 60.0)
        }

        healthStore.execute(query)
    }

    private static func makePrettyJSON(from summary: HealthSummary) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(summary)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}
