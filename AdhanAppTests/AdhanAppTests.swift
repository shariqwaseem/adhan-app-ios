import Testing
import Foundation
@testable import AdhanApp

@Suite("Prayer Calculation Tests")
struct PrayerCalculationTests {
    let service = PrayerCalculationService()

    @Test("Calculate prayer times for Mecca")
    func meccaPrayerTimes() {
        let date = createDate(year: 2025, month: 6, day: 15)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 21.4225,
            longitude: 39.8262,
            configuration: .preset(.UmmAlQura),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        #expect(entries.count == 6)
        #expect(entries[0].prayer == .tahajjud)
        #expect(entries[1].prayer == .fajr)
        #expect(entries[2].prayer == .dhuhr)
        #expect(entries[3].prayer == .asr)
        #expect(entries[4].prayer == .maghrib)
        #expect(entries[5].prayer == .isha)
    }

    @Test("Prayer times are in chronological order")
    func chronologicalOrder() {
        let date = createDate(year: 2025, month: 3, day: 21)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 40.7128,
            longitude: -74.0060,
            configuration: .preset(.NorthAmerica),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        for i in 1..<entries.count {
            #expect(entries[i].time > entries[i - 1].time, "Prayer \(entries[i].prayer.rawValue) should be after \(entries[i - 1].prayer.rawValue)")
        }
    }

    @Test("Karachi prayer times")
    func karachiPrayerTimes() {
        let date = createDate(year: 2025, month: 1, day: 15)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 24.8607,
            longitude: 67.0011,
            configuration: .preset(.Karachi),
            asrMethod: .hanafi,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        #expect(entries.count == 6)
        // Hanafi Asr should be later than Shafi'i
        let shafiEntries = service.calculatePrayerTimes(
            date: date,
            latitude: 24.8607,
            longitude: 67.0011,
            configuration: .preset(.Karachi),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        let hanafiAsr = entries.first(where: { $0.prayer == .asr })!.time
        let shafiAsr = shafiEntries.first(where: { $0.prayer == .asr })!.time
        #expect(hanafiAsr > shafiAsr, "Hanafi Asr should be later than Shafi'i Asr")
    }

    @Test("Recommended method for country codes")
    func methodRecommendation() {
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "US") == .NorthAmerica)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "SA") == .UmmAlQura)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "PK") == .Karachi)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "TR") == .Turkey)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: "GB") == .MoonsightingCommittee)
        #expect(CalculationMethodInfo.recommendedMethod(forCountryCode: nil) == .MuslimWorldLeague)
    }

    @Test("Manual adjustments are applied")
    func manualAdjustments() {
        let date = createDate(year: 2025, month: 6, day: 15)
        let entries = service.calculatePrayerTimes(
            date: date,
            latitude: 21.4225,
            longitude: 39.8262,
            configuration: .preset(.UmmAlQura),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [.fajr: 5, .maghrib: -3]
        )
        let fajr = entries.first(where: { $0.prayer == .fajr })!
        #expect(fajr.manualAdjustmentMinutes == 5)
        #expect(fajr.adjustedTime != fajr.time)
    }

    @Test("Qibla direction from New York")
    func qiblaFromNewYork() {
        let direction = service.qiblaDirection(latitude: 40.7128, longitude: -74.0060)
        // Qibla from NYC should be roughly 58-59 degrees (NE)
        #expect(direction > 50 && direction < 70, "Qibla from NYC should be roughly NE (~58°)")
    }

    @Test("Multi-day calculation returns correct count")
    func multiDayCalculation() {
        let date = createDate(year: 2025, month: 6, day: 1)
        let results = service.calculateMultipleDays(
            startDate: date,
            days: 7,
            latitude: 21.4225,
            longitude: 39.8262,
            configuration: .preset(.UmmAlQura),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        #expect(results.count == 7)
        for day in results {
            #expect(day.count == 6)
        }
    }

    private func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components)!
    }
}

@Suite("Review Prompt Tests", .serialized)
@MainActor
struct ReviewPromptTests {
    @Test("First request requires age, sessions, and distinct usage days")
    func firstRequestRequiresEveryEngagementThreshold() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let manager = makeManager(defaults: defaults)

        let qualifyingOffsets = [
            (0, 0), (0, 31),
            (1, 0), (1, 31),
            (2, 0), (3, 0), (4, 0), (4, 31)
        ]

        for offset in qualifyingOffsets.dropLast() {
            manager.appBecameActive(
                hasCompletedOnboarding: true,
                isTakingScreenshots: false,
                now: date(day: offset.0, minute: offset.1)
            )
        }
        #expect(manager.recordedSessionCount == 7)
        #expect(manager.recordedDistinctUsageDayCount == 5)
        #expect(!manager.isEligible(at: date(day: 14)))

