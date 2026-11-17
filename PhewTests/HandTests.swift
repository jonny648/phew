import AppKit
import Carbon.HIToolbox
import WebKit
import XCTest
@testable import Phew

/// A fake surface: made-up elements found by frame, no Accessibility call, nothing sent anywhere.
final class FakeSurface: HandSurface, @unchecked Sendable {  // state under `lock`
    final class Element {
        var seen: HandSeen
        var window: String
        init(_ seen: HandSeen, window: String) { self.seen = seen; self.window = window }
    }

    static let pid: pid_t = 42
    let lock = NSLock()
    var front: pid_t? = pid
    var bundles: [pid_t: String] = [pid: "com.example.practice"]
    var secureInputOn = false
    var focusedSecure = false
    var elements: [Element] = []
    var menus: [[String]: Element] = [:]
    var dialogCount = 0
    /// How long each action takes: the slow control.
    var delay: TimeInterval = 0
    private(set) var sent: [HandStep] = []

    @discardableResult
    func add(_ name: String, role: String = "AXButton", subrole: String = "", frame: CGRect, window: String = "Practice") -> HandStep {
        elements.append(Element(HandSeen(role: role, subrole: subrole, name: name, frame: frame), window: window))
        return HandStep(kind: role == "AXTextField" ? .set : .press, pid: Self.pid, role: role, name: name, frame: frame)
    }

    var sentCount: Int { lock.withLock { sent.count } }
    /// Every read of an app's screen (element, menu, focus, window, dialogs): none may come before the Never list.
    private(set) var reads = 0

    func frontPID() -> pid_t? { front }
    func bundleID(_ pid: pid_t) -> String? { bundles[pid] }
    func secureInput() -> Bool { secureInputOn }
    func focusedIsSecure(_ pid: pid_t) -> Bool { reads += 1; return focusedSecure }
    func element(at point: CGPoint, pid: pid_t) -> AnyObject? { reads += 1; return elements.first { $0.seen.frame?.contains(point) == true } }
    func menuItem(_ path: [String], pid: pid_t) -> AnyObject? { reads += 1; return menus[path] }
    func read(_ element: AnyObject) -> HandSeen? { (element as! Element).seen }
    func dialogs(_ pid: pid_t) -> Int { reads += 1; return dialogCount }
    /// NA.5: the element with the keyboard focus. F4: the name of the default button of the sheet or dialog shown.
    var focusElement: Element?
    var defaultButton: String?
    func focused(_ pid: pid_t) -> AnyObject? { reads += 1; return focusElement }
    func isDefault(_ element: AnyObject) -> Bool { (element as! Element).seen.name == defaultButton }

    /// PH.7: apps not running yet, by bundle id, and the pid each comes up with when brought to the front.
    var launchable: [String: pid_t] = [:]
    /// How the app answered being brought to the front.
    var activateEnd = HandEnd.done
    /// Every app brought to the front, by bundle id, in order.
    private(set) var activated: [String] = []
    /// The app a click lands in (`owner(at:)`): the practice app unless a test says otherwise; nil is "not known".
    var clickOwner: pid_t? = pid

    func owner(at point: CGPoint) -> pid_t? { clickOwner }
    func running(_ bundleID: String) -> pid_t? { bundles.first { $0.value == bundleID }?.key }
    func activate(_ bundleID: String, stop: @escaping () -> Bool) -> (HandEnd, pid_t?) {
        lock.withLock { activated.append(bundleID) }
        guard activateEnd == .done else { return (activateEnd, nil) }
        guard let pid = running(bundleID) ?? launchable[bundleID] else { return (.failed, nil) }
        bundles[pid] = bundleID
        front = pid
        return (.done, pid)
    }

    func send(_ step: HandStep, to element: AnyObject?) -> HandEnd {
        if delay > 0 { Thread.sleep(forTimeInterval: delay) }
        lock.withLock { sent.append(step) }
        if step.kind == .set, let element = element as? Element { element.seen.value = wrongSet ? "other made-up text" : step.text }
        return .done
    }
    /// A field that takes the set and keeps another value (a formatter): the read-back must notice (R38).
    var wrongSet = false

    /// The fake scripting surface: records each script; makes ids "made-1", "made-2"…; `append` and `cells` need what
    /// this job made, as the real one. `scriptEnd` stands in for how the app answered.
    var scriptEnd = HandEnd.done
    /// Runs while the script runs: what the user does meanwhile.
    var during: (() -> Void)?
    private(set) var scripts: [HandScript] = []
    func run(_ script: HandScript, made: [HandMade], stop: @escaping () -> Bool) -> (HandEnd, HandMade?) {
        if delay > 0 { Thread.sleep(forTimeInterval: delay) }
        during?()
        lock.withLock { scripts.append(script) }
        guard scriptEnd == .done else { return (scriptEnd, nil) }
        switch script {
        case .append: return (made.contains { $0.kind == "note" } ? .done : .gone, nil)
        case .cells: return (made.contains { $0.kind == "workbook" } ? .done : .gone, nil)
        case .note(let title, _): return (.done, HandMade(kind: "note", id: "made-\(scripts.count)", title: title))
        case .reminder(let title, _): return (.done, HandMade(kind: "reminder", id: "made-\(scripts.count)", title: title))
        case .event(let title, _, _): return (.done, HandMade(kind: "event", id: "made-\(scripts.count)", title: title))
        case .workbook: return (.done, HandMade(kind: "workbook", id: "made-\(scripts.count)"))
        default: return (.failed, nil)  // changes go through `change`
        }
    }

    /// N2.8: each app's focused window, by a made-up name; windows closed since; the windows raised, in order.
    var focused: [pid_t: String] = [:]
    var closedWindows: Set<String> = []
    private(set) var raised: [String] = []
    func focusedWindow(_ pid: pid_t) -> AnyObject? { focused[pid].map { $0 as NSString } }
    func raise(_ window: AnyObject) -> Bool {
        let name = (window as! NSString) as String
        guard !closedWindows.contains(name) else { return false }
        raised.append(name)
        focused[front ?? 0] = name
        return true
    }

    /// N2.2, N2.3: the real change logic (`HandChanges`) on made-up Notes, Excel, reminders and events in memory.
    let apps = FakeScripts()
    let items = FakeItems()
    private(set) var changed: [HandScript] = []
    private var changes: HandChanges { HandChanges(script: apps.run, items: items) }
    func facts(_ script: HandScript) -> HandFacts { changes.facts(script) }
    func change(_ script: HandScript, stop: @escaping () -> Bool) -> (HandEnd, HandKept?) {
        lock.withLock { changed.append(script) }
        return changes.run(script)
    }
}

@MainActor
final class HandTests: XCTestCase {
    private var suite = ""
    private var defaults: UserDefaults!
    private var neverRead: NeverReadList!
    private var fake: FakeSurface!
    private var savedLog: URL!
    private var log: URL!

    override func setUp() {
        suite = "PhewTests.hand.\(UUID().uuidString)"
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

    // MARK: - The off switch

    func testOffRefusesEverything() {
        defaults.set(false, forKey: Hand.allowedKey)  // the menu's switch, off
        let hand = self.hand()
        let press = fake.add("Bold", frame: frame(0))
        fake.menus[["Format", "Bold"]] = FakeSurface.Element(HandSeen(role: "AXMenuItem", name: "Bold"), window: "")
        var steps = [press, fake.add("Title", role: "AXTextField", frame: frame(1)),
                     HandStep(kind: .pick, pid: FakeSurface.pid, role: "AXMenuItem", menuPath: ["Format", "Bold"]),
                     HandStep(kind: .click, pid: FakeSurface.pid, frame: CGRect(x: 60, y: 35, width: 0, height: 0))]
        steps[1].text = "made up"
        for step in steps { XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .off, "\(step.kind)") }
        XCTAssertEqual(fake.sentCount, 0)
    }

    // MARK: - The Never list

