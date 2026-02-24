import Foundation

enum AdhanAudioCategory: String, CaseIterable {
    case sunni = "Sunni"
    case shia = "Shia"
}

struct AdhanAudioFile: Identifiable, Hashable {
    let id: String          // filename without extension, e.g. "Abdul-Basit"
    let displayName: String // human-readable, e.g. "Abdul Basit"
    let category: AdhanAudioCategory
    let fileName: String    // full filename, e.g. "Abdul-Basit.caf"

    var bundleURL: URL? {
        Bundle.main.url(
            forResource: id,
            withExtension: "caf",
            subdirectory: "AdhanAudio/\(category.rawValue.lowercased())"
        )
    }
}

enum AdhanAudioCatalog {
    static let allFiles: [AdhanAudioFile] = sunniFiles + shiaFiles

    static let sunniFiles: [AdhanAudioFile] = [
        "Abdul-Basit",
        "Abdul-Ghaffar",
        "Abdul-Hakam",
        "Adhan-Alaqsa",
        "Adhan-Egypt",
        "Adhan-Halab",
        "Adhan-Madinah",
        "Adhan-Makkah",
        "Al-Hussaini",
        "Bakir-Bash",
        "Hafez",
        "Hafiz-Murad",
        "Minshawi",
        "Naghshbandi",
        "Saber",
        "Sharif-Doman",
        "Yusuf-Islam",
    ].map { makeFile($0, category: .sunni) }

    static let shiaFiles: [AdhanAudioFile] = [
        "Aghati",
        "Ghalwash",
        "Kazem-Zadeh",
        "Moazzen-Zadeh",
        "Mohammad-Zadeh",
        "Rezaeian",
        "Rowhani-Nejad",
        "Salimi",
        "Sharif",
        "Sobhdel",
        "Tasvieh-Chi",
        "Tookhi",
    ].map { makeFile($0, category: .shia) }

    static func file(forID id: String) -> AdhanAudioFile? {
        allFiles.first { $0.id == id }
    }

    static func displayName(forID id: String) -> String {
        if id.isEmpty { return "Default" }
        return file(forID: id)?.displayName ?? id
    }

    /// Returns the bundle-relative path for use with AlertConfiguration.AlertSound.named().
    /// e.g. "AdhanAudio/sunni/Abdul-Basit.caf"
    static func bundleRelativePath(forID id: String) -> String? {
        guard let file = file(forID: id) else { return nil }
        return "AdhanAudio/\(file.category.rawValue.lowercased())/\(file.fileName)"
    }

    private static func makeFile(_ id: String, category: AdhanAudioCategory) -> AdhanAudioFile {
        AdhanAudioFile(
            id: id,
            displayName: id.replacingOccurrences(of: "-", with: " "),
            category: category,
            fileName: "\(id).caf"
        )
    }
}
