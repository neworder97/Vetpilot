import SwiftUI
import BackgroundTasks
import Combine

/// Foreground and background work share the same stores, so uploads cannot race
/// a second in-memory copy of a collection. Each store also guards overlapping requests.
@MainActor
final class VetPilotSyncController: ObservableObject {
    static let refreshIdentifier = "com.ferguson.vetpilot.collection-refresh"
    let account = VetPilotAccount()
    let clinic = ClinicStore()
    let medications = CustomMedicationStore()
    let cytology = ClinicStore(collection: "cytology")
    @Published private(set) var backgroundStatus = "Background sync runs when iOS allows."
    private var departureToken: UUID?
    private var departureTask: Task<Void, Never>?
    private var departureIdentifier: UIBackgroundTaskIdentifier = .invalid

    func syncAll() async {
        clinic.switchAccount(account.userID)
        cytology.switchAccount(account.userID)
        medications.switchAccount(account.userID)
        guard account.userID != nil, !Task.isCancelled else { return }
        await clinic.sync(account: account)
        guard !Task.isCancelled else { return }
        await cytology.sync(account: account)
        guard !Task.isCancelled else { return }
        await medications.sync(account: account)
    }

    func scheduleBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.refreshIdentifier)
        guard account.userID != nil else {
            backgroundStatus = "Sign in to enable background sync."
            return
        }
        guard UIApplication.shared.backgroundRefreshStatus == .available else {
            backgroundStatus = "Background refresh is unavailable. Enable Background App Refresh in iPhone Settings and turn off Low Power Mode."
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        // This is an earliest eligible time, not a guaranteed execution interval.
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            backgroundStatus = "Background sync requested — iOS chooses when it runs."
        } catch {
            backgroundStatus = "Background sync could not be scheduled. Foreground sync remains available."
        }
    }

    func runBackgroundRefresh() async {
        scheduleBackgroundRefresh()
        await syncAll()
    }

    /// A bounded request to finish syncing when the user leaves the app.
    /// This is not a keep-alive; expiration cancels work and releases the assertion.
    func syncWhenLeavingApp() {
        scheduleBackgroundRefresh()
        guard account.userID != nil, departureIdentifier == .invalid else { return }
        let token = UUID()
        departureToken = token
        departureIdentifier = UIApplication.shared.beginBackgroundTask(withName: "Finish VetPilot sync") { [weak self] in
            Task { @MainActor in
                guard let self, self.departureToken == token else { return }
                self.departureTask?.cancel()
                self.finishDepartureSync(token: token)
            }
        }
        guard departureIdentifier != .invalid else { departureToken = nil; return }
        departureTask = Task { [weak self] in
            guard let self else { return }
            await self.syncAll()
            self.finishDepartureSync(token: token)
        }
    }

    private func finishDepartureSync(token: UUID) {
        guard departureToken == token else { return }
        departureToken = nil
        if departureIdentifier != .invalid {
            UIApplication.shared.endBackgroundTask(departureIdentifier)
            departureIdentifier = .invalid
        }
        departureTask = nil
    }
}
