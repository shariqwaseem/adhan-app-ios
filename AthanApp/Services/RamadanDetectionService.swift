import Foundation

struct RamadanDetectionService: Sendable {
    private let hijriService = HijriDateService()

    func isRamadan(on date: Date = Date()) -> Bool {
        hijriService.isRamadan(on: date)
    }

    func ramadanDay(on date: Date = Date()) -> Int? {
        hijriService.ramadanDay(on: date)
    }

    func suhoorTime(fajrTime: Date, bufferMinutes: Int = 10) -> Date {
        Calendar.current.date(byAdding: .minute, value: -bufferMinutes, to: fajrTime) ?? fajrTime
    }

    func iftarTime(maghribTime: Date) -> Date {
        maghribTime
    }

    func ramadanInfo(
        fajrTime: Date,
        maghribTime: Date,
        suhoorBuffer: Int = 10,
        on date: Date = Date()
    ) -> RamadanInfo? {
        guard isRamadan(on: date) else { return nil }
        let day = ramadanDay(on: date) ?? 1
        let suhoor = suhoorTime(fajrTime: fajrTime, bufferMinutes: suhoorBuffer)
        let iftar = iftarTime(maghribTime: maghribTime)

        let now = date
        let isSuhoorCountdown = now < fajrTime
        let timeUntilSuhoor = suhoor.timeIntervalSince(now)
        let timeUntilIftar = iftar.timeIntervalSince(now)

        return RamadanInfo(
            day: day,
            suhoorTime: suhoor,
            iftarTime: iftar,
            isSuhoorCountdown: isSuhoorCountdown,
            timeUntilSuhoor: max(0, timeUntilSuhoor),
            timeUntilIftar: max(0, timeUntilIftar)
        )
    }
}

struct RamadanInfo: Sendable {
    let day: Int
    let suhoorTime: Date
    let iftarTime: Date
    let isSuhoorCountdown: Bool
    let timeUntilSuhoor: TimeInterval
    let timeUntilIftar: TimeInterval
}
