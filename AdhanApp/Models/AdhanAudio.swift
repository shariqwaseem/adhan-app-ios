import Foundation

struct AdhanAudioFile: Identifiable, Hashable {
    let id: String          // filename without extension, e.g. "Al-Arake"
    let displayName: String // human-readable, e.g. "Al Arake"
    let fileName: String    // full filename, e.g. "Al-Arake.caf"

    var bundleURL: URL? {
        Bundle.main.url(
            forResource: id,
            withExtension: "caf",
            subdirectory: "AdhanAudio"
        )
    }
}

enum AdhanAudioCatalog {
    static let allFiles: [AdhanAudioFile] = [
        "Adhan-Makkah-New",
        "Al-Aassaf-Iraq",
        "Al-Arake",
        "Al-Deen-Obade",
        "Al-Haddad",
        "Al-Jabar-Qatar",
        "Al-Majale",
        "Al-Maluke",
        "Al-Marush",
        "Al-Nabet-Qatar",
        "Al-Qaseme-Qatar",
        "Al-Qatami-Riyadh",
        "At-Trablsi",
        "Duman-Turkey",
        "El-Kourdi",
        "Majde",
        "Ramadan-Saad-Makkah",
    ].map { makeFile($0) }

    static func file(forID id: String) -> AdhanAudioFile? {
        allFiles.first { $0.id == id }
    }

    static func displayName(forID id: String) -> String {
        if id.isEmpty { return String(localized: "Default", bundle: LanguageManager.shared.bundle) }
        return file(forID: id)?.displayName ?? id.replacingOccurrences(of: "-", with: " ")
    }

    /// Returns the bundle-relative path for use with AlertConfiguration.AlertSound.named().
    /// e.g. "AdhanAudio/Al-Arake.caf"
    static func bundleRelativePath(forID id: String) -> String? {
        guard let file = file(forID: id) else { return nil }
        return "AdhanAudio/\(file.fileName)"
    }

    private static func makeFile(_ id: String) -> AdhanAudioFile {
        AdhanAudioFile(
            id: id,
            displayName: id.replacingOccurrences(of: "-", with: " "),
            fileName: "\(id).caf"
        )
    }
}
