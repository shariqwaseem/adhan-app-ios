import SwiftUI

struct LocationSettings: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [CitySearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        List {
            Section {
                Toggle("Automatic", isOn: automaticBinding)
                    .disabled(!locationManager.isAuthorized)

                if !locationManager.isAuthorized {
                    Button("Allow Location Permission", action: requestPermission)
                }

                LabeledContent("City") {
                    if locationManager.isLocating {
                        ProgressView()
                    } else {
                        Text(viewModel.cityName.isEmpty ? String(localized: "Not Set", bundle: LanguageManager.shared.bundle) : viewModel.cityName)
                    }
                }
            }

            if !locationManager.isAutomatic {
                Section {
                    TextField("Search City", text: $searchText)
                        .textContentType(.addressCity)
                        .autocorrectionDisabled()

                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(searchResults.enumerated()), id: \.offset) { _, result in
                        Button(result.fullName) {
                            selectCity(result)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .navigationTitle("Location")
        .animation(.default, value: locationManager.isAutomatic)
        .animation(.default, value: locationManager.isAuthorized)
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else {
                searchResults = []
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                isSearching = true
                let results = await locationManager.searchCity(trimmed)
                if Task.isCancelled {
                    isSearching = false
                    return
                }
                searchResults = results
                isSearching = false
            }
        }
    }

    private var automaticBinding: Binding<Bool> {
        Binding {
            locationManager.isAutomatic
        } set: { isOn in
            locationManager.prefersAutomatic = isOn
            // Refresh right away so turning Automatic on immediately replaces the manual city.
            if isOn {
                locationManager.requestLocation()
            }
        }
    }

    private func requestPermission() {
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestLocation()
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func selectCity(_ result: CitySearchResult) {
        locationManager.setManualLocation(
            latitude: result.latitude,
            longitude: result.longitude,
            cityName: result.cityName,
            countryCode: result.countryCode
        )
        dismiss()
    }
}
