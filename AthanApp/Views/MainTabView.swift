import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "clock.fill") {
                HomeView()
            }

            Tab("Prayer", systemImage: "bell.fill") {
                PrayerSettingsView()
            }

            Tab("Qibla", systemImage: "location.north.fill") {
                QiblaView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
