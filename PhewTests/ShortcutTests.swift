import XCTest
@testable import Phew

/// NA.13: a shortcut the user sets. Another chord or a chord with one key keeps every rule of the fixed one (exactly
/// its keys, a key held before does not block it, the hold ends on release, at 60 s and on sleep or lock); the ones
/// the Mac or common apps own are refused in one line; the choice is stored as a setting and the fixed one comes back
/// when none is stored. Made-up key flags on an injected timer: no key is pressed, no event is posted.
@MainActor
final class ShortcutTests: XCTestCase {
    private let control = NSEvent.ModifierFlags.control.rawValue, option = NSEvent.ModifierFlags.option.rawValue,
                shift = NSEvent.ModifierFlags.shift.rawValue, command = NSEvent.ModifierFlags.command.rawValue
    private var suite = ""
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suite = "phew.shortcut.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    /// A timer the test fires by hand.
    private final class Clock {
        var fire: (@MainActor () -> Void)?
        var delays: [TimeInterval] = []
        func schedule(_ delay: TimeInterval, _ fire: @escaping @MainActor () -> Void) -> () -> Void {
            delays.append(delay)
            self.fire = fire
            return { [weak self] in self?.fire = nil }
        }
    }

    private func hotKey(_ shortcut: Shortcut, _ clock: Clock, _ events: @escaping (String) -> Void) -> HotKey {
        let key = HotKey(shortcut: shortcut, schedule: clock.schedule) { events("press") }
        key.holdStart = { events("start") }
        key.holdEnd = { events("end") }
        key.holdCancel = { events("cancel") }
        key.holdLimit = { events("limit") }
        return key
    }

    /// Left Control + left Option: device bits 0x01 and 0x20, with the side-free Control and Option.
    private var leftChord: UInt { 0x21 | control | option }

    func testAnotherChordKeepsEveryRuleAndTheFixedOneNoLongerCalls() {
        let clock = Clock()
        var events: [String] = []
        let key = hotKey(Shortcut(keys: 0x21), clock) { events.append($0) }
        key.flags(0x50 | option | command)  // the fixed one
        key.flags(0)
        XCTAssertEqual(events, [])
        key.flags(leftChord)  // press: opens the ask panel
        key.flags(0)
        XCTAssertEqual(events, ["press"])
        key.flags(leftChord | 0x02 | shift)  // a third modifier: another app's shortcut
        clock.fire?()
        key.flags(0)
        XCTAssertEqual(events, ["press"])
        key.flags(0x01 | control)  // right Option instead of left
        key.flags(0x01 | 0x40 | control | option)
        key.flags(0)
        XCTAssertEqual(events, ["press"], "exactly its keys")
        key.flags(leftChord)
        key.keyDown(0, isRepeat: true)  // a key held before blocks nothing
        clock.fire?()
        XCTAssertTrue(key.holding)
        key.keyDown(8)  // a new key cancels
        key.flags(0)
        XCTAssertEqual(events, ["press", "start", "cancel"])
        key.flags(leftChord)
        clock.fire?()
        clock.fire?()  // the ceiling: the release was never seen
        XCTAssertEqual(Array(clock.delays.suffix(2)), [Design.Motion.hold, HotKey.longestHold])
        key.flags(0)
        key.flags(leftChord)
        clock.fire?()
        key.interrupt()  // sleep or lock
        key.flags(0)
        XCTAssertEqual(events, ["press", "start", "cancel", "start", "limit", "start", "cancel"])
    }

