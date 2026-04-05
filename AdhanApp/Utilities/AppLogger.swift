import Foundation
import os.log

enum AppLogger {
    private static let subsystem = "com.shariqw.adhanpro"

    static let calculation = Logger(subsystem: subsystem, category: "calculation")
    static let scheduling = Logger(subsystem: subsystem, category: "scheduling")
    static let alarm = Logger(subsystem: subsystem, category: "alarm")
    static let background = Logger(subsystem: subsystem, category: "background")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