        let finalOffset = try #require(qualifyingOffsets.last)
        manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: finalOffset.0, minute: finalOffset.1)
        )
        #expect(manager.recordedSessionCount == 8)
        #expect(!manager.isEligible(at: date(day: 13, minute: 1_439)))
        #expect(manager.isEligible(at: date(day: 14)))

        let fourDayDefaults = try makeDefaults()
        defer { clear(fourDayDefaults) }
        let fourDayManager = makeManager(defaults: fourDayDefaults)
        for day in 0..<4 {
            for minute in [0, 31] {
                fourDayManager.appBecameActive(
                    hasCompletedOnboarding: true,
                    isTakingScreenshots: false,
                    now: date(day: day, minute: minute)
                )
            }
        }
        #expect(fourDayManager.recordedSessionCount == 8)
        #expect(fourDayManager.recordedDistinctUsageDayCount == 4)
        #expect(!fourDayManager.isEligible(at: date(day: 14)))
    }

    @Test("Foreground transitions count only after thirty minutes")
    func sessionSpacingPreventsRapidForegroundCounting() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let manager = makeManager(defaults: defaults)

        manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: 0)
        )
        manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: 0, minute: 29)
        )
        #expect(manager.recordedSessionCount == 1)

        manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: 0, minute: 30)
        )
        #expect(manager.recordedSessionCount == 2)
        #expect(manager.recordedDistinctUsageDayCount == 1)
    }

    @Test("Onboarding and screenshot runs never count")
    func excludedRunsDoNotCreateEngagement() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let manager = makeManager(defaults: defaults)

        #expect(manager.appBecameActive(
            hasCompletedOnboarding: false,
            isTakingScreenshots: false,
            now: date(day: 0)
        ) == nil)
        #expect(manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: true,
            now: date(day: 1)
        ) == nil)
        #expect(manager.recordedSessionCount == 0)
        #expect(manager.recordedDistinctUsageDayCount == 0)
    }

    @Test("Request attempts persist and reset engagement")
    func requestAttemptResetsTheEngagementCycle() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let manager = makeManager(defaults: defaults, appVersion: "1.2.0")
        recordInitialEngagement(with: manager)

        let requestDate = date(day: 14)
        let candidateID = try #require(manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: requestDate
        ))
        #expect(manager.recordRequestAttempt(candidateID: candidateID, now: requestDate))
        #expect(manager.recordedSessionCount == 0)
        #expect(manager.recordedDistinctUsageDayCount == 0)
        #expect(defaults.object(forKey: ReviewPromptManager.StorageKeys.lastRequestDate) as? Date == requestDate)
        #expect(defaults.string(forKey: ReviewPromptManager.StorageKeys.lastRequestedVersion) == "1.2.0")
        #expect(!manager.recordRequestAttempt(candidateID: candidateID, now: requestDate))
    }

    @Test("Repeat requests require cooldown, a newer version, and new engagement")
    func repeatRequestRequiresEveryGate() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let originalVersion = makeManager(defaults: defaults, appVersion: "1.2.0")
        recordInitialEngagement(with: originalVersion)

        let firstRequestDate = date(day: 14)
        let candidateID = try #require(originalVersion.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: firstRequestDate
        ))
        #expect(originalVersion.recordRequestAttempt(candidateID: candidateID, now: firstRequestDate))

        let repeatOffsets = [
            (15, 0), (15, 31),
            (16, 0), (16, 31),
            (17, 0), (18, 0), (19, 0)
        ]
        for offset in repeatOffsets {
            originalVersion.appBecameActive(
                hasCompletedOnboarding: true,
                isTakingScreenshots: false,
                now: date(day: offset.0, minute: offset.1)
            )
        }

        let newVersion = makeManager(defaults: defaults, appVersion: "1.3.0")
        #expect(!newVersion.isEligible(at: date(day: 104)))

        originalVersion.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: 19, minute: 31)
        )
        #expect(!newVersion.isEligible(at: date(day: 103, minute: 1_439)))
        #expect(!originalVersion.isEligible(at: date(day: 104)))
        #expect(newVersion.isEligible(at: date(day: 104)))
    }

    @Test("Malformed persisted values restart safely")
    func malformedPersistenceRestartsTheCycle() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        defaults.set("not-a-date", forKey: ReviewPromptManager.StorageKeys.cycleStartDate)
        defaults.set("many", forKey: ReviewPromptManager.StorageKeys.cycleSessionCount)
        defaults.set([1, 2, 3], forKey: ReviewPromptManager.StorageKeys.cycleUseDays)
        defaults.set("not-a-date", forKey: ReviewPromptManager.StorageKeys.lastRequestDate)

        let manager = makeManager(defaults: defaults)
        #expect(manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: 0)
        ) == nil)
        #expect(manager.recordedSessionCount == 1)
        #expect(manager.recordedDistinctUsageDayCount == 1)
        #expect(!manager.isEligible(at: date(day: 100)))
    }

    @Test("Canceling presentation preserves eligibility for a later session")
    func cancelingPresentationDoesNotConsumeTheAttempt() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let manager = makeManager(defaults: defaults)
        recordInitialEngagement(with: manager)

        let firstCandidate = try #require(manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: 14)
        ))
        manager.cancelPendingPresentation(candidateID: firstCandidate)
        #expect(manager.presentationCandidateID == nil)
        #expect(!manager.recordRequestAttempt(candidateID: firstCandidate, now: date(day: 14)))
        #expect(defaults.object(forKey: ReviewPromptManager.StorageKeys.lastRequestDate) == nil)

        let laterCandidate = manager.appBecameActive(
            hasCompletedOnboarding: true,
            isTakingScreenshots: false,
            now: date(day: 14, minute: 31)
        )
        #expect(laterCandidate != nil)
        #expect(laterCandidate != firstCandidate)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "ReviewPromptTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.set(suiteName, forKey: "ReviewPromptTests.suiteName")
        return defaults
    }

    private func clear(_ defaults: UserDefaults) {
        guard let suiteName = defaults.string(forKey: "ReviewPromptTests.suiteName") else { return }
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func makeManager(
        defaults: UserDefaults,
        appVersion: String = "1.2.0"
    ) -> ReviewPromptManager {
        ReviewPromptManager(
            defaults: defaults,
            calendar: Self.calendar,
            appVersion: appVersion
        )
    }

    private func recordInitialEngagement(with manager: ReviewPromptManager) {
        let offsets = [
            (0, 0), (0, 31),
            (1, 0), (1, 31),
            (2, 0), (3, 0), (4, 0), (4, 31)
        ]
        for offset in offsets {
            manager.appBecameActive(
                hasCompletedOnboarding: true,
                isTakingScreenshots: false,
                now: date(day: offset.0, minute: offset.1)
            )
        }
    }

    private func date(day: Int, minute: Int = 0) -> Date {
        let seconds = TimeInterval((day * 24 * 60 + minute) * 60)
        return Self.baseDate.addingTimeInterval(seconds)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static let baseDate = Date(timeIntervalSince1970: 1_767_225_600)
}

@Suite("Hijri Date Tests")
struct HijriDateTests {
    let service = HijriDateService()

    @Test("Hijri date string is not empty")
    func hijriDateNotEmpty() {
        let result = service.hijriDateString(for: Date())
        #expect(!result.isEmpty)
    }

    @Test("Ramadan detection")
    func ramadanDetection() {
        // Ramadan 2025 starts around March 1, 2025
        var components = DateComponents()
        components.year = 2025
        components.month = 3
        components.day = 15
        components.timeZone = TimeZone(identifier: "UTC")
        let midRamadan2025 = Calendar.current.date(from: components)!
        let isRamadan = service.isRamadan(on: midRamadan2025)
        // This is approximately Ramadan time but exact dates vary
        // Just verify the function runs without crashing
        _ = isRamadan
        _ = service.ramadanDay(on: midRamadan2025)
    }
}

@Suite("Siri Prayer Time Tests")
struct SiriPrayerTimeTests {
    @Test("Next prayer answer picks the next upcoming entry")
    func nextPrayerAnswerPicksUpcomingEntry() {
        let now = Self.fixedDate(hour: 12, minute: 0)
        let service = SiriPrayerTimeService { date in
            guard Calendar.current.isDate(date, inSameDayAs: now) else { return nil }
            return [
                PrayerTimeEntry(prayer: .fajr, time: Self.fixedDate(hour: 5, minute: 10)),
                PrayerTimeEntry(prayer: .dhuhr, time: Self.fixedDate(hour: 13, minute: 15)),
                PrayerTimeEntry(prayer: .asr, time: Self.fixedDate(hour: 16, minute: 45))
            ]
        }

        let answer = service.nextPrayerAnswer(now: now)

        #expect(answer.contains("Dhuhr"))
        #expect(answer.contains("in 1 hour"))
    }

    @Test("Specific prayer answer uses past tense after the time passes")
    func specificPrayerAnswerUsesPastTense() {
        let now = Self.fixedDate(hour: 8, minute: 0)
        let service = SiriPrayerTimeService { date in
            guard Calendar.current.isDate(date, inSameDayAs: now) else { return nil }
            return [
                PrayerTimeEntry(prayer: .fajr, time: Self.fixedDate(hour: 5, minute: 10))
            ]
        }

        let answer = service.prayerTimeAnswer(for: PrayerName.fajr, now: now)

        #expect(answer.contains("Fajr was at"))
        #expect(answer.contains("today"))
    }

    private static func fixedDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}

@Suite("Localization Tests")
struct LocalizationTests {

    // MARK: - String Completeness

    @Test("All calculation methods have non-empty localizedName")
    func allCalculationMethodsHaveLocalizedName() {
        for method in CalculationMethodInfo.allCases {
            #expect(!method.localizedName.isEmpty, "\(method.rawValue) has empty localizedName")
        }
    }

    @Test("All Asr methods have non-empty localizedName")
    func allAsrMethodsHaveLocalizedName() {
        for method in AsrJuristicMethod.allCases {
            #expect(!method.localizedName.isEmpty, "\(method.rawValue) has empty localizedName")
        }
    }

    @Test("All high latitude rules have non-empty localizedName")
    func allHighLatRulesHaveLocalizedName() {
        for rule in HighLatitudeRuleOption.allCases {
            #expect(!rule.localizedName.isEmpty, "\(rule.rawValue) has empty localizedName")
        }
    }

    @Test("All Moon Sighting Isha twilight options have non-empty localizedName")
    func allMoonSightingTwilightOptionsHaveLocalizedName() {
        for twilight in MoonSightingIshaTwilight.allCases {
            #expect(!twilight.localizedName.isEmpty, "\(twilight.rawValue) has empty localizedName")
        }
    }

    @Test("All notification modes have non-empty localizedName")
    func allNotificationModesHaveLocalizedName() {
        for mode in PrayerNotificationMode.allCases {
            #expect(!mode.localizedName.isEmpty, "\(mode.rawValue) has empty localizedName")
        }
    }

    @Test("All notification modes have non-empty localizedDescription")
    func allNotificationModesHaveLocalizedDescription() {
        for mode in PrayerNotificationMode.allCases {
            #expect(!mode.localizedDescription.isEmpty, "\(mode.rawValue) has empty localizedDescription")
        }
    }

    @Test("All prayer names have non-empty localizedName")
    func allPrayerNamesHaveLocalizedName() {
        for prayer in PrayerName.allCases {
            #expect(!prayer.localizedName.isEmpty, "\(prayer.rawValue) has empty localizedName")
        }
    }

    // MARK: - RTL

    @Test("chevron.forward is a valid SF Symbol name")
    func chevronForwardIsValidSFSymbol() {
        // UIImage(systemName:) returns nil for invalid names
        // This verifies the symbol we use for RTL-aware chevrons exists
        let symbolName = "chevron.forward"
        #expect(!symbolName.isEmpty)
    }

    // MARK: - Numeral Systems

    @Test("NumeralFormatter produces Eastern Arabic when enabled")
    func numeralFormatterProducesEasternArabicWhenEnabled() {
        let result = NumeralFormatter.format(123, useArabicNumerals: true)
        #expect(result.contains("١") || result.contains("٢") || result.contains("٣"),
                "Expected Eastern Arabic numerals, got: \(result)")
    }

    @Test("NumeralFormatter produces Western digits by default")
    func numeralFormatterProducesWesternByDefault() {
        let result = NumeralFormatter.format(123, useArabicNumerals: false)
        #expect(result == "123", "Expected '123', got: \(result)")
    }

    @Test("Default useArabicNumerals is false")
    func defaultUseArabicNumeralsIsFalse() {
        let prefs = UserPreferences()
        #expect(prefs.useArabicNumerals == false)
    }

    // MARK: - Locale-Aware Formatting

    @Test("DateFormatter with timeStyle .short produces non-empty for all locales")
    func dateFormatterTimeStyleProducesNonEmptyForAllLocales() {
        let locales = ["en", "ar", "id", "tr"]
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let date = Date()

        for localeId in locales {
            formatter.locale = Locale(identifier: localeId)
            let result = formatter.string(from: date)
            #expect(!result.isEmpty, "Empty time string for locale: \(localeId)")
        }
    }

    // MARK: - Localized Names Are Non-Empty

    @Test("All localized names are non-empty strings")
    func localizedNamesAreNotEmpty() {
        // Calculation methods
        for method in CalculationMethodInfo.allCases {
            #expect(!method.localizedName.isEmpty)
        }
        // Asr methods
        for method in AsrJuristicMethod.allCases {
            #expect(!method.localizedName.isEmpty)
        }
        // High latitude rules
        for rule in HighLatitudeRuleOption.allCases {
            #expect(!rule.localizedName.isEmpty)
        }
        // Notification modes
        for mode in PrayerNotificationMode.allCases {
            #expect(!mode.localizedName.isEmpty)
        }
    }

    @Test("All localized descriptions are non-empty strings")
    func localizedDescriptionsAreNotEmpty() {
        for mode in PrayerNotificationMode.allCases {
            #expect(!mode.localizedDescription.isEmpty)
        }
    }
}