    /// ⌃⌥K: the system's hot key reports the press and the release; the modifiers alone start nothing.
    func testAChordWithOneKeyKeepsEveryRule() {
        let clock = Clock()
        var events: [String] = []
        let key = hotKey(Shortcut(keys: 0x21, key: 40, keyName: "K"), clock) { events.append($0) }
        key.flags(leftChord)
        clock.fire?()
        key.flags(0)
        XCTAssertEqual(events, [], "the modifiers alone are not the shortcut")
        key.flags(leftChord)
        key.keyPressed()
        key.keyReleased()
        key.flags(0)
        XCTAssertEqual(events, ["press"])
        key.flags(leftChord)
        key.keyPressed()
        clock.fire?()
        key.keyReleased()  // the release ends the hold
        key.keyPressed()
        clock.fire?()
        key.flags(control)  // letting go of Option ends it too
        key.keyReleased()
        key.flags(0)
        XCTAssertEqual(events, ["press", "start", "end", "start", "end"])
        key.flags(leftChord)
        key.keyPressed()
        clock.fire?()
        key.flags(leftChord | 0x02 | shift)  // a modifier joins: cancelled, nothing sent
        key.keyReleased()
        key.keyPressed()  // still down: nothing starts until the keys are up
        key.flags(0)
        key.flags(leftChord)
        key.keyPressed()
        key.keyDown(0, isRepeat: true)
        clock.fire?()
        key.keyDown(8)  // a third key
        key.keyReleased()
        XCTAssertEqual(events, ["press", "start", "end", "start", "end", "start", "cancel", "start", "cancel"])
        key.flags(0)
        key.flags(leftChord)
        key.keyPressed()
        clock.fire?()
        clock.fire?()
        XCTAssertEqual(events.last, "limit")
    }

    func testTheShortcutsTheMacAndCommonAppsOwnAreRefusedInOneLine() {
        let leftCommand: UInt = 0x08
        let refused = [Shortcut(keys: 0x10), Shortcut(keys: 0x40), Shortcut(keys: 0),  // a single modifier, or none
                       Shortcut(keys: 0, key: 40), Shortcut(keys: 0x02, key: 40)]  // a key without ⌃, ⌥ or ⌘
            + [49, 48, 12, 13, 8, 9, 7, 6, 0, 1].map { Shortcut(keys: leftCommand, key: $0) }  // ⌘Space, ⌘Tab, ⌘Q…
        for shortcut in refused {
            let line = shortcut.refusal
            XCTAssertNotNil(line, shortcut.name)
            XCTAssertFalse(line?.contains("\n") ?? true)
        }
        for shortcut in [Shortcut.default, Shortcut(keys: 0x21), Shortcut(keys: 0x0C), Shortcut(keys: 0x21, key: 49),
                         Shortcut(keys: 0x0A, key: 40)] {
            XCTAssertNil(shortcut.refusal, shortcut.name)
        }
        XCTAssertEqual(Shortcut.default.name, "right ⌥ + right ⌘")
        XCTAssertEqual(Shortcut(keys: 0x21, key: 49, keyName: Shortcut.keyName(49, characters: " ")).name, "⌃⌥Space")
        XCTAssertEqual(Shortcut.keyName(40, characters: "k"), "K")
        XCTAssertEqual(Shortcut.keyName(123, characters: "\u{F702}"), "key 123")
    }

    /// The checker's list of 17 November: an app's own shortcut, a chord that types a character, the same key on both
    /// sides, the Mac's own with more keys held. And a chord that stays allowed.
    func testOneModifierWithAKeyAndTheSameKeyTwiceAreRefused() {
        // The left keys, as the keyboard reports them.
        let (control, option, shift, command): (UInt, UInt, UInt, UInt) = (0x01, 0x20, 0x02, 0x08)
        for (keys, key) in [(command, 45), (command, 4), (control, 49), (option, 49), (option, 40), (option | shift, 40), (command | option, 53),
                            (command | shift, 12), (command | shift, 20)] as [(UInt, UInt16)] {
            XCTAssertNotNil(Shortcut(keys: keys, key: key, keyName: "x").refusal, "\(keys) \(key)")
        }
        for keys in [0x02 | 0x04, 0x08 | 0x10, 0x01 | 0x2000, 0x1_0000_0000 | 0x2_0000_0000] as [UInt] {
            XCTAssertNotNil(Shortcut(keys: keys).refusal, "\(keys)")
        }
        XCTAssertNil(Shortcut(keys: control | option, key: 40, keyName: "K").refusal)
        XCTAssertNil(Shortcut.default.refusal)
    }

