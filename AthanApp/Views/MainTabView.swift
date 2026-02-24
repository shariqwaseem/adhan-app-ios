import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Prayer", systemImage: "clock.fill") {
                HomeView()
            }

            Tab("Qibla", systemImage: "location.north.fill") {
                QiblaView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }

            Tab("Test", systemImage: "hammer.fill") {
                TestView()
            }
        }
    }
}

#Preview {
    MainTabView()
}
