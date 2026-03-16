import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: String

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Prayer", systemImage: "clock.fill", value: "prayer") {
                HomeView()
            }

            Tab("Qibla", systemImage: "location.north.fill", value: "qibla") {
                QiblaView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: "settings") {
                SettingsView()
            }
        }
    }
}

#Preview {
    MainTabView(selectedTab: .constant("prayer"))
}