    /// None stored, or one the rules refuse: the fixed one, which still calls him.
    func testTheStoredShortcutAndTheFixedOneWhenNoneIsStored() throws {
        let clock = Clock()
        var events: [String] = []
        let fixed = hotKey(.stored(defaults), clock) { events.append($0) }
        fixed.flags(0x50)
        fixed.flags(0)
        XCTAssertEqual(events, ["press"])
        let chord = Shortcut(keys: 0x21, key: 40, keyName: "K")
        chord.store(defaults)
        XCTAssertEqual(Shortcut.stored(defaults), chord)
        defaults.set(try JSONEncoder().encode(Shortcut(keys: 0x08, key: 12)), forKey: Shortcut.storeKey)  // ⌘Q
        XCTAssertEqual(Shortcut.stored(defaults), .default)
        defaults.set(Data("not a shortcut".utf8), forKey: Shortcut.storeKey)
        XCTAssertEqual(Shortcut.stored(defaults), .default)
        chord.store(defaults)
        Shortcut.default.store(defaults)
        XCTAssertNil(defaults.object(forKey: Shortcut.storeKey))
    }

    /// The panel's model: it pauses the watcher and takes the keyboard while it records, then gives both back; a
    /// chord is the keys held when all are let go; a key ends the recording; a refusal changes nothing.
    func testThePanelRecordsAChordAKeyOrRefuses() {
        var applied: [Shortcut] = [], paused: [Bool] = [], keyboard: [Bool] = []
        var accept = true
        let model = ShortcutModel(current: .default, defaults: defaults)
        model.apply = { applied.append($0); return accept }
        model.pause = { paused.append($0) }
        model.keyboard = { keyboard.append($0) }

        model.record()
        XCTAssertTrue(model.recording)
        model.flags(0x01 | control)
        model.flags(leftChord)
        model.flags(0x20 | option)
        model.flags(0)
        XCTAssertFalse(model.recording)
        XCTAssertEqual(model.current, Shortcut(keys: 0x21))
        XCTAssertEqual(Shortcut.stored(defaults), Shortcut(keys: 0x21))
        XCTAssertEqual(paused, [true, false])
        XCTAssertEqual(keyboard, [true, false])

        model.record()
        model.keyDown(40, flags: leftChord, characters: "k")
        XCTAssertEqual(model.current.name, "⌃⌥K")
        XCTAssertNil(model.problem)

        for (code, flags) in [(12, 0x08 | command), (40, 0)] as [(UInt16, UInt)] {  // ⌘Q, then K alone
            model.record()
            model.keyDown(code, flags: flags, characters: "q")
            XCTAssertNotNil(model.problem)
            XCTAssertEqual(model.current.name, "⌃⌥K", "nothing changes")
        }
        model.record()
        model.flags(0x10 | command)
        model.flags(0)
        XCTAssertNotNil(model.problem, "one modifier alone")
        model.record()
        XCTAssertNil(model.problem)
        model.keyDown(53, flags: 0, characters: nil)  // Escape: stop, nothing changes
        XCTAssertFalse(model.recording)
        XCTAssertNil(model.problem)
        XCTAssertEqual(applied.count, 2)

        accept = false  // another app holds the key
        model.record()
        model.keyDown(49, flags: leftChord, characters: " ")
        XCTAssertEqual(model.problem, "Another app already uses that one. Try another.")
        XCTAssertEqual(Shortcut.stored(defaults).name, "⌃⌥K")

        accept = true
        model.record()
        model.closed()  // the panel closed while recording: the watcher starts again
        XCTAssertFalse(model.recording)
        XCTAssertEqual(paused.last, false)
        model.useDefault()
        XCTAssertEqual(model.current, .default)
        XCTAssertNil(defaults.object(forKey: Shortcut.storeKey))
        XCTAssertEqual(paused.count, keyboard.count + 1, "closing gives the keyboard back by itself")
    }
}
