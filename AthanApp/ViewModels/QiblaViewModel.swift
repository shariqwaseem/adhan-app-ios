import Foundation
import CoreLocation
import Observation
import UIKit

@Observable
@MainActor
final class QiblaViewModel: NSObject {
    var heading: Double = 0
    var qiblaBearing: Double = 0
    var isAligned: Bool = false

    private let manager = CLLocationManager()
    private let alignmentThreshold: Double = 5.0
    private var feedbackGenerator: UIImpactFeedbackGenerator?

    override init() {
        super.init()
        manager.delegate = self
    }

    func startUpdating() {
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
            feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
            feedbackGenerator?.prepare()
        }
    }

    func stopUpdating() {
        manager.stopUpdatingHeading()
        feedbackGenerator = nil
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

extension QiblaViewModel: @preconcurrency CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let headingValue = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        MainActor.assumeIsolated {
            self.heading = headingValue
            checkAlignment()
        }
    }
}
