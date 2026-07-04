import Foundation

enum NumeralFormatter {
    static func format<T: BinaryInteger>(_ value: T, useArabicNumerals: Bool) -> String {
        format(String(value), useArabicNumerals: useArabicNumerals)
    }

    static func format(_ value: String, useArabicNumerals: Bool) -> String {
        guard useArabicNumerals else { return value }

        let easternArabicDigits: [Character: Character] = [
            "0": "٠",
            "1": "١",
            "2": "٢",
            "3": "٣",
            "4": "٤",
            "5": "٥",
            "6": "٦",
            "7": "٧",
            "8": "٨",
            "9": "٩"
        ]

        return String(value.map { easternArabicDigits[$0] ?? $0 })
    }
}
