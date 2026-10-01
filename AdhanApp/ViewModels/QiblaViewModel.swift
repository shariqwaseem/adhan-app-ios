import Foundation
import CoreLocation
import Observation
import UIKit

@Observable
@MainActor
final class QiblaViewModel: NSObject {
    /// Continuous (unwrapped) heading: it keeps counting past 360 and below 0
    /// so that crossing north never animates the long way round.
    var heading: Double = 0
    var hasHeading: Bool = false
    var qiblaBearing: Double = 0
    var isAligned: Bool = false

    private var manager: CLLocationManager?
    private let alignmentThreshold: Double = 4.0
    private var feedbackGenerator: UIImpactFeedbackGenerator?

    func startUpdating() {
        guard CLLocationManager.headingAvailable() else {
            hasHeading = true
            return
        }

        if manager == nil {
            let m = CLLocationManager()
            m.delegate = self
            m.headingFilter = kCLHeadingFilterNone
            manager = m
        }

        manager?.startUpdatingHeading()
        feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator?.prepare()
    }

    func stopUpdating() {
        manager?.stopUpdatingHeading()
        feedbackGenerator = nil
        hasHeading = false
    }

    private func update(rawHeading: Double) {
        if hasHeading {
            let delta = (rawHeading - heading).truncatingRemainder(dividingBy: 360)
            heading += delta > 180 ? delta - 360 : (delta < -180 ? delta + 360 : delta)
        } else {
            heading = rawHeading
            hasHeading = true
        }
        checkAlignment()
    }

    private func checkAlignment() {
        let diff = abs(heading - qiblaBearing).truncatingRemainder(dividingBy: 360)
        let angularDiff = min(diff, 360 - diff)
        let wasAligned = isAligned
        isAligned = angularDiff <= alignmentThreshold

        if isAligned && !wasAligned {
            feedbackGenerator?.impactOccurred()
        }
    }
}

extension QiblaViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let headingValue = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        MainActor.assumeIsolated {
            update(rawHeading: headingValue)
        }
    }
}