    func testNeverWordsEnglishAndItalian() {
        let refused: [(String, HandEnd)] = [
            ("Pay now", .paying), ("Paga ora", .paying), ("Buy", .paying), ("Acquista", .paying), ("Checkout", .paying),
            ("Procedi al pagamento", .paying), ("Card number", .paying), ("Numero della carta", .paying),
            ("Subscribe", .paying), ("Abbonati", .paying), ("Billing", .paying), ("Fatturazione", .paying),
            ("Sign in", .signIn), ("Sign-In", .signIn), ("Accedi", .signIn), ("Log in", .signIn), ("Login", .signIn),
            ("Effettua l’accesso", .signIn), ("Account settings", .signIn), ("Impostazioni dell'account", .signIn),
            ("Password", .password), ("Change password", .password), ("Codice di sicurezza", .password),
            ("Security code", .password),
        ]
        for (i, (name, reason)) in refused.enumerated() {
            let hand = self.hand()
            let step = fake.add(name, frame: CGRect(x: 600, y: 20 + i * 40, width: 100, height: 30))
            XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, reason, name)
        }
        // R3 (17 November): the window's title is not judged, only the control and its menu path. A harmless control
        // in a window named for a sign-in or a payment acts; a paying control is refused whatever the window.
        for title in ["Login screen", "Payment plan", "Accedi al tuo account", "Checkout", "Sign in to iCloud", "Made-up notes"] {
            var hand = self.hand()
            let bold = fake.add("Bold", frame: CGRect(x: 800, y: fake.elements.count * 40, width: 100, height: 30), window: title)
            XCTAssertEqual(hand.act(bold, in: hand.begin(watchUser: false)).end, .done, title)
            hand = self.hand()
            let pay = fake.add("Pay now", frame: CGRect(x: 800, y: fake.elements.count * 40, width: 100, height: 30), window: title)
            XCTAssertEqual(hand.act(pay, in: hand.begin(watchUser: false)).end, .paying, title)
        }
        XCTAssertEqual(fake.sentCount, 6)
        fake = FakeSurface()
        // A menu path.
        fake.menus[["Account", "Sign In…"]] = FakeSurface.Element(HandSeen(role: "AXMenuItem", name: "Sign In…"), window: "")
        let hand = self.hand()
        XCTAssertEqual(hand.act(HandStep(kind: .pick, pid: FakeSurface.pid, role: "AXMenuItem", menuPath: ["Account", "Sign In…"]),
                                in: hand.begin(watchUser: false)).end, .signIn)
        XCTAssertEqual(fake.sentCount, 0)
        // Whole words only, and harmless names act.
        for name in ["Bold", "Grassetto", "Display", "Spaghetti", "Paypal-free layout", "Compravendita"] {
            let hand = self.hand()
            let step = fake.add(name, frame: CGRect(x: 1000, y: fake.elements.count * 40, width: 100, height: 30))
            XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .done, name)
        }
    }

    /// R7: order and money buttons in English and Italian are paying, by code; sorting and ordinary words are not.
    func testOrderAndMoneyButtonsArePaying() {
        func refusal(_ texts: [String]) -> HandEnd? { NeverList.refusal(role: "AXButton", subrole: "", focusedSecure: false, texts: texts) }
        for name in ["Confirm order", "Confirm your order", "Order now", "Complete order", "Complete your order", "Place your order",
                     "Submit order", "Order", "Donate", "Donate now", "Send money", "Transfer money", "Transfer",
                     "Conferma ordine", "Conferma l’ordine", "Completa l'ordine", "Invia ordine", "Ordina ora", "Ordina adesso",
                     "Ordina", "Dona", "Dona ora", "Fai una donazione", "Bonifico", "Esegui bonifico", "Invia denaro", "Invia soldi"] {
            XCTAssertEqual(refusal([name]), .paying, name)
        }
        XCTAssertEqual(refusal(["Continue", "Order now – Made-up Shop"]), .paying, "in any text given: the name or the menu path")
        for name in ["Order by date", "Sort order", "Reorder", "Recent orders", "Ordina per nome", "Ordine alfabetico", "Ordinary",
                     "Transfer files", "Donald", "Riordina", "In ordine", "Ordinal"] {
            XCTAssertNil(refusal([name, "Made-up list"]), name)
        }
    }

    func testNeverApps() {
        let apps: [(String, HandEnd)] = [
            ("com.apple.systempreferences", .neverActApp), ("com.apple.settings.PrivacySecurity.extension", .neverActApp),
            ("com.apple.Terminal", .neverActApp), ("com.googlecode.iterm2", .neverActApp), ("com.apple.dt.Xcode", .neverActApp),
            ("com.microsoft.VSCode", .neverActApp), ("com.jetbrains.intellij", .neverActApp),
            ("com.1password.1password", .neverActApp), ("com.apple.keychainaccess", .neverActApp),
            ("com.apple.Passwords", .neverActApp), ("com.example.private-diary", .neverReadApp),
        ]
        neverRead.add(name: "Private Diary", bundleID: "com.example.private-diary")
        let step = fake.add("Bold", frame: frame(0))
        for (bundleID, reason) in apps {
            fake.bundles[FakeSurface.pid] = bundleID
            let hand = self.hand()
            XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, reason, bundleID)
        }
        fake.bundles[FakeSurface.pid] = nil  // no bundle id: careful side
        var hand = self.hand()
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .neverActApp)
        fake.bundles[FakeSurface.pid] = "com.example.practice"
        hand = self.hand(ownPID: FakeSurface.pid)  // Phew's own windows
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .ownApp)
        XCTAssertEqual(fake.sentCount, 0)
    }

    func testSecureFieldsAreNeverWrittenOrPressed() {
        var step = fake.add("Secret", role: "AXTextField", subrole: "AXSecureTextField", frame: frame(0))
        step.text = "made up"
        var hand = self.hand()
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .secureField)
        step.kind = .press
        hand = self.hand()
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .secureField)
        // A plain field while a secure one has focus, and anything while secure input mode is on.
        var plain = fake.add("Title", role: "AXTextField", frame: frame(1))
        plain.text = "made up"
        fake.focusedSecure = true
        hand = self.hand()
        XCTAssertEqual(hand.act(plain, in: hand.begin(watchUser: false)).end, .secureField)
        fake.focusedSecure = false
        fake.secureInputOn = true
        hand = self.hand()
        XCTAssertEqual(hand.act(plain, in: hand.begin(watchUser: false)).end, .secureInput)
        XCTAssertEqual(fake.sentCount, 0)
    }

    func testCarefulSide() {
        // R45: a fixed guess, not this Mac's language model. German and sure; English and sure; anything unsure.
        let system = NeverList.guessLanguage
        defer { NeverList.guessLanguage = system }
        NeverList.guessLanguage = { $0.contains("bestellen") ? (.german, 0.9) : $0.contains("vielleicht") ? (.german, 0.5) : (.english, 0.9) }
        XCTAssertTrue(NeverList.careful(name: "Jetzt bestellen", texts: []))
        XCTAssertFalse(NeverList.careful(name: "vielleicht", texts: []), "an unsure guess is not the careful side")
        XCTAssertTrue(NeverList.careful(name: " ", texts: ["made up"]), "no name at all")
        let unnamed = fake.add("", frame: frame(0))
        let german = fake.add("Jetzt bestellen und sofort bezahlen", frame: frame(1))
        let english = fake.add("Make the selected text bigger", frame: frame(2))
        // F4: a control with no name is in the "cannot be undone" class too, not only marked.
        for (step, mark, final) in [(unnamed, true, true), (german, true, false), (english, false, false)] {
            let hand = self.hand()
            XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)), HandResult(end: .done, marked: mark, final: final), step.name)
        }
    }

    // MARK: - Ceilings

    func testCeilings() {
        var time = Date(timeIntervalSince1970: 1_000_000)
        let step = fake.add("Bold", frame: frame(0))
        // 40 per job: spaced so the minute ceiling never bites.
        var hand = self.hand(now: { time })
        var job = hand.begin(watchUser: false)
        for i in 0..<Hand.perJob {
            XCTAssertEqual(hand.act(step, in: job).end, .done, "action \(i + 1)")
            time += 5
        }
        XCTAssertEqual(hand.act(step, in: job).end, .jobCeiling)
        // 20 per minute, across jobs.
        hand = self.hand(now: { time })
        for _ in 0..<Hand.perMinute { XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .done) }
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .minuteCeiling)
        time += 61
        job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step, in: job).end, .done)
        XCTAssertEqual(fake.sentCount, Hand.perJob + Hand.perMinute + 1)
    }

    // MARK: - Surprises: stop, never retry

    func testMovedTargetStopsWithNoRetry() {
        let step = fake.add("Bold", frame: frame(0))
        fake.elements[0].seen.frame = frame(0).offsetBy(dx: 10, dy: 0)
        let hand = self.hand()
        let job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step, in: job).end, .moved)
        fake.elements[0].seen.frame = frame(0)  // back in place: the job is still over
        XCTAssertEqual(hand.act(step, in: job).end, .moved)
        // Renamed, or another kind of control at that place.
        fake.elements[0].seen.name = "Italic"
        let renamed = self.hand()
        XCTAssertEqual(renamed.act(step, in: renamed.begin(watchUser: false)).end, .moved)
        fake.elements = []
        let gone = self.hand()
        XCTAssertEqual(gone.act(step, in: gone.begin(watchUser: false)).end, .gone)
        XCTAssertEqual(fake.sentCount, 0)
    }

    func testSurpriseSheetStopsUnlessCalledFor() {
        let open = fake.add("Open sheet", frame: frame(0))
        let bold = fake.add("Bold", frame: frame(1))
        var hand = self.hand()
        var job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(open, in: job).end, .done)
        fake.dialogCount = 1
        XCTAssertEqual(hand.act(bold, in: job).end, .surprise)
        XCTAssertEqual(hand.act(bold, in: job).end, .surprise)
        XCTAssertEqual(fake.sentCount, 1)
        // A step that calls for a window: the next one goes ahead.
        fake.dialogCount = 0
        var opens = open
        opens.opensWindow = true
        hand = self.hand()
        job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(opens, in: job).end, .done)
        fake.dialogCount = 1
        XCTAssertEqual(hand.act(bold, in: job).end, .done)
    }

    func testFrontAppChangedStops() {
        let step = fake.add("Bold", frame: frame(0))
        fake.front = 99
        let hand = self.hand()
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .frontChanged)
        XCTAssertEqual(fake.sentCount, 0)
    }

    // MARK: - Stop

    func testStopWithinOneSecondOnASlowControl() async throws {
        fake.delay = PracticeWindow.slow
        let step = fake.add("Slow", frame: frame(0))
        for run in 0..<10 {
            let hand = self.hand()
            let job = hand.begin(watchUser: false)
            let (late, ends, stopToEnd) = try await stopRun(hand, step, job, after: Double.random(in: 0.2...1.5))
            XCTAssertLessThan(stopToEnd, 1, "run \(run)")
            XCTAssertEqual(late, 0, "run \(run): a step acted after Stop")
            XCTAssertEqual(ends.last, .stopped, "run \(run)")
        }
    }

    /// PL.1, measured: a click posted to another app's pid lands only when made by AppKit with the window's number and
    /// the point inside it, flipped against the main screen's height. A point not inside any window of the app gives none.
    func testClickLocationAndWindow() {
        let bounds = CGRect(x: 881, y: 153, width: 420, height: 472)
        XCTAssertEqual(AXSurface.clickLocation(CGPoint(x: 961, y: 440), in: bounds, mainHeight: 982), NSPoint(x: 80, y: 695))
        XCTAssertEqual(AXSurface.clickLocation(CGPoint(x: 881, y: 153), in: bounds, mainHeight: 982), NSPoint(x: 0, y: 982))
        XCTAssertNil(AXSurface.window(of: 999_999, at: CGPoint(x: 10, y: 10)))
    }

    /// N2.9: a window on a second display. Main display 1440 x 900 (the one with the menu bar); global coordinates have
    /// their origin at its top-left. The point inside the window comes out the same wherever the window sits.
    func testClickLocationOnASecondDisplay() {
        let inside = NSPoint(x: 80, y: 900 - 287)  // 80 right of the window's left edge, 287 down from its top
        let windows = [
            CGRect(x: -1600, y: 120, width: 420, height: 472),   // display to the left: negative x
            CGRect(x: 1700, y: -150, width: 420, height: 472),   // display to the right, taller and higher: negative y
            CGRect(x: 300, y: -1000, width: 420, height: 472),   // display above
            CGRect(x: 1500, y: 600, width: 420, height: 472),    // display to the right, lower than the main one
        ]
        for bounds in windows {
            let point = CGPoint(x: bounds.minX + 80, y: bounds.minY + 287)
            XCTAssertEqual(AXSurface.clickLocation(point, in: bounds, mainHeight: 900), inside, "\(bounds)")
        }
    }

    func testUserInputStopsAndOwnClicksDoNot() throws {
        let step = fake.add("Bold", frame: frame(0))
        let hand = self.hand()
        let job = hand.begin(watchUser: false, in: FakeSurface.pid)
        let own = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left))
        own.setIntegerValueField(.eventSourceUserData, value: Hand.mark)
        hand.seen(own, by: job)  // made, never posted
        XCTAssertNil(job.end)
        XCTAssertEqual(hand.act(step, in: job).end, .done)
        hand.seen(try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)), by: job)  // the front app is his
        XCTAssertEqual(job.end, .userInput)
        XCTAssertEqual(hand.act(step, in: job).end, .userInput)
        XCTAssertEqual(fake.sentCount, 1)
    }

    // MARK: - actions.log

    func testActionLogHoldsOnlyNumbersAndFixedWords() throws {
        let planted = ["Planted Secret Name", "planted typed text 4242", "Planted Window Title", "Paga ora subito", "made-up-role"]
        var set = fake.add(planted[0], role: "AXTextField", frame: frame(0), window: planted[2])
        set.text = planted[1]
        let pay = fake.add(planted[3], frame: frame(1), window: planted[2])
        fake.add("Planted Other", role: "AXButton \(planted[4])", frame: frame(2), window: planted[2])
        let hand = self.hand()
        XCTAssertEqual(hand.act(set, in: hand.begin(watchUser: false)).end, .done)
        XCTAssertEqual(hand.act(pay, in: hand.begin(watchUser: false)).end, .paying)
        var odd = HandStep(kind: .press, pid: FakeSurface.pid, frame: frame(2))
        odd.name = "Planted Other"
        _ = hand.act(odd, in: hand.begin(watchUser: false))
        ActionLog.flush()

        let text = try String(contentsOf: log, encoding: .utf8)
        for word in planted + ["Planted", "planted", "Practice", "4242"] { XCTAssertFalse(text.contains(word), word) }
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 3)
        let kinds = Set(HandStep.Kind.allCases.map(\.rawValue)), ends = Set(HandEnd.allCases.map(\.rawValue))
        for line in lines {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["ts", "job", "step", "kind", "role", "ended", "marked", "ms", "chars"])
            XCTAssertTrue(kinds.contains(json["kind"] as? String ?? ""))
            XCTAssertTrue(ends.contains(json["ended"] as? String ?? ""))
            let role = try XCTUnwrap(json["role"] as? String)
            XCTAssertTrue(role == "other" || role.range(of: #"^AX[A-Za-z]+$"#, options: .regularExpression) != nil, role)
            XCTAssertNotNil(ISO8601DateFormatter().date(from: json["ts"] as? String ?? ""))
            for key in ["job", "step", "ms", "chars"] { XCTAssertNotNil(json[key] as? Int, key) }
        }
        XCTAssertTrue(lines[0].contains(#""chars":\#(planted[1].count)"#))
        XCTAssertTrue(lines[2].contains(#""role":"other""#))
    }

    // MARK: - Scripts (PH.6): the same gates, behind the app

    private func script(_ s: HandScript) -> HandStep { HandStep(kind: .script, pid: 0, script: s) }

    func testScriptsPassTheSameGates() {
        let note = script(.note(title: "Phew test 1234 made up", body: "A made-up line"))
        // Off.
        defaults.set(false, forKey: Hand.allowedKey)
        var hand = self.hand()
        XCTAssertEqual(hand.act(note, in: hand.begin(watchUser: false)).end, .off)
        defaults.set(true, forKey: Hand.allowedKey)
        // The app it acts in on the Never read list, whatever app is in front; secure input on.
        neverRead.add(name: "Notes", bundleID: "com.apple.Notes")
        hand = self.hand()
        XCTAssertEqual(hand.act(note, in: hand.begin(watchUser: false)).end, .neverReadApp)
        neverRead.remove("com.apple.Notes")
        fake.secureInputOn = true
        hand = self.hand()
        XCTAssertEqual(hand.act(note, in: hand.begin(watchUser: false)).end, .secureInput)
        fake.secureInputOn = false
        XCTAssertTrue(fake.scripts.isEmpty)
        // Not the front app and nothing on screen: a script needs neither. The front app is something else.
        fake.front = 99
        hand = self.hand()
        let job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(note, in: job).end, .done)
        XCTAssertEqual(hand.act(script(.append(text: "Another made-up line")), in: job).end, .done)
        XCTAssertEqual(job.made, [HandMade(kind: "note", id: "made-1", title: "Phew test 1234 made up")])
        // Append and cells act only on what this job made.
        let other = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(script(.cells(top: "A1", rows: [["1"]])), in: other).end, .gone)
        // Stop before the script: it is not run.
        let stopped = hand.begin(watchUser: false)
        stopped.stop()
        XCTAssertEqual(hand.act(script(.workbook), in: stopped).end, .stopped)
        XCTAssertEqual(fake.scripts.count, 3)
        // An app that refuses ends the job, never tried again.
        fake.scriptEnd = .noAccess
        let refused = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(script(.workbook), in: refused).end, .noAccess)
        XCTAssertEqual(hand.act(script(.workbook), in: refused).end, .noAccess)
        XCTAssertEqual(fake.scripts.count, 4)
    }

    /// The click that answers macOS's one-time question, or any click while a script runs behind the app, does not
    /// end the job; one before or after it does. Stop always does.
    func testUserInputDuringAScriptDoesNotEndTheJob() throws {
        let click = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left))
        let hand = self.hand()
        let job = hand.begin(watchUser: false, in: FakeSurface.pid)
        fake.during = { hand.seen(click, by: job) }  // made, never posted; lands in the app he works in
        XCTAssertEqual(hand.act(script(.workbook), in: job).end, .done)
        XCTAssertNil(job.end)
        fake.during = nil
        hand.seen(click, by: job)
        XCTAssertEqual(job.end, .userInput)
        let stopped = hand.begin(watchUser: false)
        fake.during = { stopped.stop() }
        XCTAssertEqual(hand.act(script(.workbook), in: stopped).end, .done, "the fake finishes what it was sent")
        XCTAssertEqual(stopped.end, .stopped)
    }

    /// R30: a slow script never makes `begin` on the main thread wait: a second job starts at once.
    func testASlowScriptDoesNotHoldBeginOnTheMainThread() {
        let hand = self.hand()
        let job = hand.begin(watchUser: false)
        let running = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0), ended = DispatchSemaphore(value: 0)
        fake.during = { running.signal(); release.wait() }
        // A backstop, so the test ends even if `begin` waits.
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { release.signal() }
        let step = script(.workbook)
        DispatchQueue.global().async { _ = hand.act(step, in: job); ended.signal() }
        running.wait()
        let start = Date()
        _ = hand.begin(watchUser: false)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5, "begin did not wait for the script")
        release.signal()
        ended.wait()
        fake.during = nil
    }

    func testScriptsCountTowardsTheCeilings() {
        var time = Date(timeIntervalSince1970: 1_000_000)
        let hand = self.hand(now: { time })
        let step = script(.reminder(title: "Phew test 1234 made up", due: nil))
        for _ in 0..<Hand.perMinute { XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .done) }
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .minuteCeiling)
        time += 61
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .done)
    }

    func testScriptLogLineHoldsNoWords() throws {
        let hand = self.hand()
        let job = hand.begin(watchUser: false)
        let planted = "Planted Reminder Title 4242"
        XCTAssertEqual(hand.act(script(.reminder(title: planted, due: DateComponents(year: 2031, month: 3, day: 9, hour: 10, minute: 0))), in: job).end, .done)
        ActionLog.flush()
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertFalse(text.contains("Planted") || text.contains("4242") || text.contains("2031-03-09"))
        XCTAssertTrue(text.contains(#""kind":"script""#) && text.contains(#""role":"other""#) && text.contains(#""chars":\#(planted.count)"#), text)
    }

    func testExcelRangesAndReadBack() {
        XCTAssertEqual(Hand.range(top: "A1", rows: 1, columns: 1), "A1")
        XCTAssertEqual(Hand.range(top: "b2", rows: 4, columns: 3), "B2:D5")
        XCTAssertEqual(Hand.range(top: "Y1", rows: 1, columns: 3), "Y1:AA1")
        XCTAssertEqual(Hand.range(top: "ZZ10", rows: 2, columns: 2), "ZZ10:AAA11")
        for bad in ["", "A0", "1A", "A1:B2", "A1\" & x", "AAAA1", "A 1"] { XCTAssertNil(Hand.range(top: bad, rows: 1, columns: 1), bad) }
        XCTAssertNil(Hand.range(top: "XFD1", rows: 1, columns: 2), "past the last column")
        XCTAssertTrue(Hand.sameCells(["12", "3.5", "made up", "=A1+1"], ["12", "3.50", "made up", "=A1+1"]))
        XCTAssertFalse(Hand.sameCells(["12"], ["13"]))
        XCTAssertFalse(Hand.sameCells(["12", ""], ["12"]))
        // The read-back as Excel hands it: rows of cells, or one value for one cell (no Excel needed).
        func back(_ value: String) -> String {
            AXSurface.osascript("on run argv\nset held to \(value)\n" + AXSurface.readBack + "\nend run", [], stop: { false }).1
        }
        XCTAssertEqual(back(#"{{"Made up", "10"}, {"20", ""}}"#).components(separatedBy: "\u{1F}"), ["Made up", "10", "20", ""])
        XCTAssertEqual(back(#"{{"a"}, {"b"}}"#).components(separatedBy: "\u{1F}"), ["a", "b"])
        XCTAssertEqual(back(#""one cell""#), "one cell")
    }

    /// The words go in as the run handler's list, never as script code, and as text in a note.
    func testScriptWordsStayData() {
        let trick = #"x" & (do shell script "echo planted") & "y"#
        let (end, out) = AXSurface.osascript("on run argv\nreturn item 1 of argv\nend run", [trick], stop: { false })
        XCTAssertEqual(end, .done)
        XCTAssertEqual(out, trick)
        XCTAssertEqual(AXSurface.html(["Made <b>up</b> & more", ""]), "<div>Made &lt;b&gt;up&lt;/b&gt; &amp; more</div><div><br></div>")
        // Stop cuts a running script.
        let start = Date()
        let (stopped, _) = AXSurface.osascript("delay 5", [], stop: { Date().timeIntervalSince(start) > 0.3 })
        XCTAssertEqual(stopped, .stopped)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
    }

    /// R4: a word that looks like one of osascript's own options ("-e…", "--") stays a word: every script line has
    /// its own "-e", then "--" ends the options, then the words, untouched. Built here, never run.
    func testWordsThatLookLikeOptionsStayData() {
        let words = ["-e", #"-e do shell script "x""#, "--", #"-eproperty x : (do shell script "exit 3")"#, "-l", "-s",
                     #"A "quoted" made-up title \ with \\ backslashes"#, "Made-up line one\nline two", ""]
        for source in [HandChanges.findNotes, HandChanges.changeNote, HandChanges.restoreNote, AXSurface.makeNote, AXSurface.fillCells] {
            let lines = source.split(separator: "\n").map(String.init)
            for word in words {
                let args = AXSurface.arguments(source, [word, "second"])
                XCTAssertEqual(Array(args.prefix(lines.count * 2)), lines.flatMap { ["-e", $0] }, word)
                XCTAssertEqual(Array(args.dropFirst(lines.count * 2)), ["--", word, "second"], word)
            }
        }
        // The script runner gets each title as the find script's first word, as given.
        let changes = HandChanges(script: fake.apps.run, items: fake.items)
        for word in words { _ = changes.run(.delete(.note, title: word)) }
        XCTAssertEqual(fake.apps.found, words)
    }

    /// R5: a tool's long answer is read while it runs, so a big note body never fills the pipe and hangs osascript
    /// until the time limit. A shell writes 200,000 made-up letters; no app, no osascript.
    func testALongAnswerIsReadWhileTheToolRuns() {
        let started = Date()
        let (end, out) = AXSurface.run("/bin/sh", ["-c", "head -c 200000 /dev/zero | tr '\\0' a"], timeout: 5, stop: { false })
        XCTAssertEqual(end, .done)
        XCTAssertEqual(out.count, 200_000)
        XCTAssertLessThan(Date().timeIntervalSince(started), 4)
    }

    /// R22 (a, b): the user's own clicks and keys are watched from the job's start to its close, and his own click is
    /// marked, so the watch never ends a job on it. No event is posted.
    func testTheWatchRunsForTheJobAndHisClickIsMarked() throws {
        let hand = hand()
        let watched = hand.begin(watchUser: true)
        XCTAssertTrue(watched.watching)
        hand.close(watched)
        XCTAssertFalse(watched.watching)
        XCTAssertFalse(hand.begin(watchUser: false).watching)
        XCTAssertEqual(Hand.userEvents, [.leftMouseDown, .rightMouseDown, .keyDown])
        let click = try XCTUnwrap(AXSurface.clickEvents(NSPoint(x: 10, y: 10), window: 1))
        XCTAssertEqual(click.map(\.type), [.leftMouseDown, .leftMouseUp])
        XCTAssertTrue(click.allSatisfy(Hand.isOwn))
    }

    // MARK: - PH.7: several apps in one job

    private static let sheets: pid_t = 7
    private func front(_ app: String = "com.example.sheets") -> HandStep { HandStep(kind: .front, pid: 0, name: "Sheets", app: app) }

    func testFrontSwitchPassesTheGates() throws {
        fake.bundles[Self.sheets] = "com.example.sheets"  // running, behind the practice app
        // Off.
        defaults.set(false, forKey: Hand.allowedKey)
        var hand = self.hand()
        XCTAssertEqual(hand.act(front(), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .off)
        defaults.set(true, forKey: Hand.allowedKey)
        // The Never list for the app brought, before anything of it is read: Never read, never act, Phew's own,
        // secure input on.
        neverRead.add(name: "Sheets", bundleID: "com.example.sheets")
        hand = self.hand()
        XCTAssertEqual(hand.act(front(), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .neverReadApp)
        neverRead.remove("com.example.sheets")
        fake.launchable["com.apple.Terminal"] = 8
        hand = self.hand()
        XCTAssertEqual(hand.act(front("com.apple.Terminal"), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .neverActApp)
        hand = self.hand(ownPID: Self.sheets)
        XCTAssertEqual(hand.act(front(), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .ownApp)
        fake.secureInputOn = true
        hand = self.hand()
        XCTAssertEqual(hand.act(front(), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .secureInput)
        fake.secureInputOn = false
        // Only from the app the job works in: a front change he did not make stops the job.
        fake.front = 99
        hand = self.hand()
        XCTAssertEqual(hand.act(front(), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .frontChanged)
        fake.front = FakeSurface.pid
        XCTAssertEqual(fake.activated, [])
        XCTAssertEqual(fake.reads, 0, "nothing of any app was read")
        // An app that does not come up ends the job, never tried again.
        fake.activateEnd = .timeout
        hand = self.hand()
        let slow = hand.begin(watchUser: false, in: FakeSurface.pid)
        XCTAssertEqual(hand.act(front(), in: slow).end, .timeout)
        XCTAssertEqual(hand.act(front(), in: slow).end, .timeout)
        XCTAssertEqual(fake.activated.count, 1)
        fake.activateEnd = .done

        // The switch: the app brought is the job's app now, and a step there acts.
        hand = self.hand()
        let job = hand.begin(watchUser: false, in: FakeSurface.pid)
        XCTAssertEqual(hand.act(front(), in: job).end, .done)
        XCTAssertEqual(fake.front, Self.sheets)
        XCTAssertEqual(job.app, Self.sheets)
        var bold = fake.add("Bold", frame: frame(0))
        bold.pid = Self.sheets
        XCTAssertEqual(hand.act(bold, in: job).end, .done)
        // A front change he did not make still stops the job.
        fake.front = FakeSurface.pid
        XCTAssertEqual(hand.act(bold, in: job).end, .frontChanged)
        XCTAssertEqual(fake.sentCount, 1)
        // The log line: fixed words, no app.
        ActionLog.flush()
        let text = try String(contentsOf: log, encoding: .utf8)
        XCTAssertFalse(text.contains("sheets") || text.contains("Sheets") || text.contains("Terminal"))
        XCTAssertTrue(text.contains(#""kind":"front""#) && text.contains(#""role":"other""#), text)
    }

    func testFrontSwitchesCountTowardsTheCeilings() {
        fake.bundles[Self.sheets] = "com.example.sheets"
        let time = Date(timeIntervalSince1970: 1_000_000)
        let hand = self.hand(now: { time })
        for _ in 0..<Hand.perMinute {
            fake.front = FakeSurface.pid
            XCTAssertEqual(hand.act(front(), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .done)
        }
        fake.front = FakeSurface.pid
        XCTAssertEqual(hand.act(front(), in: hand.begin(watchUser: false, in: FakeSurface.pid)).end, .minuteCeiling)
    }

    /// Back to the app the user was in on done, stuck, Stop and a refused step; never after their own take-over.
    func testBackReturnsUnlessTheUserTookOver() {
        fake.bundles[Self.sheets] = "com.example.sheets"
        let hand = self.hand()
        func switched() -> HandJob {
            fake.front = FakeSurface.pid
            let job = hand.begin(watchUser: false, in: FakeSurface.pid)
            XCTAssertEqual(hand.act(front(), in: job).end, .done)
            return job
        }
        // Done or stuck: the job has no end of its own yet.
        XCTAssertEqual(hand.back(switched()), .done)
        XCTAssertEqual(fake.front, FakeSurface.pid)
        // Stop.
        var job = switched()
        job.stop()
        XCTAssertEqual(hand.back(job), .done)
        XCTAssertEqual(fake.front, FakeSurface.pid)
        // A refused step in the app he brought.
        job = switched()
        var pay = fake.add("Pay now", frame: frame(3))
        pay.pid = Self.sheets
        XCTAssertEqual(hand.act(pay, in: job).end, .paying)
        XCTAssertEqual(hand.back(job), .done)
        XCTAssertEqual(fake.front, FakeSurface.pid)
        XCTAssertEqual(fake.activated, Array(repeating: ["com.example.sheets", "com.example.practice"], count: 3).flatMap { $0 })
        // The user took over in the app he brought: he leaves them there.
        job = switched()
        fake.clickOwner = Self.sheets
        hand.seen(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left)!, by: job)
        XCTAssertEqual(job.end, .userInput)
        XCTAssertNil(hand.back(job))
        XCTAssertEqual(fake.front, Self.sheets)
        // The user brought another app to the front: he leaves them there too.
        job = switched()
        fake.front = 99
        XCTAssertNil(hand.back(job))
        XCTAssertEqual(fake.front, 99)
        // No switch, nothing to return; and the switch off refuses the return too.
        fake.front = FakeSurface.pid
        XCTAssertNil(hand.back(hand.begin(watchUser: false, in: FakeSurface.pid)))
        job = switched()
        defaults.set(false, forKey: Hand.allowedKey)
        XCTAssertEqual(hand.back(job), .off)
        XCTAssertEqual(fake.front, Self.sheets)
    }

    /// N2.8: back to the exact window the user was in when the job began, not only the app; when it is gone, the app
    /// as it comes, as before.
    func testBackReturnsToTheExactWindow() {
        fake.bundles[Self.sheets] = "com.example.sheets"
        let hand = self.hand()
        func job() -> HandJob {
            fake.front = FakeSurface.pid
            let job = hand.begin(watchUser: false, in: FakeSurface.pid)
            fake.focused[FakeSurface.pid] = "Made-up window one"  // the app's other window came up meanwhile
            XCTAssertEqual(hand.act(front(), in: job).end, .done)
            return job
        }
        fake.focused[FakeSurface.pid] = "Made-up window two"
        XCTAssertEqual(hand.back(job()), .done)
        XCTAssertEqual(fake.front, FakeSurface.pid)
        XCTAssertEqual(fake.raised, ["Made-up window two"])
        XCTAssertEqual(fake.focused[FakeSurface.pid], "Made-up window two")
        // The window was closed during the job: the app comes back as it is, nothing else raised.
        fake.focused[FakeSurface.pid] = "Made-up window two"
        let gone = job()
        fake.closedWindows = ["Made-up window two"]
        XCTAssertEqual(hand.back(gone), .done)
        XCTAssertEqual(fake.front, FakeSurface.pid)
        XCTAssertEqual(fake.raised, ["Made-up window two"])
        // No window at the start: the app only.
        fake.focused = [:]
        let bare = hand.begin(watchUser: false, in: FakeSurface.pid)
        XCTAssertEqual(hand.act(front(), in: bare).end, .done)
        XCTAssertEqual(hand.back(bare), .done)
        XCTAssertEqual(fake.raised, ["Made-up window two"])
    }

    /// The user's own click or key stops the job only in the app he works in now (the user's word, PH.7).
    func testUserInputStopsOnlyInTheAppHeWorksIn() throws {
        fake.bundles[Self.sheets] = "com.example.sheets"
        let click = try XCTUnwrap(CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left))
        let key = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
        let hand = self.hand()
        var job = hand.begin(watchUser: false, in: FakeSurface.pid)
        fake.clickOwner = 99  // another app's window
        hand.seen(click, by: job)
        XCTAssertNil(job.end)
        fake.clickOwner = FakeSurface.pid
        hand.seen(click, by: job)
        XCTAssertEqual(job.end, .userInput)
        // After his switch, the app he brought is his: a click in the user's first app does not stop him.
        job = hand.begin(watchUser: false, in: FakeSurface.pid)
        XCTAssertEqual(hand.act(front(), in: job).end, .done)
        fake.clickOwner = FakeSurface.pid
        hand.seen(click, by: job)
        XCTAssertNil(job.end)
        hand.seen(key, by: job)  // a key lands in the front app, the one he brought
        XCTAssertEqual(job.end, .userInput)
        // Not known where it lands: careful side, it counts.
        job = hand.begin(watchUser: false, in: FakeSurface.pid)
        fake.clickOwner = nil
        hand.seen(click, by: job)
        XCTAssertEqual(job.end, .userInput)
    }

    // MARK: - PH.10: live tests look only at their own made-up window

    func testOnlyTheTestsOwnWindowMayBeSent() {
        let window = CGRect(x: 100, y: 100, width: 420, height: 220), app = "com.example.phew-practice"
        var packet = ContextPacket(appName: "Practice", bundleID: app, windowTitle: "Phew test 4821",
                                   visibleText: "Made up", cursor: nil, windowFrame: window,
                                   pointables: [Pointable(id: "e1", role: "AXButton", label: "Bold", frame: window)])
        packet.screenshot = Data([1])
        packet.screenshotFrame = window
        XCTAssertNil(packet.notTestWindow(marker: "Phew test 4821", app: app))
        XCTAssertEqual(packet.notTestWindow(marker: "", app: app), "marker")
        XCTAssertEqual(packet.notTestWindow(marker: "Practice", app: app), "marker")
        XCTAssertEqual(packet.notTestWindow(marker: "Phew test 9999", app: app), "title")
        var display = packet
        display.screenshotFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)  // the whole display: other windows in it
        XCTAssertEqual(display.notTestWindow(marker: "Phew test 4821", app: app), "picture")
        var noPicture = packet
        noPicture.screenshot = nil
        XCTAssertEqual(noPicture.notTestWindow(marker: "Phew test 4821", app: app), "picture")
        var list = packet
        list.pointables.append(Pointable(id: "e2", role: "AXRow", label: "Another note", frame: window))  // a sidebar or a list
        XCTAssertEqual(list.notTestWindow(marker: "Phew test 4821", app: app), "list")
        var never = packet
        never.neverRead = true
        XCTAssertEqual(never.notTestWindow(marker: "Phew test 4821", app: app), "neverRead")
        // The user's own app in front, even with a title that happens to carry the marker.
        XCTAssertEqual(packet.notTestWindow(marker: "Phew test 4821", app: "com.example.users-browser"), "app")
        var inside = packet
        inside.cursor = CursorElement(role: "AXButton", label: "Bold", value: "", frame: CGRect(x: 120, y: 120, width: 40, height: 20))
        XCTAssertNil(inside.notTestWindow(marker: "Phew test 4821", app: app))
        var outside = packet  // the same app's other window, or no frame at all
        outside.cursor = CursorElement(role: "AXTextArea", label: "", value: "Made up", frame: CGRect(x: 900, y: 600, width: 300, height: 200))
        XCTAssertEqual(outside.notTestWindow(marker: "Phew test 4821", app: app), "cursor")
        outside.cursor?.frame = nil
        XCTAssertEqual(outside.notTestWindow(marker: "Phew test 4821", app: app), "cursor")
    }

    /// The hit test under the mouse is system-wide: its element is read only when it belongs to the app being read.
    func testTheElementUnderTheMouseComesOnlyFromTheAppBeingRead() {
        let me = getpid()
        XCTAssertTrue(WindowReader.readsCursor(owner: 4242, of: 4242))
        XCTAssertFalse(WindowReader.readsCursor(owner: 4243, of: 4242))  // a terminal lying under the mouse
        XCTAssertFalse(WindowReader.readsCursor(owner: me, of: 4242))     // Phew's own panel
        XCTAssertFalse(WindowReader.readsCursor(owner: me, of: me))
    }

    // MARK: - Only Hand.swift acts

    /// What can send an action, or start a program or another app: only Senses/Hand.swift may hold these words.
    static let acting = ["AXUIElementPerformAction", "AXUIElementSetAttributeValue", "AXUIElementPostKeyboardEvent",
                         "CGEventPost", "CGEventTapPostEvent", ".post(tap:", "postToPid", "mouseEventSource:",
                         "keyboardEventSource:", "mouseEvent(with:", "NSAppleScript", "NSUserAppleScriptTask", "osascript", "SBApplication",
                         "NSAppleEventDescriptor", "AESend", "kAXFrontmostAttribute",
                         // R21: the calendar and reminders store, other script runners, opening and bringing apps forward, programs.
                         "EKEventStore", "OSAScript", "NSUserScriptTask", "NSUserUnixTask", "NSUserAutomatorTask",
                         "NSWorkspace.shared.open", ".activate(", "Process()"]
    /// R21: the Hand's own surfaces, which act with no gate when called directly: only `Hand.act` may call them.
    static let surfaces = ["AXSurface", "EventKitItems", "HandChanges", "removeTestItems", "showTestNote"]
    /// Named exceptions, line by line.
    static let exceptions: [String: (String) -> Bool] = [
        // WindowReader asks Chromium, Electron and Keynote to build their full Accessibility tree, for reading only
        // (AXManualAccessibility, AXEnhancedUserInterface, N2.7). It sets those two flags and nothing else.
        "Senses/WindowReader.swift": { $0.contains("[manual, enhanced].contains(name) && AXUIElementSetAttributeValue(app, name as CFString") },
        // The folder window, the one focus exception for Phew itself (CLAUDE.md), and back to the app the user was in.
        "Shell/MenuPanels.swift": { $0.contains("NSApp.activate()") || $0.contains("$0 != .current && $0.activate(from: .current, options: [])") },
        "Shell/PhewApp.swift": { $0.contains("NSApp.activate()") || $0.contains("$0 != .current && $0.activate(from: .current, options: [])") },
        // Setup opens System Settings at the privacy pane, and relaunches Phew itself, on the user's press.
        "Shell/SetupPanel.swift": { $0.contains("NSWorkspace.shared.open($0)") || $0.contains("NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL") },
        // zipinfo and ditto on a chosen ZIP; ditto on a made-up export; say on made-up samples: programs with no window.
        "Map/ClaudeExport.swift": { $0.contains("let process = Process()") },
        "Map/ImportSelfCheck.swift": { $0.contains("let process = Process()") },
        "Senses/HearCheck.swift": { $0.contains("let say = Process()") },
        // NC: the closed box starts one program, the helper on Node under the sandbox tool: no network, no file
        // writes, no child programs, so it cannot act (SkillTests checks each door).
        "Brain/SkillBox.swift": { $0.contains("let process = Process(), stdin = Pipe(), stdout = Pipe()") },
        // The live checks remove, by id, what their own scripts made, and show one made-up note (DEBUG only).
        "Shell/DebugChecks.swift": { $0.contains("Hand.shared.removeTestItems()") || $0.contains("Hand.shared.showTestNote(")
            || $0.contains("(`Hand.removeTestItems`)") },
    ]

    /// Whether `line` of `relative` (a path under Phew/) could act outside the Hand.
    static func acts(_ relative: String, _ line: String) -> Bool {
        guard relative != "Senses/Hand.swift" else { return false }
        return (acting + surfaces).contains(where: line.contains) && exceptions[relative]?(line) != true
    }

    /// R38: a typed value is read back; a field that kept something else ends the job as "check failed", not "done".
    func testATypedValueThatDidNotLandIsNoticed() {
        var step = fake.add("Title", role: "AXTextField", frame: frame(0))
        step.text = "made up"
        var hand = self.hand()
        XCTAssertEqual(hand.act(step, in: hand.begin(watchUser: false)).end, .done)
        fake.wrongSet = true
        hand = self.hand()
        let job = hand.begin(watchUser: false)
        XCTAssertEqual(hand.act(step, in: job).end, .checkFailed)
    }

    /// Fails the build if any file under Phew/ other than Senses/Hand.swift can send an action.
    func testOnlyHandActs() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Phew")
        var files = 0, offenders: [String] = []
        let all = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        for case let url as URL in all where url.pathExtension == "swift" {
            files += 1
            let relative = String(url.path.dropFirst(root.path.count + 1))
            for (n, line) in try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where Self.acts(relative, String(line)) {
                offenders.append("\(relative):\(n + 1)")
            }
        }
        XCTAssertGreaterThan(files, 40, "the scan found the sources")
        XCTAssertEqual(offenders, [], "only Senses/Hand.swift may act")
        let hand = try String(contentsOf: root.appending(path: "Senses/Hand.swift"), encoding: .utf8)
        XCTAssertTrue(hand.contains("AXUIElementPerformAction") && hand.contains("postToPid"), "the scan looks for the right words")
        // R21: the live tests' clean-up acts with no gate: it must stay out of the shipped app.
        for name in ["func removeTestItems", "func showTestNote"] {
            let before = hand[..<(try XCTUnwrap(hand.range(of: name), name)).lowerBound]
            let opened = before.range(of: "#if DEBUG", options: .backwards)?.lowerBound
            let closed = before.range(of: "#endif", options: .backwards)?.lowerBound
            XCTAssertTrue(opened != nil && (closed == nil || closed! < opened!), "\(name) is inside #if DEBUG")
        }
    }

    /// R21: the scan's own check: made-up lines in made-up files that would act are caught, a named exception is not.
    func testTheScanCatchesEveryWayToAct() {
        for line in ["EKEventStore().save(event, span: .thisEvent, commit: true)", "let task = try NSUserUnixTask(url: tool)",
                     "OSAScript(source: made)", "NSUserScriptTask(url: u)", "NSUserAutomatorTask(url: u)",
                     "NSWorkspace.shared.open(url)", "app.activate(options: [])", "let p = Process()",
                     "AXSurface().send(step, to: el)", "AXSurface().run(script, made: [], stop: { false })",
                     "EventKitItems(stop: { false }).remove(id, .event)", "HandChanges(script: run, items: items).run(.delete(.note, title: t))",
                     "Hand.shared.removeTestItems()"] {
            XCTAssertTrue(Self.acts("Brain/MadeUpTool.swift", line), line)
        }
        XCTAssertTrue(Self.acts("Shell/MenuPanels.swift", "NSWorkspace.shared.open(url)"), "an exception names its line, not its file")
        XCTAssertFalse(Self.acts("Shell/DebugChecks.swift", "        let (removed, failed) = Hand.shared.removeTestItems()"))
        XCTAssertFalse(Self.acts("Senses/Hand.swift", "EKEventStore()"))
        XCTAssertFalse(Self.acts("Brain/MadeUpTool.swift", "let reader = WindowReader.readWindow(pid: pid)"))
    }

    // MARK: - The practice window, through the real Accessibility API

    private func realHand() throws -> Hand {
        // These tests open a window on the screen. Off unless asked for (phase PL): `TEST_RUNNER_PHEW_LIVE=1 xcodebuild … test`.
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PHEW_LIVE"] == "1", "practice-window tests are off: they show a window on screen (run in phase PL)")
        try XCTSkipUnless(AXIsProcessTrusted(), "the test runner has no Accessibility permission: real-window tests skipped")
        try XCTSkipIf(IsSecureEventInputEnabled(), Self.secureInputSkip)
        // The practice window lives in the test process: it stands in for the front app and is not "Phew's own".
        return Hand(defaults: defaults, surface: AXSurface(front: { getpid() }), list: neverRead, ownPID: -1)
    }

    /// PH.9: secure input is the whole Mac's, not the practice window's: on while any app has a password field in
    /// focus, a terminal keeps secure keyboard entry, or the Mac is locked. The Hand then rightly refuses every action
    /// (`secureInput`), so a real-window test cannot run: it is skipped, visibly, never passed or failed.
    static let secureInputSkip = "secure input is on (a password field has focus somewhere, or the Mac is locked): real-window test skipped"

    /// On the main thread, unlike for other apps: macOS answers an Accessibility call to the caller's own process
    /// directly there, while from another thread every other press returns a failure although it happened (measured).
    /// Secure input coming on during the test skips it (`secureInputSkip`).
    private func act(_ hand: Hand, _ step: HandStep, _ job: HandJob) throws -> HandEnd {
        let end = hand.act(step, in: job).end
        if end == .secureInput { throw XCTSkip(Self.secureInputSkip + " (it came on during the test)") }
        if end == .moved, let owner = Self.ownerOnTop(step) {
            throw XCTSkip("another app's window (pid \(owner)) lay over the practice window: real-window test skipped")
        }
        return end
    }

    /// PH.9: the pid of another app's window on top at the step's point (another suite's practice window, a
    /// notification banner); nil when the top there is this process. Reads only the owner, never the element.
    private static func ownerOnTop(_ step: HandStep) -> pid_t? {
        var hit: AXUIElement?, owner: pid_t = 0
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(step.frame.midX), Float(step.frame.midY), &hit) == .success,
              let hit, AXUIElementGetPid(hit, &owner) == .success, owner != getpid() else { return nil }
        return owner
    }

    func testPracticeWindowActsAndRefuses() async throws {
        let hand = try realHand()
        let practice = PracticeWindow()
        defer { practice.close() }
        try await Task.sleep(for: .milliseconds(200))
        var job = hand.begin(watchUser: false)
        let pressEnd = try act(hand, practice.press("Bold"), job)
        XCTAssertEqual(pressEnd, .done)
        XCTAssertEqual(practice.presses["Bold"], 1)
        let setEnd = try act(hand, practice.set("A made-up title"), job)
        XCTAssertEqual(setEnd, .done)
        XCTAssertEqual(practice.field.stringValue, "A made-up title")
        let pickEnd = try act(hand, HandStep(kind: .pick, pid: getpid(), role: "AXMenuItem", menuPath: ["Practice", "Make Bold"]), job)
        XCTAssertEqual(pickEnd, .done)
        try await Task.sleep(for: .milliseconds(200))  // a menu item's action runs on the next turn of the run loop
        XCTAssertEqual(practice.presses["Make Bold"], 1)

        let refused: [(HandStep, HandEnd)] = [
            (practice.set("made up", secure: true), .secureField), (practice.press("Pay now"), .paying),
            (practice.press("Paga ora"), .paying), (practice.press("Sign in"), .signIn), (practice.press("Accedi"), .signIn),
            (HandStep(kind: .pick, pid: getpid(), role: "AXMenuItem", menuPath: ["Account", "Sign In…"]), .signIn),
        ]
        for (step, reason) in refused {
            job = hand.begin(watchUser: false)
            let end = try act(hand, step, job)
            XCTAssertEqual(end, reason, step.name + step.menuPath.joined())
        }
        XCTAssertEqual(practice.secret.stringValue, "")
        for name in ["Pay now", "Paga ora", "Sign in", "Accedi"] { XCTAssertNil(practice.presses[name], name) }
        XCTAssertNil(practice.presses["Sign In…"])
        // Phew's own windows: the same window, with the real own pid.
        let own = Hand(defaults: defaults, surface: AXSurface(front: { getpid() }), list: neverRead)
        let ownEnd = try act(own, practice.press("Bold"), own.begin(watchUser: false))
        XCTAssertEqual(ownEnd, .ownApp)
        XCTAssertEqual(practice.presses["Bold"], 1)
    }

    func testPracticeWindowMovedButtonAndSurpriseSheet() async throws {
        let hand = try realHand()
        let practice = PracticeWindow()
        defer { practice.close() }
        try await Task.sleep(for: .milliseconds(200))
        // The look saw "Move me" here; it moved before the action.
        let seen = practice.press("Move me")
        practice.buttons["Move me"]!.setFrameOrigin(NSPoint(x: 240, y: 240))
        var job = hand.begin(watchUser: false)
        let movedEnd = try act(hand, seen, job)
        XCTAssertEqual(movedEnd, .moved)
        let again = try act(hand, practice.press("Move me"), job)  // even where it is now: the job is over
        XCTAssertEqual(again, .moved)
        XCTAssertNil(practice.presses["Move me"])
        // A sheet the job did not call for.
        job = hand.begin(watchUser: false)
        let openEnd = try act(hand, practice.press("Open sheet"), job)
        XCTAssertEqual(openEnd, .done)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNotNil(practice.window.attachedSheet)
        let surpriseEnd = try act(hand, practice.press("Bold"), job)
        XCTAssertEqual(surpriseEnd, .surprise)
        XCTAssertNil(practice.presses["Bold"])
    }

    func testPracticeWindowStopWithinOneSecond() async throws {
        _ = try realHand()
        let practice = PracticeWindow()
        defer { practice.close() }
        try await Task.sleep(for: .milliseconds(200))
        let step = practice.press("Slow")
        var done = 0
        for run in 0..<10 {
            let hand = try realHand()
            let job = hand.begin(watchUser: false)
            let (late, ends, stopToEnd) = try await stopRun(hand, step, job, after: Double.random(in: 0.2...1.5))
            XCTAssertLessThan(stopToEnd, 1, "run \(run)")
            XCTAssertEqual(late, 0, "run \(run): a step acted after Stop")
            XCTAssertEqual(ends.last, .stopped, "run \(run): \(ends.map(\.rawValue))")
            done += ends.filter { $0 == .done }.count
        }
        XCTAssertEqual(practice.presses["Slow"], done, "every press the Hand counted, and no other")
    }

    /// N2.6, live: the practice window's own made-up menu bar, read by Accessibility, gives its commands by name, and
    /// the path as read is one the Hand picks in one step. Off unless PHEW_LIVE (it shows a window).
    func testPracticeWindowMenusAreReadAndPicked() async throws {
        let hand = try realHand()
        let practice = PracticeWindow()
        defer { practice.close() }
        try await Task.sleep(for: .milliseconds(200))
        let names = MenuReader.names(pid: getpid(), list: neverRead)
        XCTAssertTrue(names.contains("Practice: Make Bold"), names)
        XCTAssertTrue(names.contains("Account: Sign In…"), names)
        let end = try act(hand, HandStep(kind: .pick, pid: getpid(), role: "AXMenuItem", menuPath: ["Practice", "Make Bold"]),
                          hand.begin(watchUser: false))
        XCTAssertEqual(end, .done)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(practice.presses["Make Bold"], 1)
    }

    /// N2.7, live: a made-up local page in a test window (WebKit, no network). After the ask for the full tree, its
    /// button and field come back as named controls, and the Hand presses and types by name, with no click at a point.
    /// Off unless PHEW_LIVE (it shows a window). Not run when written: N2.L checks it.
    func testMadeUpPageIsPressedAndTypedByName() async throws {
        let hand = try realHand()
        let window = NSWindow(contentRect: NSRect(x: 160, y: 180, width: 420, height: 240), styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .floating
        let page = WKWebView(frame: window.contentView!.bounds)
        window.contentView?.addSubview(page)
        defer { window.orderOut(nil) }
        page.loadHTMLString("""
            <html><body><button onclick="document.title='pressed'">Made-up send</button>
            <input placeholder="Made-up name"></body></html>
            """, baseURL: nil)
        window.orderFrontRegardless()
        try await Task.sleep(for: .seconds(1))
        if WindowReader.askForFullTree(pid: getpid()).wait { try await Task.sleep(for: .seconds(1)) }
        let read = WindowReader.readWindow(pid: getpid())
        let button = try XCTUnwrap(read.pointables.first { $0.role == "AXButton" && $0.label == "Made-up send" }, "\(read.pointables)")
        let field = try XCTUnwrap(read.pointables.first { $0.role == "AXTextField" && $0.label == "Made-up name" }, "\(read.pointables)")
        let job = hand.begin(watchUser: false)
        let pressed = try act(hand, HandStep(kind: .press, pid: getpid(), role: button.role, name: button.label, frame: button.frame), job)
        XCTAssertEqual(pressed, .done)
        let typed = try act(hand, HandStep(kind: .set, pid: getpid(), role: field.role, name: field.label, frame: field.frame,
                                           text: "Made-up words"), job)
        XCTAssertEqual(typed, .done)
        try await Task.sleep(for: .milliseconds(300))
        let title = try await page.evaluateJavaScript("document.title") as? String
        XCTAssertEqual(title, "pressed")
        let value = try await page.evaluateJavaScript("document.querySelector('input').value") as? String
        XCTAssertEqual(value, "Made-up words")
    }

    /// Runs `step` over and over in `job` while another thread presses Stop after `after` seconds. Returns how many
    /// steps acted after Stop, every end, and the seconds from Stop to the loop's end.
    private func stopRun(_ hand: Hand, _ step: HandStep, _ job: HandJob, after: TimeInterval) async throws
        -> (late: Int, ends: [HandEnd], stopToEnd: TimeInterval) {
        let stopper = Task.detached { () -> Date in
            try? await Task.sleep(for: .seconds(after))
            job.stop()
            return Date()
        }
        var ends: [HandEnd] = [], starts: [Date] = []
        for _ in 0..<15 {
            starts.append(Date())
            let end = try act(hand, step, job)
            ends.append(end)
            if end != .done { break }
        }
        let finished = Date()
        let stopAt = await stopper.value
        let late = zip(starts, ends).filter { $0.0 > stopAt && $0.1 == .done }.count
        return (late, ends, finished.timeIntervalSince(stopAt))
    }
}
