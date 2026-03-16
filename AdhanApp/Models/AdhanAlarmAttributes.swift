import Foundation

#if canImport(AlarmKit)
import AlarmKit

@available(iOS 26, *)
struct AdhanAlarmMetadata: AlarmMetadata {
    var prayerName: String
    var prayerTime: Date
}
#endif
