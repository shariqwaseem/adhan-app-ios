import Foundation
import BackgroundTasks

@MainActor
struct BackgroundTaskService {
    static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Constants.backgroundRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleAppRefresh(task: refreshTask)
        }
    }

    static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Constants.backgroundRefreshIdentifier)
        // Schedule for early morning (before Fajr)
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: Date())
        dateComponents.day! += 1
        dateComponents.hour = 3
        dateComponents.minute = 0
        request.earliestBeginDate = calendar.date(from: dateComponents)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background task scheduling can fail silently
        }
    }

    private static func handleAppRefresh(task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // The actual rescheduling happens when the app enters foreground
        // Background refresh just ensures we get a chance to run
        task.setTaskCompleted(success: true)
    }
}
