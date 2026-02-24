import SwiftUI

struct QiblaView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @State private var qiblaViewModel = QiblaViewModel()

    private var qiblaAngle: Double {
        viewModel.qiblaDirection - qiblaViewModel.heading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                Image(systemName: "location.north.fill")
                    .font(.system(size: 200, weight: .ultraLight))
                    .foregroundStyle(qiblaViewModel.isAligned ? .green : .accentColor)
                    .rotationEffect(.degrees(qiblaAngle))
                    .animation(.easeOut(duration: 0.15), value: qiblaAngle)
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
