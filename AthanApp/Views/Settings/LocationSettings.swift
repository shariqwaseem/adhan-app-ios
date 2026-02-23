import SwiftUI

struct LocationSettings: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var searchResults: [(name: String, latitude: Double, longitude: Double, countryCode: String?)] = []
    @State private var isSearching = false

    var body: some View {
        List {
            Section("Current Location") {
                if locationManager.isAuthorized {
                    LabeledContent("City", value: locationManager.cityName)
                    LabeledContent("Coordinates") {
                        Text("\(locationManager.latitude, specifier: "%.4f"), \(locationManager.longitude, specifier: "%.4f")")
                            .font(.caption)
                    }
                    Button("Refresh Location") {
                        locationManager.requestLocation()
                    }
                } else {
                    Button("Enable Location Services") {
                        locationManager.requestWhenInUsePermission()
                    }
                }

                if let error = locationManager.locationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Search City") {
                TextField("City name", text: $searchText)
                    .textContentType(.addressCity)
                    .onSubmit {
                        performSearch()
                    }

                if isSearching {
                    ProgressView()
                }

                ForEach(Array(searchResults.enumerated()), id: \.offset) { _, result in
                    Button {
                        selectCity(result)
                    } label: {
                        Text(result.name)
                    }
                }
            }
        }
        .navigationTitle("Location")
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        Task {
            searchResults = await locationManager.searchCity(searchText)
            isSearching = false
        }
    }

    private func selectCity(_ result: (name: String, latitude: Double, longitude: Double, countryCode: String?)) {
        viewModel.updateLocation(
            latitude: result.latitude,
            longitude: result.longitude,
            cityName: result.name,
            countryCode: result.countryCode
        )
        searchResults = []
        searchText = ""
    }
}
