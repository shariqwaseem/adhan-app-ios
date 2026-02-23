import SwiftUI

struct QiblaView: View {
    @Environment(PrayerTimesViewModel.self) private var viewModel
    @State private var qiblaViewModel = QiblaViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Qibla Direction")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ZStack {
                        // Compass ring
                        Circle()
                            .stroke(lineWidth: 2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 250, height: 250)

                        // Cardinal directions
                        ForEach(["N", "E", "S", "W"], id: \.self) { direction in
                            let angle = cardinalAngle(direction)
                            Text(direction)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .offset(y: -135)
                                .rotationEffect(.degrees(angle))
                        }

                        // Qibla arrow
                        let qiblaAngle = viewModel.qiblaDirection - qiblaViewModel.heading
                        VStack(spacing: 0) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(Color.accentColor)
                            Text(String(format: "%.1f°", viewModel.qiblaDirection))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .rotationEffect(.degrees(qiblaAngle))
                        .animation(.spring(response: 0.3), value: qiblaAngle)
                    }
                    .frame(width: 280, height: 280)

                    if qiblaViewModel.isAligned {
                        Text("Aligned with Qibla")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                    }

                    Text("Point the top of your device towards the arrow")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Qibla")
            .onAppear {
                qiblaViewModel.qiblaBearing = viewModel.qiblaDirection
                qiblaViewModel.startUpdating()
            }
            .onDisappear {
                qiblaViewModel.stopUpdating()
            }
        }
    }

    private func cardinalAngle(_ direction: String) -> Double {
        switch direction {
        case "N": return 0
        case "E": return 90
        case "S": return 180
        case "W": return 270
        default: return 0
        }
    }
}

#Preview {
    QiblaView()
        .environment(PrayerTimesViewModel())
}
