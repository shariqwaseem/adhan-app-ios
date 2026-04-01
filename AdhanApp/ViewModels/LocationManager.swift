import Foundation
import CoreLocation
import MapKit
import Observation

@Observable
@MainActor
final class LocationManager: NSObject {
    var latitude: Double = 0
    var longitude: Double = 0
    var cityName: String = "Set Location"
    var countryCode: String? = nil
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isAuthorized: Bool = false
    var locationError: String? = nil
    var lastLocationUpdate: Date? = nil
    var isManualLocationRequest: Bool = false

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
        isManualLocationRequest = true
        manager.requestLocation()
    }

    func searchCity(_ query: String) async -> [(name: String, latitude: Double, longitude: Double, countryCode: String?)] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.compactMap { item in
                let placemark = item.placemark
                let name = [placemark.locality, placemark.administrativeArea, placemark.country]
                    .compactMap { $0 }
                    .joined(separator: ", ")
                guard !name.isEmpty else { return nil }
                return (
                    name: name,
                    latitude: placemark.coordinate.latitude,
                    longitude: placemark.coordinate.longitude,
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
            self.lastLocationUpdate = Date()
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
            }
        }
    }
}