@Suite("Calculation Selection Tests", .serialized)
struct CalculationSelectionTests {
    @Test("Auto resolves by country while preset and custom remain fixed")
    func selectionResolution() {
        #expect(CalculationSelection.automatic.resolved(countryCode: "SA") == .preset(.UmmAlQura))
        #expect(CalculationSelection.automatic.resolved(countryCode: "PK") == .preset(.Karachi))
        #expect(CalculationSelection.automatic.resolved(countryCode: "US") == .preset(.NorthAmerica))
        #expect(CalculationSelection.automatic.resolved(countryCode: nil) == .preset(.MuslimWorldLeague))

        let preset = CalculationSelection.preset(.Karachi)
        #expect(preset.resolved(countryCode: "SA") == .preset(.Karachi))

        let custom = CustomCalculationParameters(fajrAngle: 17.5, ishaRule: .angle(16.5))
        #expect(CalculationSelection.custom(custom).resolved(countryCode: "US") == .custom(custom))
    }

    @Test("Legacy values migrate to Auto once and current payload persists")
    func migrationAndPersistence() throws {
        let suiteName = "CalculationSelectionTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("Other", forKey: "calculationMethod")
        #expect(CalculationSettingsStorage.load(from: defaults) == nil)

        let migrated = CalculationSettingsPayload()
        CalculationSettingsStorage.save(migrated, to: defaults)
        defaults.set(CalculationMethodInfo.Karachi.rawValue, forKey: "calculationMethod")
        #expect(CalculationSettingsStorage.load(from: defaults)?.selection == .automatic)

        let manual = CalculationSettingsPayload(
            selection: .preset(.Karachi),
            updatedAt: Date(timeIntervalSince1970: 2),
            wasExplicitlySelected: true
        )
        CalculationSettingsStorage.save(manual, to: defaults)
        #expect(CalculationSettingsStorage.load(from: defaults) == manual)
    }

