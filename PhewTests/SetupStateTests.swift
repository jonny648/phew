import XCTest
@testable import Phew

/// First run (PX.5, docs/15-design.md 15.5 G): which row shows which control in which state, and that the panel
/// shows at launch only when something is missing. Made-up values only: no Keychain, no permission is looked at.
final class SetupStateTests: XCTestCase {
    private let allDone = SetupState(hasKey: true, accessibility: true, screen: true, screenAtLaunch: true)

    func testFreshInstallAsksForAllThree() {
        let fresh = SetupState(hasKey: false, accessibility: false, screen: false, screenAtLaunch: false)
        XCTAssertEqual(fresh.key, .keyField)
        XCTAssertEqual(fresh.accessibilityRow, .allow)
        XCTAssertEqual(fresh.screenRow, .allow)
        XCTAssertTrue(fresh.missing)
    }

    func testNothingMissingShowsNothing() {
        XCTAssertEqual([allDone.key, allDone.accessibilityRow, allDone.screenRow], [.done, .done, .done])
        XCTAssertFalse(allDone.missing)
    }

    func testEachMissingThingAloneShowsThePanel() {
        var noKey = allDone
        noKey.hasKey = false
        var noAccessibility = allDone
        noAccessibility.accessibility = false
        var noScreen = allDone
        noScreen.screen = false
        noScreen.screenAtLaunch = false
        for state in [noKey, noAccessibility, noScreen] { XCTAssertTrue(state.missing) }
    }

    /// macOS asks only once: after Allow was pressed, in any run, the button opens System Settings.
    func testAskedBeforeOpensSystemSettings() {
        var state = SetupState(hasKey: true, accessibility: false, screen: false, screenAtLaunch: false,
                               askedAccessibility: true, askedScreen: true)
        XCTAssertEqual(state.accessibilityRow, .openSettings)
        XCTAssertEqual(state.screenRow, .openSettings)
        state.askedAccessibility = false
        XCTAssertEqual(state.accessibilityRow, .allow)
        state.accessibility = true
        XCTAssertEqual(state.accessibilityRow, .done, "granted wins over asked")
    }

    /// Granted since launch: not active until Phew reopens, so the row offers the reopen and still counts as missing.
    func testScreenRecordingGrantedButNotActiveOffersReopen() {
        let state = SetupState(hasKey: true, accessibility: true, screen: true, screenAtLaunch: false)
        XCTAssertEqual(state.screenRow, .reopen)
        XCTAssertTrue(state.missing)
    }

    /// Sent to System Settings in this run: the system may still say "not granted" until Phew reopens.
    func testSentToSettingsOffersReopen() {
        let state = SetupState(hasKey: true, accessibility: true, screen: false, screenAtLaunch: false,
                               askedScreen: true, screenSentToSettings: true)
        XCTAssertEqual(state.screenRow, .reopen)
    }

    @MainActor
    func testReadyOnlyWhenNothingIsMissingAndNotForTheKeyAlone() {
        XCTAssertTrue(SetupModel(state: allDone, keyOnly: false, live: false).ready)
        let keyOnly = SetupModel(state: allDone, keyOnly: true, live: false)
        XCTAssertFalse(keyOnly.ready, "API Key… shows the key row, not the ready state")
        XCTAssertTrue(keyOnly.showsKeyField, "the menu's key row always has the field, to replace a key")
        var missing = allDone
        missing.hasKey = false
        let model = SetupModel(state: missing, keyOnly: false, live: false)
        XCTAssertFalse(model.ready)
        XCTAssertTrue(model.showsKeyField)
        XCTAssertFalse(SetupModel(state: allDone, keyOnly: false, live: false).showsKeyField)
        XCTAssertNotNil(SetupModel(state: allDone, keyOnly: true, rejected: true, live: false).keyProblem)
    }

    /// A made-up model never asks, opens or writes anything: its buttons do nothing.
    @MainActor
    func testMadeUpModelTouchesNothing() {
        let model = SetupModel(state: SetupState(hasKey: true, accessibility: false, screen: false, screenAtLaunch: false),
                               keyOnly: false, live: false)
        model.accessibilityPressed()
        model.screenPressed()
        model.recheck()
        XCTAssertFalse(model.state.askedAccessibility)
        XCTAssertFalse(model.state.askedScreen)
        XCTAssertFalse(model.state.accessibility)
    }
}
