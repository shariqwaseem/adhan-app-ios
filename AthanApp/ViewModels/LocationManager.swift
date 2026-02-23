import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
final class LocationManager: NSObject {
    var latitude: Double = 0
    var longitude: Double = 0
    var cityName: String = "Unknown"
    var countryCode: String? = nil
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isAuthorized: Bool = false
    var locationError: String? = nil

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
        updateIsAuthorized()
    }

    func requestWhenInUsePermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysPermission() {
        manager.requestAlwaysAuthorization()
    }

    func requestLocation() {
        guard isAuthorized else {
            requestWhenInUsePermission()
            return
        }
        manager.requestLocation()
    }

    func startMonitoringSignificantLocationChanges() {
        guard isAuthorized else { return }
        manager.startMonitoringSignificantLocationChanges()
    }

    func stopMonitoringSignificantLocationChanges() {
        manager.stopMonitoringSignificantLocationChanges()
    }

    func searchCity(_ query: String) async -> [(name: String, latitude: Double, longitude: Double, countryCode: String?)] {
        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            return placemarks.compactMap { placemark in
                guard let location = placemark.location else { return nil }
                let name = [placemark.locality, placemark.administrativeArea, placemark.country]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                return (
                    name: name.isEmpty ? query : name,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    countryCode: placemark.isoCountryCode
                )
            }
        } catch {
            return []
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        Task {
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let placemark = placemarks.first {
                    self.cityName = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                    self.countryCode = placemark.isoCountryCode
                }
            } catch {
                self.cityName = "Lat: \(String(format: "%.2f", location.coordinate.latitude)), Lon: \(String(format: "%.2f", location.coordinate.longitude))"
            }
        }
    }

    private func updateIsAuthorized() {
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

extension LocationManager: @preconcurrency CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.locationError = nil
            reverseGeocode(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            self.locationError = error.localizedDescription
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            self.authorizationStatus = status
            updateIsAuthorized()
            if isAuthorized {
                self.manager.requestLocation()
                startMonitoringSignificantLocationChanges()
            }
        }
    }
}