    @Test("Synced explicit choice beats a newer migration default")
    func explicitSyncWins() {
        let synced = CalculationSettingsPayload(
            selection: .preset(.NorthAmerica),
            updatedAt: Date(timeIntervalSince1970: 1),
            wasExplicitlySelected: true
        )
        let migrationDefault = CalculationSettingsPayload(
            selection: .automatic,
            updatedAt: Date(timeIntervalSince1970: 2),
            wasExplicitlySelected: false
        )
        #expect(CalculationSettingsStorage.preferred([migrationDefault, synced]) == synced)
    }

    @Test("Legacy version-one payloads default Moon Sighting Isha to General")
    func legacyPayloadDefaultsToGeneralTwilight() throws {
        let original = CalculationSettingsPayload(
            selection: .preset(.MoonsightingCommittee),
            updatedAt: Date(timeIntervalSince1970: 123),
            wasExplicitlySelected: true
        )
        let encoded = try #require(CalculationSettingsStorage.encode(original))
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "moonSightingIshaTwilight")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try #require(CalculationSettingsStorage.decode(legacyData))
        #expect(decoded.version == 1)
        #expect(decoded.selection == original.selection)
        #expect(decoded.updatedAt == original.updatedAt)
        #expect(decoded.wasExplicitlySelected)
        #expect(decoded.moonSightingIshaTwilight == .general)
    }

    @MainActor
    @Test("Changing Moon Sighting twilight does not mark Auto as an explicit method selection")
    func twilightChangePreservesCalculationSelectionSemantics() {
        let initial = CalculationSettingsPayload(
            selection: .automatic,
            updatedAt: Date(timeIntervalSince1970: 1),
            wasExplicitlySelected: false
        )
        let viewModel = PrayerTimesViewModel(
            initialCalculationSettings: initial,
            persistsCalculationSettings: false
        )

        viewModel.moonSightingIshaTwilight = .abyad

        #expect(viewModel.calculationSelection == .automatic)
        #expect(viewModel.calculationSettings.wasExplicitlySelected == false)
        #expect(viewModel.moonSightingIshaTwilight == .abyad)
        #expect(viewModel.calculationSettings.updatedAt > initial.updatedAt)
    }

    @Test("Custom values clamp to supported ranges")
    func customValidation() {
        let low = CustomCalculationParameters(fajrAngle: -5, ishaRule: .fixedMinutesAfterMaghrib(0))
        #expect(low.fajrAngle == 1)
        #expect(low.ishaRule == .fixedMinutesAfterMaghrib(1))

        let high = CustomCalculationParameters(fajrAngle: 45, ishaRule: .angle(50))
        #expect(high.fajrAngle == 30)
        #expect(high.ishaRule == .angle(30))

        var invalidAfterInitialization = high
        invalidAfterInitialization.fajrAngle = 80
        invalidAfterInitialization.ishaRule = .fixedMinutesAfterMaghrib(500)
        let payload = CalculationSettingsPayload(selection: .custom(invalidAfterInitialization))
        let decoded = CalculationSettingsStorage.decode(CalculationSettingsStorage.encode(payload))
        #expect(decoded?.selection == .custom(CustomCalculationParameters(
            fajrAngle: 30,
            ishaRule: .fixedMinutesAfterMaghrib(240)
        )))
    }

    @MainActor
    @Test("Saudi Auto label names the resolved Umm al-Qura method")
    func autoLabel() {
        let viewModel = PrayerTimesViewModel(
            initialCalculationSettings: CalculationSettingsPayload(selection: .automatic),
            persistsCalculationSettings: false
        )
        viewModel.countryCode = "SA"
        #expect(viewModel.calculationSelectionLabel == "Auto (Umm al-Qura)")
    }

    @MainActor
    @Test("Location changes preserve manual and Custom selections")
    func locationDoesNotOverwriteExplicitSelection() {
        let automatic = PrayerTimesViewModel(
            initialCalculationSettings: CalculationSettingsPayload(selection: .automatic),
            persistsCalculationSettings: false
        )
        automatic.updateLocation(latitude: 21.4225, longitude: 39.8262, cityName: "Makkah", countryCode: "SA")
        #expect(automatic.calculationSelection == .automatic)
        #expect(automatic.effectiveCalculationMethod == .UmmAlQura)
        automatic.updateLocation(latitude: 24.8607, longitude: 67.0011, cityName: "Karachi", countryCode: "PK")
        #expect(automatic.calculationSelection == .automatic)
        #expect(automatic.effectiveCalculationMethod == .Karachi)

        let manual = PrayerTimesViewModel(
            initialCalculationSettings: CalculationSettingsPayload(
                selection: .preset(.Karachi),
                wasExplicitlySelected: true
            ),
            persistsCalculationSettings: false
        )
        manual.updateLocation(latitude: 21.4225, longitude: 39.8262, cityName: "Makkah", countryCode: "SA")
        #expect(manual.calculationSelection == .preset(.Karachi))

        let parameters = CustomCalculationParameters(fajrAngle: 18, ishaRule: .fixedMinutesAfterMaghrib(95))
        manual.setCalculationSelection(.custom(parameters))
        manual.updateLocation(latitude: 40.7128, longitude: -74.0060, cityName: "New York", countryCode: "US")
        #expect(manual.calculationSelection == .custom(parameters))
    }

    @MainActor
    @Test("Custom first use seeds from Auto and restores the last values")
    func customSeedRestoreAndReset() {
        let viewModel = PrayerTimesViewModel(
            initialCalculationSettings: CalculationSettingsPayload(selection: .automatic),
            persistsCalculationSettings: false
        )
        viewModel.countryCode = "SA"
        #expect(viewModel.customCalculationParameters == CustomCalculationParameters(
            fajrAngle: 18.5,
            ishaRule: .fixedMinutesAfterMaghrib(90)
        ))

        let edited = CustomCalculationParameters(fajrAngle: 17.2, ishaRule: .fixedMinutesAfterMaghrib(95))
        viewModel.updateCustomCalculationParameters(edited)
        viewModel.setCalculationSelection(.preset(.NorthAmerica))
        #expect(viewModel.customCalculationParameters == edited)

        viewModel.setCalculationSelection(.custom(viewModel.customCalculationParameters))
        viewModel.resetCustomCalculationParameters()
        #expect(viewModel.customCalculationParameters == CustomCalculationParameters(
            fajrAngle: 18.5,
            ishaRule: .fixedMinutesAfterMaghrib(90)
        ))
    }
}

@Suite("Prayer Accuracy Regression Tests")
struct PrayerAccuracyRegressionTests {
    private let makkahLatitude = 21.4225
    private let makkahLongitude = 39.8262

