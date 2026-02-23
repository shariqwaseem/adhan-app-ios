import SwiftUI
import SwiftData

@main
struct AthanApp: App {
    @State private var prayerTimesViewModel = PrayerTimesViewModel()
    @State private var locationManager = LocationManager()
    @State private var notificationScheduler = NotificationScheduler()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(prayerTimesViewModel)
                .environment(locationManager)
                .environment(notificationScheduler)
                .task {
                    locationManager.requestWhenInUsePermission()
                    await notificationScheduler.requestPermission()
                }
                .onChange(of: locationManager.latitude) { _, _ in
                    onLocationChanged()
                }
                .onChange(of: locationManager.longitude) { _, _ in
                    onLocationChanged()
                }
        }
        .modelContainer(for: UserPreferences.self)
    }

    private func onLocationChanged() {
        guard locationManager.latitude != 0 || locationManager.longitude != 0 else { return }
        prayerTimesViewModel.updateLocation(
            latitude: locationManager.latitude,
            longitude: locationManager.longitude,
            cityName: locationManager.cityName,
            countryCode: locationManager.countryCode
        )
        Task {
            await notificationScheduler.rescheduleAll(
                prayerEntries: prayerTimesViewModel.sevenDayTimes(),
                preferences: nil
            )
        }
    }
}
