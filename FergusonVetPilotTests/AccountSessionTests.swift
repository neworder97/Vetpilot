import XCTest
@testable import FergusonVetPilot
final class AccountSessionTests: XCTestCase {
    func testRefreshOriginRejectsLogoutAccountSwitchAndNewLogin() {
        let origin = VetPilotSession(access_token: "old-access", refresh_token: "old-refresh", expires_in: 1, user: .init(id: UUID(), email: nil))
        XCTAssertTrue(origin.matchesRefreshOrigin(origin))
        XCTAssertFalse(origin.matchesRefreshOrigin(nil))
        var switched = origin; switched.user.id = UUID()
        XCTAssertFalse(origin.matchesRefreshOrigin(switched))
        var signedInAgain = origin; signedInAgain.refresh_token = "new-login-refresh"
        XCTAssertFalse(origin.matchesRefreshOrigin(signedInAgain))
    }
}
