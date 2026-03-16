import SwiftUI

struct LocationSettings: View {
    @Environment(LocationManager.self) private var locationManager
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [(name: String, latitude: Double, longitude: Double, countryCode: String?)] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isLocating = false

    var body: some View {
        List {
            Section {
                Button {
                    isLocating = true
                    locationManager.requestLocation()
                } label: {
                    HStack {
                        Label("Use Current Location", systemImage: "location.fill")
                        if isLocating {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isLocating)
            } footer: {
                if viewModel.cityName.isEmpty == false {
                    Text("Currently set to \(viewModel.cityName)")
                }
            }

            Section("Search City") {
                TextField("Type a city name...", text: $searchText)
                    .textContentType(.addressCity)
                    .autocorrectionDisabled()

                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                ForEach(Array(searchResults.enumerated()), id: \.offset) { _, result in
                    Button {
                        selectCity(result)
                    } label: {
                        Label {
                            Text(result.name)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Location")
        .onChange(of: locationManager.lastLocationUpdate) { _, _ in
            guard isLocating else { return }
            isLocating = false
            dismiss()
        }
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
                guard !Task.isCancelled else { return }
                searchResults = results
                isSearching = false
            }
        }
    }

    private func selectCity(_ result: (name: String, latitude: Double, longitude: Double, countryCode: String?)) {
        viewModel.updateLocation(
            latitude: result.latitude,
            longitude: result.longitude,
            cityName: result.name,
            countryCode: result.countryCode,
            autoSetCalculationMethod: true
        )
        dismiss()
    }
}
