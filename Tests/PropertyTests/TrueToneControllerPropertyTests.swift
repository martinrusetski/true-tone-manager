import XCTest
import SwiftCheck
@testable import TrueToneManager

final class MockTrueToneSystemClient: TrueToneSystemClient {
    var currentState: Bool = false
    var setStateCalls: [Bool] = []
    var getStatusCalls = 0
    var supported: Bool = true
    var available: Bool = true

    func isSupported() -> Bool {
        return supported
    }

    func isAvailable() -> Bool {
        return available
    }

    func getEnabled() -> Bool {
        getStatusCalls += 1
        return currentState
    }

    func setEnabled(_ enabled: Bool) {
        setStateCalls.append(enabled)
        currentState = enabled
    }
}

final class TrueToneControllerPropertyTests: XCTestCase {

    func testProperty3_StateTransitions() {
        property("Requesting state change when current state differs succeeds") <- forAll { (initial: Bool, target: Bool) in
            guard initial != target else { return true }

            let client = MockTrueToneSystemClient()
            client.currentState = initial
            let controller = TrueToneController(systemClient: client)

            do {
                try controller.setTrueTone(enabled: target)
                let actualState = try controller.getCurrentState()
                return actualState == target && client.setStateCalls.contains(target)
            } catch {
                return false
            }
        }
    }

    func testProperty4_Idempotence() {
        property("Requesting same state when already in that state returns success without modification") <- forAll { (state: Bool) in
            let client = MockTrueToneSystemClient()
            client.currentState = state
            let controller = TrueToneController(systemClient: client)

            let callsBefore = client.setStateCalls.count

            do {
                try controller.setTrueTone(enabled: state)
                let actualState = try controller.getCurrentState()
                return actualState == state && client.setStateCalls.count == callsBefore
            } catch {
                return false
            }
        }
    }

    func testUnsupportedHardware() {
        let client = MockTrueToneSystemClient()
        client.supported = false
        let controller = TrueToneController(systemClient: client)

        XCTAssertFalse(controller.isSupported())
        XCTAssertThrowsError(try controller.getCurrentState()) { error in
            XCTAssertEqual(error as? TrueToneControllerError, .unsupportedHardware)
        }
    }

    func testUnavailableDisplayThrowsOnSet() {
        let client = MockTrueToneSystemClient()
        client.supported = true
        client.available = false
        let controller = TrueToneController(systemClient: client)

        XCTAssertFalse(controller.isAvailable())
        XCTAssertThrowsError(try controller.setTrueTone(enabled: true)) { error in
            XCTAssertEqual(error as? TrueToneControllerError, .unavailable)
        }
        // Reading the global setting is still allowed (it reflects the system
        // checkbox, not whether a capable display is currently attached).
        XCTAssertNoThrow(try controller.getCurrentState())
    }
}
