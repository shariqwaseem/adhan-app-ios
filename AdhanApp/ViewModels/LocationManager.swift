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
    var isLocating = false

    /// The user's choice. Automatic follows GPS (and travel); manual keeps the chosen city.
    var prefersAutomatic: Bool = !SharedDataManager.loadUsesManualLocation() {
        didSet {
            guard oldValue != prefersAutomatic else { return }
            SharedDataManager.saveUsesManualLocation(!prefersAutomatic)
            SignificantLocationChangeService.shared.startMonitoringIfAuthorized()
        }
    }

    /// Automatic is only in effect while location access is granted.
    var isAutomatic: Bool {
        prefersAutomatic && isAuthorized
    }

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var requestsLocationAfterAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
        updateIsAuthorized()
    }

    func requestWhenInUsePermission() {
        requestsLocationAfterAuthorization = true
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
        isLocating = true
        manager.requestLocation()
    }

    func searchCity(_ query: String) async -> [CitySearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.compactMap { item in
                let placemark = item.placemark
                let parts = [placemark.locality, placemark.administrativeArea, placemark.country].compactMap { $0 }
                guard let cityName = parts.first else { return nil }
                return CitySearchResult(
                    fullName: parts.joined(separator: ", "),
                    cityName: cityName,
                    latitude: placemark.coordinate.latitude,
                    longitude: placemark.coordinate.longitude,
                    countryCode: placemark.isoCountryCode
                )
            }
        } catch {
            return []
        }
    }

    /// Pins prayer times to a chosen city. Only counts as choosing manual mode when
    /// automatic was available; without permission it's a fallback until access is granted.
    func setManualLocation(latitude: Double, longitude: Double, cityName: String, countryCode: String?) {
        if isAuthorized {
            prefersAutomatic = false
        }
        isLocating = false
        apply(latitude: latitude, longitude: longitude, cityName: cityName, countryCode: countryCode)
    }

    private func reverseGeocode(_ location: CLLocation) {
        Task {
            var name = "Lat: \(String(format: "%.2f", location.coordinate.latitude)), Lon: \(String(format: "%.2f", location.coordinate.longitude))"
            var country: String?
            if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
                name = placemark.locality ?? placemark.administrativeArea ?? "Unknown"
                country = placemark.isoCountryCode
            }
            self.isLocating = false
            // The user may have switched to manual while geocoding.
            guard self.isAutomatic else { return }
            self.apply(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                cityName: name,
                countryCode: country
            )
        }
    }

    private func apply(latitude: Double, longitude: Double, cityName: String, countryCode: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
        self.countryCode = countryCode
        lastLocationUpdate = Date()
    }

    private func updateIsAuthorized() {
        isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            self.locationError = nil
            guard self.isAutomatic else {
                self.isLocating = false
                return
            }
            reverseGeocode(location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            self.locationError = error.localizedDescription
            self.isLocating = false
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            let wasAuthorized = isAuthorized
            self.authorizationStatus = status
            updateIsAuthorized()
            // Newly granted access re-enables automatic mode, so fetch right away.
            let becameAutomatic = !wasAuthorized && isAutomatic
            if isAuthorized && (requestsLocationAfterAuthorization || becameAutomatic) {
                requestsLocationAfterAuthorization = false
                isLocating = true
                self.manager.requestLocation()
            } else if status == .denied || status == .restricted {
                requestsLocationAfterAuthorization = false
            }
            SignificantLocationChangeService.shared.startMonitoringIfAuthorized()
        }
    }
}

struct CitySearchResult {
    /// "Karachi, Sindh, Pakistan" — shown in search results to tell places apart.
    let fullName: String
    /// "Karachi" — what's saved and shown once selected.
    let cityName: String
    let latitude: Double
    let longitude: Double
    let countryCode: String?
}
