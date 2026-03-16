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
                (qiblaViewModel.isAligned ? Color.green : Color(.systemGroupedBackground))
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.3), value: qiblaViewModel.isAligned)

                Image(systemName: "location.north.fill")
                    .font(.system(size: 300, weight: .ultraLight))
                    .foregroundStyle(qiblaViewModel.isAligned ? .white : .accentColor)
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