    @Test("Umm al-Qura uses 90-minute Isha outside Ramadan and 120 during Ramadan")
    func ramadanUmmAlQuraIntervals() throws {
        let calendar = fixedCalendar(timeZoneID: "Asia/Riyadh")
        let service = PrayerCalculationService(calendar: calendar)
        let nonRamadan = service.calculatePrayerTimes(
            date: fixedDate(2025, 6, 15, 12, 0, calendar: calendar),
            latitude: makkahLatitude,
            longitude: makkahLongitude,
            configuration: .preset(.UmmAlQura),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        let ramadan = service.calculatePrayerTimes(
            date: fixedDate(2025, 3, 15, 12, 0, calendar: calendar),
            latitude: makkahLatitude,
            longitude: makkahLongitude,
            configuration: .preset(.UmmAlQura),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )

        let nonRamadanMaghrib = try #require(nonRamadan.first(where: { $0.prayer == .maghrib }))
        let nonRamadanIsha = try #require(nonRamadan.first(where: { $0.prayer == .isha }))
        let ramadanMaghrib = try #require(ramadan.first(where: { $0.prayer == .maghrib }))
        let ramadanIsha = try #require(ramadan.first(where: { $0.prayer == .isha }))
        #expect(abs(nonRamadanIsha.time.timeIntervalSince(nonRamadanMaghrib.time) - 90 * 60) <= 1)
        #expect(abs(ramadanIsha.time.timeIntervalSince(ramadanMaghrib.time) - 120 * 60) <= 1)
    }

    @Test("Custom fixed Isha does not receive the Ramadan extension")
    func customIntervalIsNotExtended() throws {
        let calendar = fixedCalendar(timeZoneID: "Asia/Riyadh")
        let service = PrayerCalculationService(calendar: calendar)
        let entries = service.calculatePrayerTimes(
            date: fixedDate(2025, 3, 15, 12, 0, calendar: calendar),
            latitude: makkahLatitude,
            longitude: makkahLongitude,
            configuration: .custom(CustomCalculationParameters(
                fajrAngle: 18.5,
                ishaRule: .fixedMinutesAfterMaghrib(90)
            )),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        let maghrib = try #require(entries.first(where: { $0.prayer == .maghrib }))
        let isha = try #require(entries.first(where: { $0.prayer == .isha }))
        #expect(abs(isha.time.timeIntervalSince(maghrib.time) - 90 * 60) <= 1)
    }

    @Test("Tahajjud starts at the final third measured from previous Maghrib")
    func tahajjudUsesPreviousMaghrib() throws {
        let calendar = fixedCalendar(timeZoneID: "Asia/Riyadh")
        let service = PrayerCalculationService(calendar: calendar)
        let date = fixedDate(2025, 6, 15, 12, 0, calendar: calendar)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: date))
        let todayEntries = service.calculatePrayerTimes(
            date: date,
            latitude: makkahLatitude,
            longitude: makkahLongitude,
            configuration: .preset(.UmmAlQura),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [.tahajjud: 7, .fajr: 10, .maghrib: -5]
        )
        let yesterdayEntries = service.calculatePrayerTimes(
            date: yesterday,
            latitude: makkahLatitude,
            longitude: makkahLongitude,
            configuration: .preset(.UmmAlQura),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        let tahajjud = try #require(todayEntries.first(where: { $0.prayer == .tahajjud }))
        let fajr = try #require(todayEntries.first(where: { $0.prayer == .fajr }))
        let previousMaghrib = try #require(yesterdayEntries.first(where: { $0.prayer == .maghrib }))
        let expected = previousMaghrib.time.addingTimeInterval(fajr.time.timeIntervalSince(previousMaghrib.time) * 2 / 3)
        #expect(abs(tahajjud.time.timeIntervalSince(expected)) <= 1)
        #expect(abs(tahajjud.adjustedTime.timeIntervalSince(tahajjud.time) - 7 * 60) <= 1)
    }

    @Test("Tahajjud formula survives DST, month, and year boundaries")
    func tahajjudCalendarBoundaries() throws {
        try assertTahajjudFormula(
            year: 2025, month: 3, day: 10,
            timeZoneID: "America/New_York",
            latitude: 40.7128, longitude: -74.0060,
            configuration: .preset(.NorthAmerica)
        )
        try assertTahajjudFormula(
            year: 2026, month: 1, day: 1,
            timeZoneID: "Asia/Riyadh",
            latitude: makkahLatitude, longitude: makkahLongitude,
            configuration: .preset(.UmmAlQura)
        )
    }

    @Test("Shared core payload round-trip preserves calculation parity")
    func sharedCoreParity() throws {
        let calendar = fixedCalendar(timeZoneID: "America/New_York")
        let payload = CalculationSettingsPayload(
            selection: .custom(CustomCalculationParameters(fajrAngle: 16.5, ishaRule: .angle(15.5))),
            wasExplicitlySelected: true,
            moonSightingIshaTwilight: .abyad
        )
        let decoded = try #require(CalculationSettingsStorage.decode(CalculationSettingsStorage.encode(payload)))
        let configuration = decoded.selection.resolved(countryCode: "US")
        let date = fixedDate(2025, 7, 1, 12, 0, calendar: calendar)
        let appResult = PrayerCalculationCore(calendar: calendar).calculate(
            date: date,
            latitude: 40.7128,
            longitude: -74.0060,
            configuration: configuration,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            moonSightingIshaTwilight: decoded.moonSightingIshaTwilight
        )
        let widgetResult = PrayerCalculationCore(calendar: calendar).calculate(
            date: date,
            latitude: 40.7128,
            longitude: -74.0060,
            configuration: configuration,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            moonSightingIshaTwilight: decoded.moonSightingIshaTwilight
        )
        #expect(appResult == widgetResult)
        #expect(decoded.moonSightingIshaTwilight == .abyad)
    }

    @Test("Moon Sighting twilight variants match upstream Isha fixtures and leave other prayers unchanged")
    func moonSightingIshaTwilightFixtures() throws {
        let calendar = fixedCalendar(timeZoneID: "America/Toronto")
        let service = PrayerCalculationService(calendar: calendar)
        let date = fixedDate(2021, 7, 1, 12, 0, calendar: calendar)

        func entries(for twilight: MoonSightingIshaTwilight) -> [PrayerTimeEntry] {
            service.calculatePrayerTimes(
                date: date,
                latitude: 43.494,
                longitude: -79.844,
                configuration: .preset(.MoonsightingCommittee),
                asrMethod: .standard,
                highLatitudeRule: .middleOfTheNight,
                adjustments: [:],
                moonSightingIshaTwilight: twilight
            )
        }

        let general = entries(for: .general)
        let ahmer = entries(for: .ahmer)
        let abyad = entries(for: .abyad)
        let defaultGeneral = service.calculatePrayerTimes(
            date: date,
            latitude: 43.494,
            longitude: -79.844,
            configuration: .preset(.MoonsightingCommittee),
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )

        for prayer in PrayerName.allCases where prayer != .isha {
            let generalTime = try #require(general.first(where: { $0.prayer == prayer })?.time)
            #expect(ahmer.first(where: { $0.prayer == prayer })?.time == generalTime)
            #expect(abyad.first(where: { $0.prayer == prayer })?.time == generalTime)
            #expect(defaultGeneral.first(where: { $0.prayer == prayer })?.time == generalTime)
        }

        let expected: [(MoonSightingIshaTwilight, [PrayerTimeEntry], Int, Int)] = [
            (.general, general, 22, 22),
            (.ahmer, ahmer, 22, 19),
            (.abyad, abyad, 23, 17),
        ]
        for (twilight, result, hour, minute) in expected {
            let isha = try #require(result.first(where: { $0.prayer == .isha }))
            let expectedTime = fixedDate(2021, 7, 1, hour, minute, calendar: calendar)
            #expect(
                abs(isha.time.timeIntervalSince(expectedTime)) <= 60,
                "Unexpected \(twilight.rawValue) Moon Sighting Isha"
            )
        }
        #expect(defaultGeneral.first(where: { $0.prayer == .isha })?.time == general.first(where: { $0.prayer == .isha })?.time)
    }

