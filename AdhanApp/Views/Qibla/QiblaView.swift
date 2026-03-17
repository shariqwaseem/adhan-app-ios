import SwiftUI

struct QiblaView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @Environment(LocationManager.self) private var locationManager
    @State private var qiblaViewModel = QiblaViewModel()

    private var qiblaAngle: Double {
        viewModel.qiblaDirection - qiblaViewModel.heading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (qiblaViewModel.isAligned ? Color.green : Color(.systemGroupedBackground))
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.3), value: qiblaViewModel.isAligned)

                Image(systemName: "location.north.fill")
                    .font(.system(size: 300, weight: .ultraLight))
                    .foregroundStyle(qiblaViewModel.isAligned ? .white : .accentColor)
                    .rotationEffect(.degrees(qiblaAngle))
                    .animation(.easeOut(duration: 0.15), value: qiblaAngle)
            }
            .overlay(alignment: .bottom) {
                if !locationManager.isAuthorized {
                    Text("Qibla direction requires location access to work accurately.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .navigationTitle("Qibla")
            .task {
                qiblaViewModel.qiblaBearing = viewModel.qiblaDirection
                qiblaViewModel.startUpdating()
            }
            .onDisappear {
                qiblaViewModel.stopUpdating()
            }
        }
    }
}

#Preview {
    QiblaView()
        .environment(PrayerTimesViewModel())
}
