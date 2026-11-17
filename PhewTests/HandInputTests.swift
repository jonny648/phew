import AppKit
import Carbon.HIToolbox
import XCTest
@testable import Phew

/// NA.4, NA.5 and NA.6 on the fake surface (`FakeSurface`, HandTests.swift): the new kinds of action through the one
/// acting function and its gates, the never-send shortcuts, keys only to the job's app, the "cannot be undone" class
/// for shortcuts, a dialog's default button and a control with no name, script titles, and an agent's task as one job.
/// Nothing is posted: the events are made and looked at, never sent.
@MainActor
final class HandInputTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private var neverRead: NeverReadList!
    private var fake: FakeSurface!
    private var savedLog: URL!
    private var log: URL!

    override func setUp() {
        suite = "PhewTests.handInput.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.set(true, forKey: Hand.allowedKey)
        neverRead = NeverReadList(defaults: defaults)
        fake = FakeSurface()
        savedLog = ActionLog.url
        log = FileManager.default.temporaryDirectory.appending(path: "phew-actions-\(UUID().uuidString).log")
        ActionLog.url = log  // never the user's real actions.log
    }

    override func tearDown() {
        ActionLog.flush()
        try? FileManager.default.removeItem(at: log)
        ActionLog.url = savedLog
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    private func hand(ownPID: pid_t = getpid(), now: @escaping () -> Date = Date.init) -> Hand {
        Hand(defaults: defaults, surface: fake, list: neverRead, ownPID: ownPID, now: now)
    }

    private func frame(_ i: Int) -> CGRect { CGRect(x: 20, y: 20 + i * 40, width: 100, height: 30) }

    /// A job in the practice app, as the card starts one.
    private func job(_ hand: Hand, agent: Bool = false) -> HandJob { hand.begin(watchUser: false, in: FakeSurface.pid, agent: agent) }

    private func keys(_ chord: String) throws -> HandStep {
        HandStep(kind: .keys, pid: FakeSurface.pid, chord: try XCTUnwrap(HandChord.parse(chord), chord))
    }

    private func typed(_ text: String) -> HandStep { HandStep(kind: .keys, pid: FakeSurface.pid, text: text) }

    /// The four pointed kinds on a control the look saw.
    private func pointed(_ kind: HandStep.Kind, on step: HandStep) -> HandStep {
        var step = step
        step.kind = kind
        if kind == .scroll { step.amount = 3 }
        if kind == .drag { step.to = CGPoint(x: 300, y: 300) }
        return step
    }

    // MARK: - NA.5: the new kinds pass the same gates as a press

    func testDoubleRightScrollAndDragActAndPassTheGates() {
        let bold = fake.add("Bold", frame: frame(0))
        let kinds: [HandStep.Kind] = [.doubleClick, .rightClick, .scroll, .drag]
        for kind in kinds {
            let hand = self.hand()
            XCTAssertEqual(hand.act(pointed(kind, on: bold), in: job(hand)).end, .done, "\(kind)")
        }
        XCTAssertEqual(fake.sent.map(\.kind), kinds)
        // Refused, nothing sent: off, a never app, a Never read app, Phew's own, secure input, a paying control, a
        // secure field, another app in front, Stop.
        let pay = fake.add("Pay now", frame: frame(1))
        let secret = fake.add("Secret", role: "AXTextField", subrole: "AXSecureTextField", frame: frame(2))
        neverRead.add(name: "Private Diary", bundleID: "com.example.private-diary")
        for kind in kinds {
            func end(_ step: HandStep, ownPID: pid_t = getpid(), stop: Bool = false) -> HandEnd {
                let hand = self.hand(ownPID: ownPID), job = job(hand)
                if stop { job.stop() }
                return hand.act(pointed(kind, on: step), in: job).end
            }
            defaults.set(false, forKey: Hand.allowedKey)
            XCTAssertEqual(end(bold), .off, "\(kind)")
            defaults.set(true, forKey: Hand.allowedKey)
            for (bundle, refused) in [("com.apple.Terminal", HandEnd.neverActApp), ("com.example.private-diary", .neverReadApp)] {
                fake.bundles[FakeSurface.pid] = bundle
                XCTAssertEqual(end(bold), refused, "\(kind) \(bundle)")
            }
            fake.bundles[FakeSurface.pid] = "com.example.practice"
            XCTAssertEqual(end(bold, ownPID: FakeSurface.pid), .ownApp, "\(kind)")
            fake.secureInputOn = true
            XCTAssertEqual(end(bold), .secureInput, "\(kind)")
            fake.secureInputOn = false
            XCTAssertEqual(end(pay), .paying, "\(kind)")
            XCTAssertEqual(end(secret), .secureField, "\(kind)")
            fake.front = 99
            XCTAssertEqual(end(bold), .frontChanged, "\(kind)")
            fake.front = FakeSurface.pid
            XCTAssertEqual(end(bold, stop: true), .stopped, "\(kind)")
        }
        XCTAssertEqual(fake.sentCount, kinds.count)
    }

    func testTheNewKindsCountTowardsTheCeilings() throws {
        var time = Date(timeIntervalSince1970: 1_000_000)
        let bold = fake.add("Bold", frame: frame(0))
        let hand = self.hand(now: { time })
        let job = job(hand)
        let steps = [pointed(.doubleClick, on: bold), pointed(.scroll, on: bold), try keys("cmd+b"), typed("made up")]
        for i in 0..<Hand.perJob {
            XCTAssertEqual(hand.act(steps[i % steps.count], in: job).end, .done, "action \(i + 1)")
            time += 5
        }
        XCTAssertEqual(hand.act(steps[0], in: job).end, .jobCeiling)
    }

    func testScrollAndDragLimits() {
        let bold = fake.add("Bold", frame: frame(0))
        func end(_ step: HandStep) -> HandEnd { let hand = self.hand(); return hand.act(step, in: job(hand)).end }
        var scroll = pointed(.scroll, on: bold)
        for amount in [0, Hand.mostScroll + 1, -Hand.mostScroll - 1] {
            scroll.amount = amount
            XCTAssertEqual(end(scroll), .failed, "\(amount)")
        }
        scroll.amount = -Hand.mostScroll
        XCTAssertEqual(end(scroll), .done)
        // A drag that ends outside the job's app, or with no end, is not made.
        var drag = pointed(.drag, on: bold)
        fake.clickOwner = 99
        XCTAssertEqual(end(drag), .failed)
        fake.clickOwner = FakeSurface.pid
        drag.to = nil
        XCTAssertEqual(end(drag), .failed)
        // What it ends on is judged as the control it starts on.
        fake.add("Buy now", frame: frame(3))
        fake.add("Secret", role: "AXTextField", subrole: "AXSecureTextField", frame: frame(4))
        drag.to = CGPoint(x: frame(3).midX, y: frame(3).midY)
        XCTAssertEqual(end(drag), .paying)
        drag.to = CGPoint(x: frame(4).midX, y: frame(4).midY)
        XCTAssertEqual(end(drag), .secureField)
        // A bare canvas point: no control under it, still made.
        let canvas = HandStep(kind: .drag, pid: FakeSurface.pid, frame: CGRect(x: 500, y: 500, width: 0, height: 0), to: CGPoint(x: 600, y: 600))
        XCTAssertEqual(end(canvas), .done)
        XCTAssertEqual(fake.sent.map(\.kind), [.scroll, .drag])
    }

    // MARK: - NA.5: keys

    func testKeysGoOnlyToTheJobsAppWhileItIsInFront() throws {
        let bold = try keys("cmd+b")
        var hand = self.hand()
        XCTAssertEqual(hand.act(bold, in: job(hand)).end, .done)
        XCTAssertEqual(fake.sent.last?.chord, HandChord.parse("cmd+B"))
        XCTAssertEqual(fake.sent.last?.pid, FakeSurface.pid, "to the job's app, by its pid")
        // A job in another app: the keys are not its app's.
        hand = self.hand()
        XCTAssertEqual(hand.act(bold, in: hand.begin(watchUser: false, in: 7)).end, .frontChanged)
        hand = self.hand()
        XCTAssertEqual(hand.act(bold, in: hand.begin(watchUser: false)).end, .frontChanged, "a job with no app takes no key")
        // Another app came to the front.
        fake.front = 99
        hand = self.hand()
        XCTAssertEqual(hand.act(bold, in: job(hand)).end, .frontChanged)
        fake.front = FakeSurface.pid
        // A surprise sheet.
        hand = self.hand()
        let sheet = job(hand)
        XCTAssertEqual(hand.act(bold, in: sheet).end, .done)
        fake.dialogCount = 1
        XCTAssertEqual(hand.act(bold, in: sheet).end, .surprise)
        fake.dialogCount = 0
        XCTAssertEqual(fake.sentCount, 2)
    }

    func testNoKeyWhileAPasswordPromptIsOpen() throws {
        func end(_ step: HandStep, ownPID: pid_t = getpid()) -> HandEnd { let hand = self.hand(ownPID: ownPID); return hand.act(step, in: job(hand)).end }
        for step in [try keys("return"), try keys("cmd+v"), typed("made-up text")] {
            fake.secureInputOn = true
            XCTAssertEqual(end(step), .secureInput)
            fake.secureInputOn = false
            fake.focusedSecure = true
            XCTAssertEqual(end(step), .secureField)
            fake.focusedSecure = false
            fake.focusElement = FakeSurface.Element(HandSeen(role: "AXTextField", subrole: "AXSecureTextField", name: "Made up"), window: "")
            XCTAssertEqual(end(step), .secureField, "the focused element is a secure field")
            // The never words on the focused control, as on a pressed one.
            fake.focusElement = FakeSurface.Element(HandSeen(role: "AXTextField", name: "Card number"), window: "")
            XCTAssertEqual(end(step), .paying)
            fake.focusElement = nil
            fake.bundles[FakeSurface.pid] = "com.apple.Terminal"
            XCTAssertEqual(end(step), .neverActApp)
            fake.bundles[FakeSurface.pid] = "com.example.practice"
            XCTAssertEqual(end(step, ownPID: FakeSurface.pid), .ownApp)
            defaults.set(false, forKey: Hand.allowedKey)
            XCTAssertEqual(end(step), .off)
            defaults.set(true, forKey: Hand.allowedKey)
        }
        XCTAssertEqual(fake.sentCount, 0)
    }

    func testTheNeverSendShortcutsAreNeverSent() throws {
        let list = ["cmd+q", "cmd+option+q", "cmd+shift+q", "cmd+option+shift+q", "control+cmd+q", "cmd+option+escape",
                    "cmd+option+shift+escape", "cmd+shift+delete", "cmd+option+shift+delete", "cmd+space", "cmd+option+space",
                    "control+space", "control+option+space", "cmd+tab", "cmd+shift+tab", "cmd+h", "cmd+option+h", "cmd+option+d",
                    "control+up", "control+down", "control+left", "control+right", "cmd+shift+3", "cmd+shift+4", "cmd+shift+5",
                    "control+cmd+shift+3", "control+cmd+shift+4"]
        XCTAssertEqual(NeverList.neverSend.count, list.count, "every entry is a real chord")
        for chord in list {
            let hand = self.hand()
            // Any order and case of the modifiers is the same chord.
            let shuffled = chord.split(separator: "+").dropLast().reversed().joined(separator: "+") + "+" + chord.split(separator: "+").last!.uppercased()
            XCTAssertEqual(hand.act(try keys(chord.contains("+") ? shuffled : chord), in: job(hand)).end, .neverKeys, chord)
        }
        XCTAssertEqual(fake.sentCount, 0)
        XCTAssertEqual(ActJob.sentence(for: .neverKeys), "I never press that shortcut: it quits, logs out, locks, empties the Trash or leaves the app.")
    }

    /// The vocabulary is fixed: fn and the globe key cannot be named, nor anything outside the list.
    func testAChordIsParsedFromAFixedVocabularyOnly() {
        XCTAssertEqual(HandChord.parse(" Command + B "), HandChord.parse("cmd+b"))
        XCTAssertEqual(HandChord.parse("ctrl+opt+F12"), HandChord.parse("control+option+f12"))
        XCTAssertEqual(HandChord.parse("alt+left")?.modifiers, [.option])
        for good in ["a", "z", "0", "9", "return", "tab", "space", "escape", "delete", "forwarddelete", "up", "down", "left",
                     "right", "f1", "f12", "cmd+shift+option+control+k"] {
            XCTAssertNotNil(HandChord.parse(good), good)
        }
        for bad in ["", "+", "cmd+", "fn+f", "globe+a", "cmd+fn+q", "hyper+a", "cmd+b+c", "cmd+cmd+b", "f13", "f0", "enter",
                    "home", "cmd+;", "⌘b", "cmd b", "power", "eject", "capslock", "cmd+shift"] {
            XCTAssertNil(HandChord.parse(bad), bad)
        }
        XCTAssertEqual(HandChord.parse("cmd+shift+z")?.symbols, "⇧⌘Z")
        XCTAssertEqual(HandChord.parse("return")?.symbols, "↩")
        XCTAssertEqual(HandChord.parse("control+option+tab")?.flags, [.maskControl, .maskAlternate])
    }

    func testDeleteAndSendShortcutsAreTagged() throws {
        func result(_ step: HandStep, agent: Bool = false) -> HandResult { let hand = self.hand(); return hand.act(step, in: job(hand, agent: agent)) }
        for chord in ["cmd+delete", "cmd+option+delete", "cmd+forwarddelete", "cmd+return", "cmd+shift+return", "cmd+shift+d"] {
            XCTAssertEqual(result(try keys(chord)), HandResult(end: .done, final: true), chord)
            XCTAssertEqual(result(try keys(chord), agent: true).end, .needsConfirm, chord)
        }
        for chord in ["cmd+s", "cmd+z", "delete", "forwarddelete", "cmd+b", "return", "space", "shift+return", "tab"] {
            XCTAssertEqual(result(try keys(chord)), HandResult(end: .done), chord)
        }
        // Return while a sheet is open presses its default button; Return or Space on a focused Send button sends.
        fake.dialogCount = 1
        XCTAssertTrue(result(try keys("return")).final)
        XCTAssertFalse(result(try keys("cmd+b")).final)
        fake.dialogCount = 0
        fake.focusElement = FakeSurface.Element(HandSeen(role: "AXButton", name: "Send"), window: "")
        XCTAssertTrue(result(try keys("space")).final)
        XCTAssertTrue(result(try keys("return")).final)
        XCTAssertFalse(result(try keys("tab")).final)
        fake.focusElement = nil
        // Typed text with a new line: Return in a web form.
        XCTAssertTrue(result(typed("Made up\nline")).final)
        XCTAssertFalse(result(typed("Made up line")).final)
    }

    func testTypedTextIsCappedAndLoggedAsACountOnly() throws {
        func end(_ step: HandStep) -> HandEnd { let hand = self.hand(); return hand.act(step, in: job(hand)).end }
        let planted = "Planted typed words 4242 "
        let most = String(repeating: planted, count: Hand.mostTyped / planted.count) + String(repeating: "x", count: Hand.mostTyped % planted.count)
        XCTAssertEqual(most.count, Hand.mostTyped)
        XCTAssertEqual(end(typed(most)), .done)
        XCTAssertEqual(end(typed(most + "x")), .failed)
        XCTAssertEqual(end(typed("")), .failed)
        XCTAssertEqual(end(try keys("cmd+b")), .done)
        XCTAssertEqual(fake.sentCount, 2)
        ActionLog.flush()
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertFalse(text.contains("Planted") || text.contains("4242") || text.contains("cmd") || text.contains("\"b\""), text)
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 4)
        XCTAssertTrue(lines[0].contains(#""kind":"keys""#) && lines[0].contains(#""chars":\#(Hand.mostTyped)"#), String(lines[0]))
        XCTAssertTrue(lines[3].contains(#""chars":0"#), "a shortcut is no characters")
    }

    /// The events are made, never posted: a key with its modifiers, typed text one character each, a double click and
    /// a drag in one window; each marked as Phew's own, so the user's watch never takes it for theirs.
    func testTheEventsAreMadeRightAndMarked() throws {
        let key = try XCTUnwrap(AXSurface.keyEvents(try XCTUnwrap(HandChord.parse("cmd+shift+b"))))
        XCTAssertEqual(key.map(\.type), [.keyDown, .keyUp])
        XCTAssertEqual(key.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [Int64(kVK_ANSI_B), Int64(kVK_ANSI_B)])
        XCTAssertTrue(key.allSatisfy { $0.flags.contains([.maskCommand, .maskShift]) && !$0.flags.contains(.maskAlternate) })
        XCTAssertTrue(key.allSatisfy(Hand.isOwn))
        let typed = try XCTUnwrap(AXSurface.typeEvents("Hé!"))
        XCTAssertEqual(typed.count, 6)
        XCTAssertTrue(typed.allSatisfy(Hand.isOwn))
        XCTAssertNil(AXSurface.typeEvents(""))
        XCTAssertNil(AXSurface.typeEvents(String(repeating: "x", count: Hand.mostTyped + 1)))
        let double = try XCTUnwrap(AXSurface.mouseEvents([(.leftMouseDown, .zero, 1), (.leftMouseUp, .zero, 1),
                                                          (.leftMouseDown, .zero, 2), (.leftMouseUp, .zero, 2)], window: 1))
        XCTAssertEqual(double.map { $0.getIntegerValueField(.mouseEventClickState) }, [1, 1, 2, 2])
        let right = try XCTUnwrap(AXSurface.mouseEvents([(.rightMouseDown, .zero, 1), (.rightMouseUp, .zero, 1)], window: 1))
        XCTAssertEqual(right.map(\.type), [.rightMouseDown, .rightMouseUp])
        XCTAssertTrue((double + right).allSatisfy(Hand.isOwn))
    }

    // MARK: - F4: a dialog's default button and a control with no name

    func testADialogsDefaultButtonAndAnUnnamedControlCannotBeUndone() {
        let ok = fake.add("OK", frame: frame(0))
        let cancel = fake.add("Cancel", frame: frame(1))
        let unnamed = fake.add("", frame: frame(2))
        fake.defaultButton = "OK"
        func result(_ step: HandStep, agent: Bool = false) -> HandResult { let hand = self.hand(); return hand.act(step, in: job(hand, agent: agent)) }
        XCTAssertTrue(result(ok).final, "the default button")
        XCTAssertFalse(result(cancel).final)
        XCTAssertTrue(result(pointed(.doubleClick, on: ok)).final)
        XCTAssertTrue(result(unnamed).final, "no name: no word can judge it")
        XCTAssertTrue(result(pointed(.doubleClick, on: unnamed)).final)
        XCTAssertFalse(result(pointed(.rightClick, on: unnamed)).final, "a right click only opens a menu")
        XCTAssertFalse(result(pointed(.scroll, on: unnamed)).final)
        // A click at a bare canvas point is on no control.
        XCTAssertFalse(result(HandStep(kind: .click, pid: FakeSurface.pid, frame: CGRect(x: 500, y: 500, width: 0, height: 0))).final)
        // An agent's waits for the confirm, and nothing is sent.
        let sent = fake.sentCount
        XCTAssertEqual(result(ok, agent: true).end, .needsConfirm)
        XCTAssertEqual(result(unnamed, agent: true).end, .needsConfirm)
        XCTAssertEqual(fake.sentCount, sent)
    }

    // MARK: - F3: script titles, and an agent's task as one job

    func testScriptTitlesAreCheckedForPasswordWords() {
        func end(_ script: HandScript) -> HandEnd { let hand = self.hand(); return hand.act(HandStep(kind: .script, pid: 0, script: script), in: hand.begin(watchUser: false)).end }
        let refused: [(HandScript, HandEnd)] = [
            (.note(title: "Password list", body: "made up"), .password),
            (.noteBody(title: "Codice di sicurezza", body: "made up"), .password),
        ]
        for (script, reason) in refused { XCTAssertEqual(end(script), reason, "\(script)") }
        XCTAssertTrue(fake.scripts.isEmpty && fake.changed.isEmpty, "nothing ran")
        // Paying and sign-in words are not judged in a title: a reminder to pay or to log in is a reminder.
        XCTAssertEqual(end(.reminder(title: "Pay the made-up rent", due: nil)), .done)
        for title in ["Buy milk", "Paga la bolletta", "Checkout review", "Order"] { XCTAssertNil(NeverList.refusal(titles: [title]), title) }
        // Body text is not judged.
        XCTAssertEqual(end(.reminder(title: "Log in to the made-up portal", due: nil)), .done)
        XCTAssertEqual(end(.note(title: "Made-up plan", body: "pay the password")), .done)
    }

    /// A task's add_items are one job for the per-job ceiling: 40 in all, never 40 per item.
    func testAnAgentsTaskIsOneJobForTheCeiling() async throws {
        var time = Date(timeIntervalSince1970: 1_000_000)
        let hand = self.hand(now: { time })
        let list = TaskList(brain: ClaudeBrain(provider: TaskTests.Hanging(), tools: RunnerTests.FakeMap(out: "")), hand: hand,
                            folder: { nil })
        _ = list.start("Research a made-up topic", packet: nil)
        let task = try XCTUnwrap(list.items.first?.id)
        for i in 0..<Hand.perJob {
            let end = await list.add(.reminder(title: "Made-up reminder \(i)", due: nil), task: task)
            XCTAssertEqual(end, "done", "item \(i + 1)")
            time += 5  // spaced, so the minute ceiling never bites
        }
        let end = await list.add(.reminder(title: "One made-up reminder too many", due: nil), task: task)
        XCTAssertEqual(end, HandEnd.jobCeiling.rawValue)
        XCTAssertEqual(fake.scripts.count, Hand.perJob)
        list.stopAll()
    }

    // MARK: - NA.6: any app not on a Never list

    /// The system's own lookup, reading only: Finder always runs; a made-up name is on no Mac.
    func testAppsAreFoundByNameOnThisMac() {
        XCTAssertEqual(Hand.apps(named: " finder ").map(\.bundleID), ["com.apple.finder"])
        XCTAssertEqual(Hand.apps(named: "No Such Made-up App 4242").count, 0)
        XCTAssertEqual(Hand.apps(named: "").count, 0)
    }
}