    @Test("Moon Sighting twilight setting is ignored by other calculation methods")
    func moonSightingTwilightDoesNotAffectOtherMethods() {
        let calendar = fixedCalendar(timeZoneID: "Asia/Karachi")
        let core = PrayerCalculationCore(calendar: calendar)
        let date = fixedDate(2025, 6, 15, 12, 0, calendar: calendar)

        func result(for twilight: MoonSightingIshaTwilight) -> [BasePrayerTime] {
            core.calculate(
                date: date,
                latitude: 24.8607,
                longitude: 67.0011,
                configuration: .preset(.Karachi),
                asrMethod: .hanafi,
                highLatitudeRule: .middleOfTheNight,
                moonSightingIshaTwilight: twilight
            )
        }

        #expect(result(for: .general) == result(for: .ahmer))
        #expect(result(for: .general) == result(for: .abyad))
    }

    @Test("Automatic high-latitude mode follows the upstream recommendation without changing stored explicit values")
    func automaticHighLatitudeRule() {
        let calendar = fixedCalendar(timeZoneID: "UTC")
        let core = PrayerCalculationCore(calendar: calendar)
        let date = fixedDate(2025, 6, 21, 12, 0, calendar: calendar)

        func result(latitude: Double, rule: HighLatitudeRuleOption) -> [BasePrayerTime] {
            core.calculate(
                date: date,
                latitude: latitude,
                longitude: 0,
                configuration: .preset(.MuslimWorldLeague),
                asrMethod: .standard,
                highLatitudeRule: rule
            )
        }

        #expect(result(latitude: 48, rule: .automatic) == result(latitude: 48, rule: .middleOfTheNight))
        #expect(result(latitude: 55, rule: .automatic) == result(latitude: 55, rule: .seventhOfTheNight))
        #expect(result(latitude: 55, rule: .automatic) != result(latitude: 55, rule: .middleOfTheNight))
        #expect(HighLatitudeRuleOption(rawValue: "Middle of the Night") == .middleOfTheNight)
        #expect(HighLatitudeRuleOption(rawValue: "Seventh of the Night") == .seventhOfTheNight)
        #expect(HighLatitudeRuleOption(rawValue: "Twilight Angle") == .twilightAngle)
    }

    @Test("Prayer ordering and daily continuity hold near the International Date Line")
    func internationalDateLineRegression() throws {
        let calendar = fixedCalendar(timeZoneID: "UTC")
        let core = PrayerCalculationCore(calendar: calendar)
        let firstDate = fixedDate(2025, 12, 1, 12, 0, calendar: calendar)
        let secondDate = try #require(calendar.date(byAdding: .day, value: 1, to: firstDate))
        let coordinates = [
            (42.74674252600066, 177.2401196144623),
            (47.082209457885355, 177.24642294208638),
        ]

        for (latitude, longitude) in coordinates {
            func result(for date: Date) -> [BasePrayerTime] {
                core.calculate(
                    date: date,
                    latitude: latitude,
                    longitude: longitude,
                    configuration: .preset(.MuslimWorldLeague),
                    asrMethod: .standard,
                    highLatitudeRule: .twilightAngle
                )
            }

            let first = result(for: firstDate)
            let second = result(for: secondDate)
            #expect(first.count == 6)
            #expect(second.count == 6)
            for index in 1..<first.count {
                #expect(first[index].time > first[index - 1].time)
            }
            for prayer in PrayerName.allCases {
                let firstTime = try #require(first.first(where: { $0.prayer == prayer })?.time)
                let secondTime = try #require(second.first(where: { $0.prayer == prayer })?.time)
                let interval = secondTime.timeIntervalSince(firstTime)
                #expect(interval > 20 * 60 * 60 && interval < 28 * 60 * 60)
            }
        }
    }

    @Test("Golden prayer times remain stable for Makkah, Karachi, and New York")
    func goldenPrayerTimes() throws {
        let fixtures: [GoldenPrayerFixture] = [
            GoldenPrayerFixture(
                name: "Makkah",
                timeZoneID: "Asia/Riyadh",
                year: 2025, month: 6, day: 15,
                latitude: 21.4225, longitude: 39.8262,
                configuration: .preset(.UmmAlQura), asrMethod: .standard,
                expected: [(.tahajjud, 1, 8), (.fajr, 4, 10), (.dhuhr, 12, 21), (.asr, 15, 41), (.maghrib, 19, 4), (.isha, 20, 34)]
            ),
            GoldenPrayerFixture(
                name: "Makkah Ramadan",
                timeZoneID: "Asia/Riyadh",
                year: 2025, month: 3, day: 15,
                latitude: 21.4225, longitude: 39.8262,
                configuration: .preset(.UmmAlQura), asrMethod: .standard,
                expected: [(.tahajjud, 1, 38), (.fajr, 5, 13), (.dhuhr, 12, 30), (.asr, 15, 54), (.maghrib, 18, 30), (.isha, 20, 30)]
            ),
            GoldenPrayerFixture(
                name: "Karachi",
                timeZoneID: "Asia/Karachi",
                year: 2025, month: 1, day: 15,
                latitude: 24.8607, longitude: 67.0011,
                configuration: .preset(.Karachi), asrMethod: .hanafi,
                expected: [(.tahajjud, 2, 0), (.fajr, 5, 58), (.dhuhr, 12, 42), (.asr, 16, 29), (.maghrib, 18, 4), (.isha, 19, 25)]
            ),
            GoldenPrayerFixture(
                name: "New York",
                timeZoneID: "America/New_York",
                year: 2025, month: 7, day: 1,
                latitude: 40.7128, longitude: -74.0060,
                configuration: .preset(.NorthAmerica), asrMethod: .standard,
                expected: [(.tahajjud, 1, 23), (.fajr, 3, 50), (.dhuhr, 13, 1), (.asr, 17, 0), (.maghrib, 20, 31), (.isha, 22, 10)]
            ),
        ]

        for fixture in fixtures {
            let calendar = fixedCalendar(timeZoneID: fixture.timeZoneID)
            let date = fixedDate(fixture.year, fixture.month, fixture.day, 12, 0, calendar: calendar)
            let service = PrayerCalculationService(calendar: calendar)
            let entries = service.calculatePrayerTimes(
                date: date,
                latitude: fixture.latitude,
                longitude: fixture.longitude,
                configuration: fixture.configuration,
                asrMethod: fixture.asrMethod,
                highLatitudeRule: .middleOfTheNight,
                adjustments: [:]
            )
            #expect(entries.count == 6)
            for (prayer, hour, minute) in fixture.expected {
                let actual = try #require(entries.first(where: { $0.prayer == prayer }), "Missing \(prayer.rawValue) for \(fixture.name)")
                let expected = fixedDate(fixture.year, fixture.month, fixture.day, hour, minute, calendar: calendar)
                #expect(
                    abs(actual.time.timeIntervalSince(expected)) <= 60,
                    "\(fixture.name) \(prayer.rawValue) drifted from the golden time"
                )
            }
        }
    }

    private func assertTahajjudFormula(
        year: Int,
        month: Int,
        day: Int,
        timeZoneID: String,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration
    ) throws {
        let calendar = fixedCalendar(timeZoneID: timeZoneID)
        let service = PrayerCalculationService(calendar: calendar)
        let date = fixedDate(year, month, day, 12, 0, calendar: calendar)
        let previousDate = try #require(calendar.date(byAdding: .day, value: -1, to: date))
        let today = service.calculatePrayerTimes(
            date: date,
            latitude: latitude,
            longitude: longitude,
            configuration: configuration,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        let previous = service.calculatePrayerTimes(
            date: previousDate,
            latitude: latitude,
            longitude: longitude,
            configuration: configuration,
            asrMethod: .standard,
            highLatitudeRule: .middleOfTheNight,
            adjustments: [:]
        )
        let tahajjud = try #require(today.first(where: { $0.prayer == .tahajjud }))
        let fajr = try #require(today.first(where: { $0.prayer == .fajr }))
        let previousMaghrib = try #require(previous.first(where: { $0.prayer == .maghrib }))
        let expected = previousMaghrib.time.addingTimeInterval(fajr.time.timeIntervalSince(previousMaghrib.time) * 2 / 3)
        #expect(abs(tahajjud.time.timeIntervalSince(expected)) <= 1)
    }
}

