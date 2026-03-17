import Foundation

struct AdhanAudioFile: Identifiable, Hashable {
    let id: String          // filename without extension, e.g. "Al-Arake"
    let displayName: String // human-readable, e.g. "Al Arake"
    let fileName: String    // full filename, e.g. "Al-Arake.caf"

    var localFileURL: URL {
        let libraryDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return libraryDir.appendingPathComponent("Sounds/\(fileName)")
    }

    var playbackURL: URL? {
        isDownloaded ? localFileURL : nil
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localFileURL.path)
    }

    var downloadURL: URL {
        URL(string: "\(AdhanAudioCatalog.baseURL)/\(id).caf")!
    }
}

enum AdhanAudioCatalog {
    static let baseURL = "https://pub-266c20788f114addb715d76354fbf729.r2.dev/adhan_audio"

    static let allFiles: [AdhanAudioFile] = [
        "Adhan-Makkah-New",
        "Al-Aassaf-Iraq",
        "Al-Deen-Obade",
        "Al-Haddad",
        "Al-Jabar-Qatar",
        "Al-Majale",
        "Al-Maluke",
        "Al-Marush",
        "Al-Nabet-Qatar",
        "Al-Qaseme-Qatar",
        "Al-Qatami-Riyadh",
        "El-Kourdi",
        "Ramadan-Saad-Makkah",
    ].map { makeFile($0) }

    static func file(forID id: String) -> AdhanAudioFile? {
        allFiles.first { $0.id == id }
    }

    static func displayName(forID id: String) -> String {
        if id.isEmpty { return String(localized: "Default", bundle: LanguageManager.shared.bundle) }
        return file(forID: id)?.displayName ?? id.replacingOccurrences(of: "-", with: " ")
    }

    /// Returns the sound path for use with AlertConfiguration.AlertSound.named().
    /// Downloaded → "{fileName}" (AlarmKit finds it in Library/Sounds/)
    /// Not downloaded → nil (triggers fallback to default)
    static func alarmSoundPath(forID id: String) -> String? {
        guard let file = file(forID: id) else { return nil }
        return file.isDownloaded ? file.fileName : nil
    }

    /// Backward-compatible alias.
    static func bundleRelativePath(forID id: String) -> String? {
        alarmSoundPath(forID: id)
    }

    private static func makeFile(_ id: String) -> AdhanAudioFile {
        AdhanAudioFile(
            id: id,
            displayName: id.replacingOccurrences(of: "-", with: " "),
            fileName: "\(id).caf"
        )
    }
}
