import Foundation
import Observation

@Observable
@MainActor
final class ReviewPromptManager {
    struct Policy: Equatable {
        var minimumCycleAgeDays = 14
        var minimumSessionCount = 8
        var minimumDistinctDayCount = 5
        var minimumSessionSpacing: TimeInterval = 30 * 60
        var repeatCooldownDays = 90

        static let standard = Policy()
    }

    enum StorageKeys {
        static let cycleStartDate = "reviewPrompt.cycleStartDate"
        static let cycleSessionCount = "reviewPrompt.cycleSessionCount"
        static let cycleUseDays = "reviewPrompt.cycleUseDays"
        static let lastCountedSessionDate = "reviewPrompt.lastCountedSessionDate"
        static let lastRequestDate = "reviewPrompt.lastRequestDate"
        static let lastRequestedVersion = "reviewPrompt.lastRequestedVersion"
    }

    private(set) var presentationCandidateID: UUID?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let appVersion: String
    @ObservationIgnored private let policy: Policy

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        appVersion: String? = nil,
        policy: Policy = .standard
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.appVersion = appVersion
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "unknown"
        self.policy = policy
    }

    @discardableResult
    func appBecameActive(
        hasCompletedOnboarding: Bool,
        isTakingScreenshots: Bool,
        now: Date = .now
    ) -> UUID? {
        guard hasCompletedOnboarding, !isTakingScreenshots else { return nil }
        guard shouldCountSession(at: now) else { return nil }

        recordSession(at: now)

        guard isEligible(at: now) else { return nil }
        let candidateID = UUID()
        presentationCandidateID = candidateID
        return candidateID
    }

    func appBecameInactive() {
        cancelPendingPresentation()
    }

    func cancelPendingPresentation(candidateID: UUID? = nil) {
        guard candidateID == nil || presentationCandidateID == candidateID else { return }
        presentationCandidateID = nil
    }

    @discardableResult
    func recordRequestAttempt(candidateID: UUID, now: Date = .now) -> Bool {
        guard presentationCandidateID == candidateID, isEligible(at: now) else { return false }

        defaults.set(now, forKey: StorageKeys.lastRequestDate)
        defaults.set(appVersion, forKey: StorageKeys.lastRequestedVersion)
        resetEngagementCycle()
        presentationCandidateID = nil
        return true
    }

    func isEligible(at now: Date) -> Bool {
        guard let cycleStartDate = storedDate(forKey: StorageKeys.cycleStartDate),
              cycleStartDate <= now,
              recordedSessionCount >= policy.minimumSessionCount,
              recordedDistinctUsageDayCount >= policy.minimumDistinctDayCount,
              let minimumCycleDate = calendar.date(
                  byAdding: .day,
                  value: policy.minimumCycleAgeDays,
                  to: cycleStartDate
              ),
              now >= minimumCycleDate else {
            return false
        }

        guard let lastRequestDate = storedDate(forKey: StorageKeys.lastRequestDate) else {
            return true
        }

        guard let minimumRepeatDate = calendar.date(
            byAdding: .day,
            value: policy.repeatCooldownDays,
            to: lastRequestDate
        ),
        now >= minimumRepeatDate else {
            return false
        }

        let lastRequestedVersion = defaults.string(forKey: StorageKeys.lastRequestedVersion)
        return lastRequestedVersion != appVersion
    }

    var recordedSessionCount: Int {
        guard storedDate(forKey: StorageKeys.cycleStartDate) != nil,
              let number = defaults.object(forKey: StorageKeys.cycleSessionCount) as? NSNumber else {
            return 0
        }
        return max(0, number.intValue)
    }

    var recordedDistinctUsageDayCount: Int {
        storedUseDays().count
    }

    private func shouldCountSession(at now: Date) -> Bool {
        guard let lastSessionDate = storedDate(forKey: StorageKeys.lastCountedSessionDate) else {
            return true
        }

        let elapsed = now.timeIntervalSince(lastSessionDate)
        return elapsed < 0 || elapsed >= policy.minimumSessionSpacing
    }

    private func recordSession(at now: Date) {
        let existingCycleStart = storedDate(forKey: StorageKeys.cycleStartDate)
        let hasValidCycle = existingCycleStart.map { $0 <= now } == true

        if !hasValidCycle {
            defaults.set(now, forKey: StorageKeys.cycleStartDate)
            defaults.set(1, forKey: StorageKeys.cycleSessionCount)
            defaults.set([useDayKey(for: now)], forKey: StorageKeys.cycleUseDays)
        } else {
            defaults.set(recordedSessionCount + 1, forKey: StorageKeys.cycleSessionCount)
            var useDays = storedUseDays()
            useDays.insert(useDayKey(for: now))
            defaults.set(Array(useDays).sorted(), forKey: StorageKeys.cycleUseDays)
        }

        defaults.set(now, forKey: StorageKeys.lastCountedSessionDate)
    }

    private func resetEngagementCycle() {
        defaults.removeObject(forKey: StorageKeys.cycleStartDate)
        defaults.removeObject(forKey: StorageKeys.cycleSessionCount)
        defaults.removeObject(forKey: StorageKeys.cycleUseDays)
    }

    private func storedDate(forKey key: String) -> Date? {
        defaults.object(forKey: key) as? Date
    }

    private func storedUseDays() -> Set<String> {
        guard storedDate(forKey: StorageKeys.cycleStartDate) != nil,
              let days = defaults.array(forKey: StorageKeys.cycleUseDays) as? [String] else {
            return []
        }
        return Set(days)
    }

    private func useDayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return [components.era, components.year, components.month, components.day]
            .map { String($0 ?? 0) }
            .joined(separator: "-")
    }
}