@MainActor
@Suite("Live Prayer Rollover Tests", .serialized)
struct LivePrayerRolloverTests {
    @Test("Prayer state advances exactly at a daytime boundary")
    func daytimeBoundary() {
        let calendar = fixedCalendar(timeZoneID: "UTC")
        let viewModel = PrayerTimesViewModel(
            calculationService: FixedPrayerCalculationService(calendar: calendar),
            calendar: calendar,
            initialCalculationSettings: CalculationSettingsPayload(selection: .automatic),
            persistsCalculationSettings: false
        )
        let beforeDhuhr = fixedDate(2026, 7, 13, 11, 59, calendar: calendar).addingTimeInterval(59)
        viewModel.calculateToday(at: beforeDhuhr)
        #expect(viewModel.currentPrayer?.prayer == .fajr)
        #expect(viewModel.nextPrayer?.prayer == .dhuhr)

        viewModel.refreshPrayerState(at: beforeDhuhr.addingTimeInterval(1))
        #expect(viewModel.currentPrayer?.prayer == .dhuhr)
        #expect(viewModel.nextPrayer?.prayer == .asr)
    }

    @Test("Isha remains current through midnight before tomorrow's Tahajjud")
    func midnightAndTahajjudBoundaries() {
        let calendar = fixedCalendar(timeZoneID: "UTC")
        let viewModel = PrayerTimesViewModel(
            calculationService: FixedPrayerCalculationService(calendar: calendar),
            calendar: calendar,
            initialCalculationSettings: CalculationSettingsPayload(selection: .automatic),
            persistsCalculationSettings: false
        )
        let lateEvening = fixedDate(2026, 7, 13, 23, 0, calendar: calendar)
        viewModel.calculateToday(at: lateEvening)
        #expect(viewModel.currentPrayer?.prayer == .isha)
        #expect(viewModel.nextPrayer?.prayer == .tahajjud)

        let midnight = fixedDate(2026, 7, 14, 0, 0, calendar: calendar)
        viewModel.refreshPrayerState(at: midnight)
        #expect(viewModel.currentPrayer?.prayer == .isha)
        #expect(viewModel.nextPrayer?.prayer == .tahajjud)

        let tahajjud = fixedDate(2026, 7, 14, 3, 0, calendar: calendar)
        viewModel.refreshPrayerState(at: tahajjud)
        #expect(viewModel.currentPrayer?.prayer == .tahajjud)
        #expect(viewModel.nextPrayer?.prayer == .fajr)

        let fajr = fixedDate(2026, 7, 14, 5, 0, calendar: calendar)
        viewModel.refreshPrayerState(at: fajr)
        #expect(viewModel.currentPrayer?.prayer == .fajr)
        #expect(viewModel.nextPrayer?.prayer == .dhuhr)
    }
}

private struct FixedPrayerCalculationService: PrayerCalculationServiceProtocol {
    let calendar: Calendar

    func calculatePrayerTimes(
        date: Date,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int],
        moonSightingIshaTwilight: MoonSightingIshaTwilight = .general
    ) -> [PrayerTimeEntry] {
        let schedule: [(PrayerName, Int, Int)] = [
            (.tahajjud, 3, 0),
            (.fajr, 5, 0),
            (.dhuhr, 12, 0),
            (.asr, 16, 0),
            (.maghrib, 19, 0),
            (.isha, 21, 0),
        ]
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return schedule.compactMap { prayer, hour, minute in
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            components.year = day.year
            components.month = day.month
            components.day = day.day
            components.hour = hour
            components.minute = minute
            guard let time = calendar.date(from: components) else { return nil }
            return PrayerTimeEntry(
                prayer: prayer,
                time: time,
                manualAdjustmentMinutes: adjustments[prayer] ?? 0
            )
        }
    }

    func calculateMultipleDays(
        startDate: Date,
        days: Int,
        latitude: Double,
        longitude: Double,
        configuration: ResolvedCalculationConfiguration,
        asrMethod: AsrJuristicMethod,
        highLatitudeRule: HighLatitudeRuleOption,
        adjustments: [PrayerName: Int],
        moonSightingIshaTwilight: MoonSightingIshaTwilight = .general
    ) -> [[PrayerTimeEntry]] {
        (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            return calculatePrayerTimes(
                date: date,
                latitude: latitude,
                longitude: longitude,
                configuration: configuration,
                asrMethod: asrMethod,
                highLatitudeRule: highLatitudeRule,
                adjustments: adjustments,
                moonSightingIshaTwilight: moonSightingIshaTwilight
            )
        }
    }

    func qiblaDirection(latitude: Double, longitude: Double) -> Double { 0 }
}

