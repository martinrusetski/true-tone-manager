import XCTest
@testable import TrueToneManager

final class UpdaterManagerTests: XCTestCase {
    func testInteractiveFirstLaunchRequestsPermission() {
        XCTAssertEqual(
            UpdaterManager.startupAction(
                hasPrompted: false,
                allowsPermissionPrompt: true
            ),
            .requestPermission
        )
    }

    func testLoginItemFirstLaunchRemainsSilent() {
        XCTAssertEqual(
            UpdaterManager.startupAction(
                hasPrompted: false,
                allowsPermissionPrompt: false
            ),
            .remainSilent
        )
    }

    func testReturningLaunchChecksInBackgroundAfterPermissionChoice() {
        XCTAssertEqual(
            UpdaterManager.startupAction(
                hasPrompted: true,
                allowsPermissionPrompt: false
            ),
            .checkInBackground
        )
    }
}
