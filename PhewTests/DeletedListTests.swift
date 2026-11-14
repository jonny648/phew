import XCTest
@testable import Phew

/// The Recently deleted panel's list, on a stub Brain with made-up forgets.
@MainActor
final class DeletedListTests: XCTestCase {
    func testDaysLeftText() {
        XCTAssertEqual(DeletedList.daysLeftText(30), "30 days left")
        XCTAssertEqual(DeletedList.daysLeftText(1), "1 day left")
        XCTAssertEqual(DeletedList.daysLeftText(0), "Less than a day left")
        XCTAssertEqual(DeletedList.daysLeftText(-2), "Less than a day left")
    }

    func testRefreshShowsTheBrainsListAsGiven() async {
        let list = DeletedList(brain: DeletedStubBrain())
        XCTAssertFalse(list.loaded)
        await list.refresh()
        XCTAssertTrue(list.loaded)
        XCTAssertEqual(list.items.map(\.id), [1, 2])
        XCTAssertEqual(list.items.first?.label, "Made-up person: Ada Example")
        XCTAssertEqual(list.items.map(\.daysLeft), [29, 1])
    }

    func testRestoreAndDeleteNowCallTheBrainAndReloadTheList() async {
        let brain = DeletedStubBrain()
        let list = DeletedList(brain: brain)
        await list.refresh()
        await list.restore(1)
        XCTAssertEqual(list.items.map(\.id), [2])
        XCTAssertNil(list.problem)
        await list.deleteNow(2)
        XCTAssertTrue(list.items.isEmpty)
        XCTAssertEqual(brain.calls, ["restore 1", "deleteNow 2"])
        XCTAssertFalse(list.busy)
    }

    func testAFailedActionSaysSo() async {
        let list = DeletedList(brain: DeletedStubBrain())
        await list.deleteNow(99)
        XCTAssertNotNil(list.problem)
        XCTAssertEqual(list.items.count, 2)  // the list is still read again
    }

    /// The protocol's defaults, for a Brain that has no Map: an empty list, and actions that say no.
    func testBrainDefaults() async {
        let brain = FakeBrain()
        let items = await brain.recentlyDeleted()
        let restored = await brain.restore(1)
        let deleted = await brain.deleteNow(1)
        XCTAssertTrue(items.isEmpty)
        XCTAssertFalse(restored)
        XCTAssertFalse(deleted)
    }
}
