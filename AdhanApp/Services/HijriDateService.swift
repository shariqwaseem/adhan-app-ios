import Foundation

struct HijriDateService: Sendable {
    private static let hijriCalendar: Calendar = {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale.current
        return cal
    }()

    func hijriDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Self.hijriCalendar
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func hijriComponents(for date: Date) -> DateComponents {
        Self.hijriCalendar.dateComponents([.year, .month, .day], from: date)
    }

    func isRamadan(on date: Date) -> Bool {
        let components = hijriComponents(for: date)
        return components.month == 9
    }

    func ramadanDay(on date: Date) -> Int? {
        guard isRamadan(on: date) else { return nil }
        return hijriComponents(for: date).day
    }
}