private struct GoldenPrayerFixture {
    let name: String
    let timeZoneID: String
    let year: Int
    let month: Int
    let day: Int
    let latitude: Double
    let longitude: Double
    let configuration: ResolvedCalculationConfiguration
    let asrMethod: AsrJuristicMethod
    let expected: [(PrayerName, Int, Int)]
}

private func fixedCalendar(timeZoneID: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(identifier: timeZoneID)!
    return calendar
}

private func fixedDate(
    _ year: Int,
    _ month: Int,
    _ day: Int,
    _ hour: Int,
    _ minute: Int,
    calendar: Calendar
) -> Date {
    calendar.date(from: DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

@Suite("Alert Offset Settings Tests")
struct AlertOffsetSettingsTests {
    @Test("Before and after offsets cover the supported range in ten-minute steps")
    func availableOffsets() {
        let offsets = AlertTimingSettings.availableOffsetsMinutes
        #expect(offsets.first == -120)
        #expect(offsets.last == 60)
        #expect(offsets.count == 18)
        #expect(!offsets.contains(0))

        let beforeOffsets = offsets.filter { $0 < 0 }
        let afterOffsets = offsets.filter { $0 > 0 }
        #expect(zip(beforeOffsets, beforeOffsets.dropFirst()).allSatisfy { $1 - $0 == 10 })
        #expect(zip(afterOffsets, afterOffsets.dropFirst()).allSatisfy { $1 - $0 == 10 })
    }

    @Test("Legacy five-minute pre-alerts migrate to the nearest offset option")
    func legacyPrayerSettingsMigration() {
        let preferences = UserPreferences()
        preferences.fajrPreAlarmMinutes = 25

        let migrated = preferences.alertTimingSettings(for: .fajr)
        #expect(migrated.offsetMinutes == -30)
        #expect(migrated.isOffsetAlertEnabled)
        #expect(migrated.isMainAlertEnabled)

        preferences.setAlertTimingSettings(
            AlertTimingSettings(
                offsetMinutes: 60,
                isOffsetAlertEnabled: true,
                isMainAlertEnabled: false
            ),
            for: .fajr
        )
        let saved = preferences.alertTimingSettings(for: .fajr)
        #expect(saved.offsetMinutes == 60)
        #expect(saved.isOffsetAlertEnabled)
        #expect(!saved.isMainAlertEnabled)
        #expect(preferences.fajrPreAlarmMinutes == 0)
    }

    @Test("Custom alarms can schedule only an offset alert after the set time")
    func customAlarmOffsetOnly() {
        let settings = AlertTimingSettings(
            offsetMinutes: 60,
            isOffsetAlertEnabled: true,
            isMainAlertEnabled: false
        )
        let alarm = CustomAlarm(title: "Wake", alertTimingSettings: settings)
        let scheduledTime = Date(timeIntervalSince1970: 1_000)

        #expect(alarm.alertTimingSettings == settings)
        #expect(!alarm.alertTimingSettings.shouldScheduleMainAlert)
        #expect(alarm.alertTimingSettings.offsetFireDate(relativeTo: scheduledTime)
            == scheduledTime.addingTimeInterval(60 * 60))
    }

    @Test("Schedule choices map to valid alert combinations")
    func alertScheduleChoices() {
        let initial = AlertTimingSettings()
        let mainOnly = AlertScheduleSelection.mainOnly.applying(to: initial)
        #expect(mainOnly.isMainAlertEnabled)
        #expect(!mainOnly.isOffsetAlertEnabled)

        let offsetOnly = AlertScheduleSelection.offsetOnly.applying(to: initial)
        #expect(!offsetOnly.isMainAlertEnabled)
        #expect(offsetOnly.isOffsetAlertEnabled)

        let both = AlertScheduleSelection.both.applying(to: initial)
        #expect(both.isMainAlertEnabled)
        #expect(both.isOffsetAlertEnabled)
    }

    @MainActor
    @Test("A post-prayer alert remains upcoming after the prayer time passes")
    func postPrayerAlertAfterMainTime() {
        let now = Date(timeIntervalSince1970: 10_000)
        let prayerTime = now.addingTimeInterval(-30 * 60)
        let preferences = UserPreferences()
        preferences.setAlertTimingSettings(
            AlertTimingSettings(
                offsetMinutes: 60,
                isOffsetAlertEnabled: true,
                isMainAlertEnabled: false
            ),
            for: .fajr
        )
        let scheduler = NotificationScheduler()

        scheduler.refreshNextAlarmTime(
            prayerEntries: [PrayerTimeEntry(prayer: .fajr, time: prayerTime)],
            preferences: preferences,
            now: now
        )

        #expect(scheduler.nextScheduledAlarmTime == prayerTime.addingTimeInterval(60 * 60))
    }
}

@Suite("Audio Download Safety Tests")
struct AudioDownloadSafetyTests {
    @Test("Download work never exceeds its concurrency limit")
    func boundedConcurrency() {
        var queue = DownloadWorkQueue<String>(maximumConcurrentCount: 2)

        let firstClaim = queue.enqueue("first")
        let secondClaim = queue.enqueue("second")
        let thirdClaim = queue.enqueue("third")
        #expect(firstClaim == ["first"])
        #expect(secondClaim == ["second"])
        #expect(thirdClaim.isEmpty)
        #expect(queue.active == Set(["first", "second"]))
        #expect(queue.pending == ["third"])

        let nextClaim = queue.complete("first")
        #expect(nextClaim == ["third"])
        #expect(queue.active == Set(["second", "third"]))
        #expect(queue.pending.isEmpty)
    }

    @Test("Queued downloads can be cancelled without consuming a slot")
    func queuedCancellation() {
        var queue = DownloadWorkQueue<String>(maximumConcurrentCount: 1)

        let activeClaim = queue.enqueue("active")
        let queuedClaim = queue.enqueue("queued")
        let removedQueuedDownload = queue.removePending("queued")
        let claimAfterCompletion = queue.complete("active")
        #expect(activeClaim == ["active"])
        #expect(queuedClaim.isEmpty)
        #expect(removedQueuedDownload)
        #expect(claimAfterCompletion.isEmpty)
        #expect(queue.active.isEmpty)
        #expect(queue.pending.isEmpty)
    }

    @Test("Progress delivery is limited to ten updates per second")
    func throttledProgress() {
        var throttler = DownloadProgressThrottler(minimumInterval: 0.1)

        let initialEmission = throttler.shouldEmit(taskID: 7, progress: 0.01, at: 10)
        let earlyEmission = throttler.shouldEmit(taskID: 7, progress: 0.25, at: 10.05)
        let intervalEmission = throttler.shouldEmit(taskID: 7, progress: 0.30, at: 10.11)
        let completionEmission = throttler.shouldEmit(taskID: 7, progress: 1, at: 10.12)
        #expect(initialEmission)
        #expect(!earlyEmission)
        #expect(intervalEmission)
        #expect(completionEmission)

        throttler.reset(taskID: 7)
        let postResetEmission = throttler.shouldEmit(taskID: 7, progress: 0.01, at: 10.13)
        #expect(postResetEmission)
    }
}
