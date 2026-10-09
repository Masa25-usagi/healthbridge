import Foundation

struct HealthSummary: Codable {
    let date: String
    let steps: Double?
    let activeEnergyKcal: Double?
    let averageHeartRateBpm: Double?
    let restingHeartRateBpm: Double?
    let hrvMs: Double?
    let sleepMinutes: Double?
}
