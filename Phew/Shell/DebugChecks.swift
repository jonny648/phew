#if DEBUG
import AppKit

/// Self-checks for the checker, who cannot press keys or click. Each runs only with its launch flag.
extension AppDelegate {
    func runDebugChecks() {
        let arguments = CommandLine.arguments
        // Every motion takes its Reduce Motion form, without touching the system setting.
        if arguments.contains("--debug-reduce-motion") { Design.Motion.forceReduce = true }
        if arguments.contains("--debug-open-panel") { Task { await checkPanel() } }
        // Senses: captures the front app, with a screenshot, into the debug files.
        // An optional bundle id after the flag reads that running app instead, without bringing it forward.
        if let flag = arguments.firstIndex(of: "--debug-capture") {
            let target = arguments.dropFirst(flag + 1).first
                .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { _ = Senses.capture(app: target) }
        }
        if arguments.contains("--debug-brain-check") { BrainSelfCheck.run() }  // real API calls, made-up data
        if arguments.contains("--debug-card") { Task { await checkCard() } }
        if arguments.contains("--debug-guide") { Task { await checkGuide() } }
        if arguments.contains("--debug-thread") { Task { await checkThread() } }
        if arguments.contains("--debug-deleted-check") { Task { await checkDeleted() } }
        if arguments.contains("--debug-export-check") { Task { await checkExport() } }
        if let flag = arguments.firstIndex(of: "--debug-act"), let words = arguments.dropFirst(flag + 1).first {
            Task { await checkAct(words) }
        }
        if arguments.contains("--debug-first-run") { Task { await checkFirstRun() } }
        if let flag = arguments.firstIndex(of: "--debug-add-items"), let marker = arguments.dropFirst(flag + 1).first {
            Task { await checkAddItems(marker) }
        }
        if arguments.contains("--debug-report") { Task { await checkReport() } }
        if let flag = arguments.firstIndex(of: "--debug-menu"), let dir = arguments.dropFirst(flag + 1).first {
            Task { await checkMenu(dir) }
            if let flag = arguments.firstIndex(of: "--debug-list-windows"), let pid = arguments.dropFirst(flag + 1).first.flatMap({ Int32($0) }) {
            listPracticeWindows(pid)
        }
        // PH.11: one click at a screen point (Accessibility coordinates) through the Hand, in a practice app only. No model call.
        if let flag = arguments.firstIndex(of: "--debug-click"), arguments.count > flag + 3, let pid = Int32(arguments[flag + 1]),
           let x = Double(arguments[flag + 2]), let y = Double(arguments[flag + 3]) {
            Task {
                guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier?.hasPrefix("com.example.phew-practice") == true
                else { shellLog("click check: not a practice app"); exit(0) }
                UserDefaults.standard.setVolatileDomain([Hand.allowedKey: true], forName: UserDefaults.argumentDomain)
                try? await Task.sleep(for: .seconds(1))
                let job = Hand.shared.begin(watchUser: false, in: pid)
                let step = HandStep(kind: .click, pid: pid, frame: CGRect(x: x, y: y, width: 0, height: 0))
                let end = await Task.detached { Hand.shared.act(step, in: job) }.value.end
                Hand.shared.close(job)
                shellLog("click check: ended \(end.rawValue), post events allowed \(CGPreflightPostEventAccess()), accessibility \(AXIsProcessTrusted())")
                exit(0)
            }
        }
    }
    }

    /// A made-up report for the report check: a title, two headings, a list, bold, italics, code and a link.
    static let madeUpReport = """
    # Kerning sources for the poster

    A short look at where to learn **kerning** for a made-up poster, with three sources worth reading first.

    ## What I found

    - **Example Type Guide**: a free chapter on spacing capitals, with pictures of each pair.
    - *Spacing Basics*, a made-up course: about two hours, video and exercises.
    - A forum thread on kerning in headlines, mostly about `AV`, `To` and `Wa`.
    - The [Example Foundry notes](https://example.com/kerning-notes) on optical kerning.

    ## What to do next

    1. Read the guide's chapter on capitals first; it is the shortest.
    2. Try the course's second lesson on your poster title.
    3. Keep the forum thread for later questions.

    Kerning matters most in large type. In body text the font's own spacing is usually right, so leave it alone.

    The headline is set in capitals, so the pairs to check are AV, LT, TA and WA. Tighten them a little, then look at the title from a distance.

    A made-up line to make the report longer, so the card reaches its full height.
    Another made-up line, for the same reason.
    And a last one.

    Sources were read on 15 November 2026.
    """

    /// PA.6: the made-up report above opened from the menu as a click does (`openTask`), with its PDF saved in a
    /// temporary folder and then as not saved, light and dark. Logs the card's height, whether it scrolls and shows the
    /// file row, and focus. The temporary folder is deleted. No model call. Quits at the end.
    private func checkReport() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let tmp = FileManager.default.temporaryDirectory.appending(path: "phew-report-check-\(UUID().uuidString)")
        Report.copies = tmp.appending(path: "copies")  // never the user's own reports folder
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let words = "Made-up kerning sources for the poster"
        let saved = try? Report.save(Self.madeUpReport, task: words, folder: tmp)
        for (n, (dark, file)) in [(false, saved), (false, nil), (true, saved), (true, nil)].enumerated() {
            NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            tasks.debugAdd(TaskList.Item(id: 900 + n, words: words, state: .ready, report: TaskReport(markdown: Self.madeUpReport, saved: file)))
            openTask(900 + n)
            try? await Task.sleep(for: .seconds(2))
            func scrolls(_ view: NSView) -> [NSScrollView] { ((view as? NSScrollView).map { [$0] } ?? []) + view.subviews.flatMap(scrolls) }
            let scroll = card.contentView.flatMap { scrolls($0).first }
            shellLog("report check \(dark ? "dark" : "light") \(file == nil ? "unsaved" : "saved"): visible=\(card.isVisible) height=\(Int(card.frame.height)) docHeight=\(Int(scroll?.documentView?.bounds.height ?? 0)) clipHeight=\(Int(scroll?.contentView.bounds.height ?? 0)) fileRow=\(card.model.saved != nil) unsavedLine=\(card.model.text.hasSuffix("could not be saved as a file.")) key=\(card.isKeyWindow) phewFront=\(phewIsFront) frontUnchanged=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == front)")
            card.dismiss()
        }
        try? FileManager.default.removeItem(at: tmp)
        shellLog("report check done: pdf saved \(saved != nil), temp removed \(!FileManager.default.fileExists(atPath: tmp.path))")
        exit(0)
    }

    /// The menu bar menu as the system holds it, with a made-up running task and a made-up ready one, written to
    /// `<dir>/menu.txt`: each entry's title, second line, state and whether it is enabled. Nothing is clicked; the menu
    /// is never opened. Quits at the end.
    private func checkMenu(_ dir: String) async {
        tasks.debugAdd(TaskList.Item(id: 801, words: "Made-up kerning sources for the poster", progress: "Searching, 2 searches"))
        tasks.debugAdd(TaskList.Item(id: 802, words: "Made-up font licences", state: .ready, report: TaskReport(markdown: "# Made up", saved: nil)))
        try? await Task.sleep(for: .seconds(2))
        var out: [String] = []
        func dump(_ menu: NSMenu, _ indent: String) {
            menu.delegate?.menuNeedsUpdate?(menu)
            for item in menu.items {
                out.append(indent + (item.isSeparatorItem ? "-----" : "\(item.title) | \(item.subtitle ?? "") | on=\(item.state == .on) enabled=\(item.isEnabled)"))
                if let sub = item.submenu { dump(sub, indent + "    ") }
            }
        }
        let item = NSApp.windows.lazy.filter { $0.className == "NSStatusBarWindow" && $0.responds(to: NSSelectorFromString("statusItem")) }
            .compactMap { $0.value(forKey: "statusItem") as? NSStatusItem }.first { $0.menu != nil }
        if let menu = item?.menu { dump(menu, "") } else { out.append("no menu found") }
        try? out.joined(separator: "\n").write(to: URL(filePath: dir).appending(path: "menu.txt"), atomically: true, encoding: .utf8)
        exit(0)
    }

    /// PH.7 diagnosis: the windows of a made-up practice app (bundle id `com.example.phew-practice…` only, never any
    /// other app's) as Accessibility and the window server list them. Roles, sizes, title lengths and whether the title
    /// carries a test marker: never a title or a text. Quits at the end.
    private func listPracticeWindows(_ pid: pid_t) {
        guard let bundle = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier, bundle.hasPrefix("com.example.phew-practice")
        else { shellLog("list windows: not a practice app, nothing read"); exit(0) }
        func attribute(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(el, name as CFString, &value) == .success ? value : nil
        }
        let app = AXUIElementCreateApplication(pid)
        let focused = attribute(app, kAXFocusedWindowAttribute).map { $0 as! AXUIElement }
        let main = attribute(app, kAXMainWindowAttribute).map { $0 as! AXUIElement }
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        shellLog("list windows: \(windows.count) in Accessibility, focused given \(focused != nil), main given \(main != nil)")
        func describe(_ w: AXUIElement) -> String {
            let title = attribute(w, kAXTitleAttribute) as? String ?? ""
            var size = CGSize.zero
            if let v = attribute(w, kAXSizeAttribute), CFGetTypeID(v) == AXValueGetTypeID() { AXValueGetValue(v as! AXValue, .cgSize, &size) }
            let kids = (attribute(w, kAXChildrenAttribute) as? [AXUIElement] ?? []).map { attribute($0, kAXRoleAttribute) as? String ?? "?" }
            return "role \(attribute(w, kAXRoleAttribute) as? String ?? "?") subrole \(attribute(w, kAXSubroleAttribute) as? String ?? "?") title \(title.count) chars marked \(title.contains("Phew test")) size \(Int(size.width))x\(Int(size.height)) children \(kids)"
        }
        for (i, w) in windows.enumerated() {
            shellLog("list windows: #\(i) \(describe(w)) focused \(focused.map { CFEqual($0, w) } ?? false) main \(main.map { CFEqual($0, w) } ?? false)")
        }
        if let focused, !windows.contains(where: { CFEqual($0, focused) }) { shellLog("list windows: focused, not in the list: \(describe(focused))") }
        let server = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
        for info in server where info[kCGWindowOwnerPID as String] as? pid_t == pid {
            let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) } ?? .zero
            shellLog("list windows: server layer \(info[kCGWindowLayer as String] as? Int ?? -1) onScreen \(info[kCGWindowIsOnscreen as String] as? Bool ?? false) size \(Int(bounds.width))x\(Int(bounds.height)) name \((info[kCGWindowName as String] as? String)?.count ?? -1) chars")
        }
        exit(0)
    }

    /// PL.7: a task's four background adds, as `TaskList.add` makes them (a job that does not watch the user, `kind:
    /// .script` only, a sheet as a new workbook then its cells), on made-up items titled `marker` ("Phew test " and a
    /// number). After each, whether the app in front is still the one that was. No model call. Everything made is
    /// removed by id at the end, the workbook closed without saving. Logs fixed words only. Quits at the end.
    private func checkAddItems(_ marker: String) async {
        guard marker.range(of: #"^Phew test [0-9]{3,}$"#, options: .regularExpression) != nil else { return shellLog("add check: no marker") }
        UserDefaults.standard.setVolatileDomain([Hand.allowedKey: true], forName: UserDefaults.argumentDomain)
        try? await Task.sleep(for: .seconds(2))
        NSApp.deactivate()
        try? await Task.sleep(for: .seconds(1))
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))! + 3600 * 9
        let items: [(String, [HandScript])] = [
            ("note", [.note(title: marker, body: "A made-up line.")]),
            ("reminder", [.reminder(title: marker, due: nil)]),
            ("event", [.event(title: marker, start: tomorrow, end: tomorrow + 1800)]),
            ("sheet", [.workbook, .cells(top: "A1", rows: [["Phew test", "1"], ["made up", "2"]])]),
        ]
        for (name, scripts) in items {
            let job = Hand.shared.begin(watchUser: false)
            var end = HandEnd.done
            let begun = Date()
            for script in scripts where end == .done {
                let step = HandStep(kind: .script, pid: 0, script: script)
                end = await Task.detached { Hand.shared.act(step, in: job) }.value.end
            }
            Hand.shared.close(job)
            try? await Task.sleep(for: .seconds(1))  // an app that activates itself does so within a moment
            let now = NSWorkspace.shared.frontmostApplication
            shellLog("add check \(name): ended \(end.rawValue) in \(Int(Date().timeIntervalSince(begun) * 1000)) ms, frontUnchanged=\(now?.processIdentifier == front) excelFront=\(now?.bundleIdentifier == "com.microsoft.Excel") phewFront=\(phewIsFront)")
        }
        let (removed, failed) = Hand.shared.removeTestItems()
        try? await Task.sleep(for: .seconds(1))
        shellLog("add check clean-up: removed \(removed) could not remove \(failed) frontUnchanged=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == front)")
        exit(0)
    }

    /// PX.5: the real first-run panel in each state, from made-up values (the Keychain and the permissions are not
    /// looked at, and no button is pressed), then the key row alone as "API Key…" shows it. Logs states only.
    static let firstRunStates: [(String, SetupState, keyOnly: Bool, rejected: Bool)] = [
        ("fresh", SetupState(hasKey: false, accessibility: false, screen: false, screenAtLaunch: false), false, false),
        ("refused", SetupState(hasKey: true, accessibility: false, screen: false, screenAtLaunch: false,
                               askedAccessibility: true, askedScreen: true), false, false),
        ("not-active", SetupState(hasKey: true, accessibility: true, screen: true, screenAtLaunch: false), false, false),
        ("ready", SetupState(hasKey: true, accessibility: true, screen: true, screenAtLaunch: true), false, false),
        ("key-menu", SetupState(hasKey: true, accessibility: true, screen: true, screenAtLaunch: true), true, false),
        ("key-rejected", SetupState(hasKey: true, accessibility: true, screen: true, screenAtLaunch: true), true, true),
    ]

    private func checkFirstRun() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for (name, state, keyOnly, rejected) in Self.firstRunStates {
            setup.show(SetupModel(state: state, keyOnly: keyOnly, rejected: rejected, live: false))
            try? await Task.sleep(for: .milliseconds(500))
            let panel = setup.panel
            shellLog("first run check \(name): visible=\(panel?.isVisible ?? false) nonactivating=\(panel?.styleMask.contains(.nonactivatingPanel) ?? false) width=\(Int(panel?.frame.width ?? 0)) height=\(Int(panel?.frame.height ?? 0)) key=\(panel?.isKeyWindow ?? false) fieldFocused=\(panel?.firstResponder is NSTextView) missing=\(state.missing) rows=\([state.key, state.accessibilityRow, state.screenRow]) appActive=\(NSRunningApplication.current.isActive) phewFront=\(phewIsFront) frontUnchanged=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == front)")
            setup.dismiss()
        }
        shellLog("first run check done: shown=\(setup.isShown) phewFront=\(phewIsFront)")
    }

    /// PH.5 live: `--debug-act "<words>" --test-window "<marker>"` asks Phew the words, through the real ask path,
    /// about the app in front, with acting on for this process only: in memory (the argument domain), never written to
    /// the user's defaults. Real model calls and real actions. The user's own click or key stops the job.
    /// PH.10: only on a window the test itself made, holding only made-up content, whose title carries `marker` ("Phew
    /// test " and a number). Before the first model call, and before every later look, the capture is cut to that
    /// window and checked (`ContextPacket.notTestWindow`); when it is not that window, nothing is sent and the check
    /// stops. `--test-pid <pid>` names the test's app, a practice app from Tools/PracticeApp (no other app is read), looked at and acted in whatever app is in front; with
    /// `--test-note`, Notes; with neither, nothing is sent. `--test-note` first makes a made-up note titled `marker` and opens it in its own window (no
    /// sidebar, no list). At the end everything scripts made is removed by id (`Hand.removeTestItems`). Logs counts and fixed words
    /// only, never the words, a title or the card's lines. Quits at the end.
    /// With `--debug-stop-after <n>`, Stop is pressed (what the card's button calls) once n actions are ticked.
    private func checkAct(_ words: String) async {
        let arguments = CommandLine.arguments
        let marker = arguments.firstIndex(of: "--test-window").flatMap { arguments.dropFirst($0 + 1).first } ?? ""
        UserDefaults.standard.setVolatileDomain([Hand.allowedKey: true], forName: UserDefaults.argumentDomain)
        let stopAfter = arguments.firstIndex(of: "--debug-stop-after").flatMap { arguments.dropFirst($0 + 1).first }.flatMap { Int($0) }
        try? await Task.sleep(for: .seconds(2))
        NSApp.deactivate()
        let apps = ["com.apple.Notes", "com.apple.reminders", "com.apple.iCal", "com.microsoft.Excel"]
        shellLog("act check: allowed=\(Hand.shared.allowed) accessibility=\(AXIsProcessTrusted()) phewFront=\(phewIsFront) permissions=\(apps.map { Hand.permission($0) })")
        if arguments.contains("--test-note") {
            let job = Hand.shared.begin(watchUser: false)
            let made = Hand.shared.act(HandStep(kind: .script, pid: 0, script: .note(title: marker, body: "A made-up line for a Phew test.")), in: job)
            Hand.shared.close(job)
            let shown = job.made.first.map { Hand.shared.showTestNote($0.id) } ?? false
            shellLog("act check: test note \(made.end.rawValue), shown in its own window \(shown)")
            try? await Task.sleep(for: .seconds(2))
        }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        // The test's own app, looked at and acted in even while the user works in another: `--test-pid <pid>`, or Notes
        // with `--test-note`. Never the app in front, which may be the user's.
        let app = arguments.firstIndex(of: "--test-pid").flatMap { arguments.dropFirst($0 + 1).first }.flatMap { Int32($0) }
            .flatMap { NSRunningApplication(processIdentifier: $0) }
            ?? (arguments.contains("--test-note") ? NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Notes").first : nil)
        if app == nil { shellLog("act check: no test app named; nothing sent") }
        // Each look reads the app the job works in now (`pid`: the test's app, then any app the job switched to, PH.7)
        // and passes the same guard: a window there whose title carries the marker, or nothing is sent.
        let look = { (pid: pid_t) async -> ContextPacket? in
            var why = "none"
            guard let target = NSRunningApplication(processIdentifier: pid), let bundle = target.bundleIdentifier else { return nil }
            // Only a made-up practice app (Tools/PracticeApp), or Notes holding the test's own note: a wrong `--test-pid`
            // must not even read another app's window into memory.
            guard bundle.hasPrefix("com.example.phew-practice") || (bundle == "com.apple.Notes" && arguments.contains("--test-note")) else {
                shellLog("act check: look refused, not a test app; nothing read")
                return nil
            }
            // Up to three tries: while the user switches Spaces the window is briefly off screen and has no picture.
            for _ in 0..<3 {
                let packet = await Senses.capture(app: target, windowOnly: true).value
                guard let reason = packet.map({ $0.notTestWindow(marker: marker, app: bundle) }) ?? "none" else { return packet }
                why = reason
                try? await Task.sleep(for: .milliseconds(500))
            }
            shellLog("act check: look refused in the \(pid == app?.processIdentifier ? "test's app" : "app switched to"), not the test's own made-up window (\(why)); nothing sent")
            return nil
        }
        if let pid = app?.processIdentifier, let first = await look(pid) {
            capture = Task { first }
            TextCard.testWindow = (pid, look)
            let visible = NSScreen.screens.first?.visibleFrame ?? .zero
            anchor = NSPoint(x: visible.minX + 20, y: visible.minY + 320)  // out of the way, bottom left
            ask(words)
            var seen = 0, stopped: Date?
            for _ in 0..<2400 where card.isVisible && (card.answering || card.model.thinking) {
                let rows = card.model.actions
                if rows.count != seen {
                    seen = rows.count
                    // Each row as it appears: its state and the footer, never its words.
                    shellLog("act check: row \(rows.count) \(rows.last.map { "\($0.state)" } ?? "") acting=\(card.model.acting) footer stop=\(card.model.acting) closeHidden=\(card.model.acting)")
                }
                if let stopAfter, stopped == nil, rows.filter({ $0.state == .done }).count >= stopAfter, card.model.acting {
                    stopped = Date()
                    card.handJob?.stop()  // what the footer's Stop button calls
                    shellLog("act check: Stop pressed after \(stopAfter) actions")
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            shellLog("act check done: lines=\(card.model.text.split(separator: "\n").count) problem=\(card.model.problem != nil) note=\(card.model.note != nil) steps=\(card.model.steps.count) frontUnchanged=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == front) phewFront=\(phewIsFront) $\(CallLog.spentUSD)")
        }
        for (script, end, made) in Hand.shared.ranHere { shellLog("act check script: \(Self.shape(script, marker: marker)) ended \(end.rawValue) made \(made != nil)") }
        let (removed, failed) = Hand.shared.removeTestItems()
        shellLog("act check clean-up: removed \(removed) could not remove \(failed)")
        try? await Task.sleep(for: .seconds(2))
        card.dismiss()
        exit(0)
    }

    /// A script as numbers and fixed words: whether its title carries the test's marker, line and cell counts, and
    /// dates as days from today and a clock time. Never a title or a text.
    private static func shape(_ script: HandScript, marker: String) -> String {
        func when(_ date: Date?) -> String {
            guard let date else { return "none" }
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date)).day ?? 0
            return "+\(days)d \(date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))"
        }
        switch script {
        case let .note(title, body): return "note marked=\(title.hasPrefix(marker)) lines=\(body.isEmpty ? 0 : body.components(separatedBy: .newlines).count)"
        case let .append(text): return "append lines=\(text.components(separatedBy: .newlines).count)"
        case let .reminder(title, due):
            return "reminder marked=\(title.hasPrefix(marker)) due=\(due.map { $0.hour == nil ? "date only, " + when(Calendar.current.date(from: $0)) : when(Calendar.current.date(from: $0)) } ?? "none")"
        case let .event(title, start, end): return "event marked=\(title.hasPrefix(marker)) start=\(when(start)) minutes=\(Int(end.timeIntervalSince(start) / 60))"
        case .workbook: return "workbook"
        case let .cells(top, rows): return "cells top=\(top) rows=\(rows.count) columns=\(rows.map(\.count).max() ?? 0)"
        }
    }

    /// P5.10 without the save window: a made-up Map in memory, exported through the real Export panel and its model,
    /// with sensitive facts off then on. `save` writes to a file in the app's temporary folder (never the real Map,
    /// never a user folder), which is read back, compared, and deleted. Logs counts and focus only, never a word of
    /// the Map or a path. The system folder window itself needs a hand test. No model calls.
    private func checkExport() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard let store = try? await MadeUpMap.build() else { return shellLog("export check: made-up map failed") }
        let stub = ExportStubBrain(store: store)
        let file = FileManager.default.temporaryDirectory.appending(path: "phew-export-check-\(UUID().uuidString).md")
        for sensitive in [false, true] {
            let exporter = MapExporter(brain: stub) { text in
                try text.write(to: file, atomically: true, encoding: .utf8)
                return file.lastPathComponent
            }
            menuPanel.show(title: "Export the Map", ExportView(exporter: exporter))
            exporter.includeSensitive = sensitive
            await exporter.export()
            let written = stub.lastText ?? ""
            let read = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            let lines = read.split(separator: "\n")
            let panel = menuPanel.panel
            shellLog("export check sensitive=\(sensitive): asked=\(stub.asked) roundTrip=\(!read.isEmpty && read == written) bytes=\(read.utf8.count) lines=\(lines.count) sections=\(lines.filter { $0.hasPrefix("## ") }.count) facts=\(lines.filter { $0.hasPrefix("- ") }.count) sensitiveMarks=\(read.components(separatedBy: "Sensitive.").count - 1) forgottenAbsent=\(!read.contains(MadeUpMap.forgottenName)) sensitiveNamePresent=\(read.contains(MadeUpMap.sensitiveName)) saved=\(exporter.status != nil) panel visible=\(panel?.isVisible ?? false) key=\(panel?.isKeyWindow ?? false) nonactivating=\(panel?.styleMask.contains(.nonactivatingPanel) ?? false) phewFront=\(phewIsFront) frontUnchanged=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == front)")
        }
        try? FileManager.default.removeItem(at: file)
        menuPanel.close()
        shellLog("export check done: file deleted=\(!FileManager.default.fileExists(atPath: file.path)) panel closed=\(menuPanel.panel == nil) phewFront=\(phewIsFront)")
    }

    /// Opens Recently deleted on a stub with two made-up forgets, runs Restore and Delete now as their buttons do,
    /// then opens About and licences. Logs counts and focus only, never a label. No model calls, no real Map.
    private func checkDeleted() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let stub = DeletedStubBrain()
        let list = DeletedList(brain: stub)
        menuPanel.show(title: "Recently deleted", DeletedView(list: list))
        await until { list.loaded }
        func state(_ moment: String) {
            let panel = menuPanel.panel
            let frontUnchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == front
            shellLog("deleted check \(moment): visible=\(panel?.isVisible ?? false) key=\(panel?.isKeyWindow ?? false) keyOnlyIfNeeded=\(panel?.becomesKeyOnlyIfNeeded ?? false) nonactivating=\(panel?.styleMask.contains(.nonactivatingPanel) ?? false) appActive=\(NSRunningApplication.current.isActive) phewFront=\(phewIsFront) frontUnchanged=\(frontUnchanged) items=\(list.items.count) daysLeft=\(list.items.map { DeletedList.daysLeftText($0.daysLeft) }) problem=\(list.problem != nil)")
        }
        state("opened")
        await list.restore(1)
        state("after Restore on item 1")
        await list.deleteNow(2)
        state("after Delete now on item 2")
        await list.deleteNow(99)  // an id the stub does not know: the brain says no
        state("after Delete now on an unknown id")
        shellLog("deleted check: stub calls \(stub.calls)")
        menuPanel.show(title: "About Phew", AboutView())
        try? await Task.sleep(for: .seconds(1))
        let about = menuPanel.panel
        shellLog("deleted check about: visible=\(about?.isVisible ?? false) key=\(about?.isKeyWindow ?? false) phewFront=\(phewIsFront) noticeLines=\(AboutView.sqlcipherNotice.split(separator: "\n").count)")
        menuPanel.close()
        shellLog("deleted check done: panel closed=\(menuPanel.panel == nil) phewFront=\(phewIsFront) frontUnchanged=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == front)")
    }

    /// Opens the panel twice (the second open is the usual case in real use), then closes it as Escape does.
    private func checkPanel() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()  // real use: another app is active when the shortcut fires
        shellLog("self-check before open: appActive=\(NSRunningApplication.current.isActive) phewFront=\(phewIsFront) windows=\(NSApp.windows.map(\.className))")
        for _ in 0..<2 {
            panel.open { question in shellLog("self-check: panel closed, question \(question == nil ? "none" : "given")") }
            try? await Task.sleep(for: .seconds(1))
            let responder = panel.firstResponder.map { String(describing: type(of: $0)) } ?? "none"
            // The edit actions the panel sends for Command+A, C, V, X reach the field through the responder chain.
            let editor = panel.firstResponder as? NSTextView
            editor?.insertText("check", replacementRange: NSRange(location: NSNotFound, length: 0))
            let routed = NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: panel)
            shellLog("self-check: key=\(panel.isKeyWindow) appActive=\(NSRunningApplication.current.isActive) phewFront=\(phewIsFront) firstResponder=\(responder) selectAll routed=\(routed) selected=\(editor?.selectedRange().length ?? -1) of \(editor?.string.count ?? -1)")
            NSApp.sendAction(#selector(NSResponder.cancelOperation(_:)), to: nil, from: nil)
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Plays a fake Brain through the real ask path: an answer with steps, an error sentence, and a missing key
    /// (the card closes and the key window opens). Closes everything at the end.
    private func checkCard() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let realBrain = brain
        for failure in [nil, BrainError.overloaded, .noKey] {
            let name = failure.map { "\($0)" } ?? "answer"
            brain = FakeBrain(failure: failure)
            capture = Task<ContextPacket?, Never> { nil }
            anchor = NSEvent.mouseLocation
            ask("")
            shellLog("card check \(name): appeared=\(card.isVisible) key=\(card.isKeyWindow) thinking=\(card.model.thinking)")
            try? await Task.sleep(for: .seconds(2))
            let frontUnchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == front
            shellLog("card check \(name): visible=\(card.isVisible) pieces=\(card.model.pieces) steps=\(card.model.steps.count) thinking=\(card.model.thinking) problem=\(card.model.problem ?? "none") keyWindow=\(setup.isShown) frontUnchanged=\(frontUnchanged) phewFront=\(phewIsFront) \(cardFrames)")
            card.dismiss()
            setup.dismiss()
        }
        brain = realBrain
        let frontUnchanged = NSWorkspace.shared.frontmostApplication?.processIdentifier == front
        shellLog("card check done: card visible=\(card.isVisible) keyWindow=\(setup.isShown) frontUnchanged=\(frontUnchanged)")
    }

    /// Plays a made-up four-step guide through the real card and overlay: a made-up element, a screenshot point,
    /// a step without a target, the element again. First it follows: it calls `userActed`, the action monitor's own
    /// entry point (no event is made), and each look captures whatever app is front and asks the fake Brain, which
    /// moves one step per look, until the last look finds every step done. Then it starts again, picks a step line
    /// and closes the card with a look waiting, as Escape, the close control and the shortcut do. Last, a look that
    /// fails: overloaded keeps the guide without following, no key closes it and opens the key window. No model calls.
    /// In those four the screen watch runs but counts every look as a change. In the last, "watch", it judges for real:
    /// Phew's own windows are left out of it, so on a still screen an action makes no look; with a short idle limit
    /// the watch stops by itself; an action starts it again and, with nothing to compare with, the look goes ahead.
    /// "hit" and "hit-back" (PS.3) press and release on the targets as the monitor reports them: a drag does not move
    /// on, a direct hit moves on at once with the looking motion, the look confirms ("hit") or steps back
    /// ("hit-back"), a hit inside a point's ring moves on, a typing step and the last step wait for the look.
    /// The action monitor is real: the user's own clicks, keys and scrolls during the check also make looks.
    private func checkGuide() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let realBrain = brain
        let watch = ScreenWatch.shared
        let main = NSScreen.screens[0].frame
        let display = CGDisplayBounds(CGMainDisplayID())  // top-left origin, as Senses measures
        var packet = ContextPacket(appName: "Made Up", bundleID: "com.example.madeup", windowTitle: "Made up",
                                   visibleText: "", cursor: nil)
        packet.pointables = [Pointable(id: "e1", role: "AXButton", label: "Made up",
                                       frame: CGRect(x: display.midX - 160, y: display.midY - 60, width: 120, height: 28))]
        packet.screenshotFrame = display
        let targets: [StepTarget?] = [.element("e1"), .point(x: Int(display.width / 2) + 60, y: Int(display.height / 2) + 40), nil, .element("e1")]
        for (ending, failure) in [("follow", nil), ("cancel", nil), ("overloaded", BrainError.overloaded), ("noKey", .noKey), ("watch", nil),
                                  ("hit", nil), ("hit-back", nil)] {
            watch.seesEveryChange = ending != "watch"
            ScreenWatch.idleLimit = ending == "watch" ? 6 : 120
            // PS.3: steps 1, 2 and 4 need only a click, step 3 typing. In "hit-back" every look finds the step not done.
            brain = FakeBrain(targets: targets, lookFailure: failure, clicks: ending.hasPrefix("hit") ? [true, true, false, true] : [],
                              confirms: ending != "hit-back")
            capture = Task<ContextPacket?, Never> { packet }
            anchor = NSPoint(x: main.midX - 600, y: main.midY + 160)  // a made-up cursor, left of the targets
            ask("")
            try? await Task.sleep(for: .seconds(2))  // the fake answer streams, then step 1 starts
            weak let overlay = card.overlay
            shellLog("guide check \(ending): menu bar icon found=\(NSApp.windows.contains { $0.className == "NSStatusBarWindow" }) following=\(card.actionMonitor != nil)")
            try? await Task.sleep(for: .seconds(3))  // step 1's glide and ring
            func state(_ moment: String) {
                shellLog("guide check \(ending) \(moment): step=\(card.model.current + 1) looks=\(card.rule.looks) lookPending=\(card.lookPending) looking=\(overlay?.isLooking ?? false) cardVisible=\(card.isVisible) overlay ignoresMouse=\(overlay?.ignoresMouseEvents ?? false) visible=\(overlay?.isVisible ?? false) key=\(overlay?.isKeyWindow ?? false) canBecomeKey=\(overlay?.canBecomeKey ?? true) cardKey=\(card.isKeyWindow) phewFront=\(phewIsFront) appActive=\(NSRunningApplication.current.isActive) watch=\(watch.running)")
            }
            state("step 1")
            if ending == "follow" {
                // Does Accessibility's hit test take the clear overlay for content? The card's centre is the control.
                shellLog("guide check follow: hit test lands on Phew, inside the card=\(Self.hitIsPhew(NSPoint(x: card.frame.midX, y: card.frame.midY))) on the overlay away from the card=\(Self.hitIsPhew(NSPoint(x: main.midX + 300, y: main.midY - 200)))")
                try? await Task.sleep(for: .seconds(3))
                state("after 3 s without an action")
                card.userActed()
                await until { !self.card.lookPending }
                state("after one action")
                card.userActed()
                await until { self.card.rule.inFlight }
                card.userActed(); card.userActed()  // two more while that look runs
                shellLog("guide check follow: two actions during look \(card.rule.looks), in flight=\(card.rule.inFlight)")
                await until { !self.card.lookPending }
                try? await Task.sleep(for: .seconds(3))  // room for any extra look
                state("after an action and two during its look, then 3 s")
                card.userActed()  // the last look finds every step done
                await until { !self.card.lookPending }
            } else if ending == "watch" {
                card.userActed()
                await until { !self.card.lookPending }
                state("after an action on a still screen")
                await until { !watch.running }
                state("after \(Int(ScreenWatch.idleLimit)) s without an action")
                card.userActed()
                await until { !self.card.lookPending }
                state("after an action that started the watch again")
                card.dismiss()
            } else if ending.hasPrefix("hit") {
                // A press and release as the action monitor sees them (no event is made), `drag` points apart.
                func hit(_ step: Int, dx: CGFloat = 0, drag: CGFloat = 0) {
                    guard let rect = card.targets[step] else { return shellLog("guide check \(ending): step \(step + 1) has no target") }
                    let at = NSPoint(x: rect.midX + dx, y: rect.midY)
                    card.rule.pressed(at: at)
                    card.directHit(at: NSPoint(x: at.x + drag, y: at.y))
                }
                hit(0, drag: 20)
                state("after a drag on step 1's target")
                let t0 = Date()
                hit(0)
                shellLog("guide check \(ending): direct hit on step 1, card on step \(card.model.current + 1) after \(Int(Date().timeIntervalSince(t0) * 1000)) ms, looking=\(overlay?.isLooking ?? false)")
                card.userActed()  // the release is also an action: the look that confirms
                await until { !self.card.lookPending }
                state("after the look that confirms")
                if ending == "hit" {
                    hit(1, dx: 15)  // inside the 22-point ring around step 2's point
                    state("after a direct hit inside step 2's ring")
                    hit(2)  // step 3 needs typing: a click into it waits for the look
                    state("after a click on step 3, a typing step")
                    card.jump(to: 3)
                    hit(3)  // the last step always waits for the look
                    state("after a click on the last step's target")
                    card.userActed()
                    await until { !self.card.lookPending }
                    state("after the look on the last step")
                }
                card.dismiss()
            } else if failure != nil {
                card.userActed()
                await until { !self.card.lookPending }
                state("after a look that failed")
                card.jump(to: 1)  // step lines still work
                shellLog("guide check \(ending): card visible=\(card.isVisible) following=\(card.actionMonitor != nil) step after picking line 2=\(card.model.current + 1) keyWindow=\(setup.isShown)")
                card.dismiss()
                setup.dismiss()
            } else {
                card.jump(to: 2)  // what a click on step line 3 calls
                card.userActed()
                try? await Task.sleep(for: .seconds(1))  // the glide, with a look still waiting
                state("after picking step line 3 and an action")
                card.dismiss()  // what Escape, the close control and the shortcut call
            }
            try? await Task.sleep(for: .seconds(1))  // the glide home
            card.userActed()  // after the end nothing may follow
            let left = NSApp.windows.filter { $0 is PointerOverlay }.count
            shellLog("guide check \(ending) end: card visible=\(card.isVisible) overlay released=\(overlay == nil) overlay windows left=\(left) phewFront=\(phewIsFront) cardKey=\(card.isKeyWindow) monitor removed=\(card.actionMonitor == nil) lookPending=\(card.lookPending) looks=\(card.rule.looks) watch running=\(watch.running) frames held=\(watch.holdsFrames)")
        }
        watch.seesEveryChange = false
        ScreenWatch.idleLimit = 120
        brain = realBrain
    }

    /// PS.11, the conversation card, through a fake Brain and the real card: the closed card, the thread opened as a
    /// click does, a reply typed with a new line (Shift and Return) and sent with Return, a reply typed and sent while
    /// he answers (it waits, then goes), and the shortcut on the empty, focused field (it closes). Each reply takes a
    /// real capture of the front app, in memory only, which the fake Brain ignores. Logs counts and focus only, never
    /// the typed words. No model calls.
    private func checkThread() async {
        try? await Task.sleep(for: .seconds(1))
        NSApp.deactivate()
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let realBrain = brain
        brain = FakeBrain()
        capture = Task<ContextPacket?, Never> { nil }
        anchor = NSEvent.mouseLocation
        ask("")
        await until { !self.card.answering }
        func state(_ moment: String) {
            let editor = card.firstResponder as? NSTextView
            shellLog("thread check \(moment): visible=\(card.isVisible) open=\(card.model.open) key=\(card.isKeyWindow) replyFocused=\(editor?.isEditable ?? false) size=\(Int(card.frame.width))x\(Int(card.frame.height)) insideVisibleFrame=\(NSScreen.screens.contains { $0.visibleFrame.contains(self.card.frame) }) earlier=\(card.model.history.count) thinking=\(card.model.thinking) answering=\(card.answering) queued=\(card.model.queued) draftLines=\(card.model.draft.isEmpty ? 0 : card.model.draft.split(separator: "\n").count) appActive=\(NSRunningApplication.current.isActive) phewFront=\(phewIsFront) frontUnchanged=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == front)")
        }
        func type(_ text: String) {
            (card.firstResponder as? NSTextView)?.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
        func pressReturn(shift: Bool = false) {
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: shift ? .shift : [], timestamp: 0,
                                               windowNumber: card.windowNumber, context: nil, characters: "\r",
                                               charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36) else { return }
            card.sendEvent(event)
        }
        state("closed card")
        card.openThread()  // what a click on the closed card calls
        try? await Task.sleep(for: .seconds(1))
        state("opened")
        type("Made-up first line")
        pressReturn(shift: true)
        type("made-up second line")
        try? await Task.sleep(for: .milliseconds(200))
        state("typed two lines")
        pressReturn()
        try? await Task.sleep(for: .milliseconds(300))
        state("reply sent")
        type("Made-up reply typed while he answers")
        pressReturn()
        state("reply sent while answering")
        await until { self.card.model.history.count == 2 && !self.card.answering }
        try? await Task.sleep(for: .milliseconds(300))
        state("waiting reply answered")
        card.focusReply()
        card.shortcutPressed()  // the field is focused and empty: the conversation closes
        try? await Task.sleep(for: .milliseconds(300))
        state("after the shortcut on the empty field")
        brain = realBrain
    }

    /// Polls `done` every 50 ms, for at most 10 s.
    private func until(_ done: () -> Bool) async {
        for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(50)) }
    }

    /// Whether Accessibility's hit test at `point` (AppKit coordinates) lands on one of Phew's windows. Reads only
    /// the owner's process id.
    private static func hitIsPhew(_ point: NSPoint) -> String {
        var hit: AXUIElement?
        let y = (NSScreen.screens.first?.frame.height ?? 0) - point.y
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(y), &hit) == .success,
              let hit else { return "no element" }
        var owner: pid_t = 0
        AXUIElementGetPid(hit, &owner)
        return "\(owner == getpid())"
    }

    /// The card's frame as the window server has it (top-left origin), and whether it lies inside the screen.
    private var cardFrames: String {
        let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        guard card.isVisible,
              let info = windows.first(where: { $0[kCGWindowNumber as String] as? Int == card.windowNumber }),
              let bounds = info[kCGWindowBounds as String] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return "windowServer=none" }
        var ids = [CGDirectDisplayID](repeating: 0, count: 16), count: UInt32 = 0
        CGGetActiveDisplayList(16, &ids, &count)
        let inDisplay = ids.prefix(Int(count)).contains { CGDisplayBounds($0).contains(rect) }
        let inVisibleFrame = NSScreen.screens.contains { $0.visibleFrame.contains(card.frame) }
        return "windowServer=\(rect) insideDisplay=\(inDisplay) insideVisibleFrame=\(inVisibleFrame)"
    }
}

/// A stand-in Brain for the card and guide checks: a guide answer in pieces with three steps (pointing at
/// `targets`), or `failure` after two pieces.
struct FakeBrain: Brain {
    var failure: BrainError?
    var targets: [StepTarget?] = [nil, nil, nil]
    /// Thrown by `progress`, as a look that fails.
    var lookFailure: BrainError?
    /// Which steps need only a click (PS.3); missing ones do not.
    var clicks: [Bool] = []
    /// False: every look finds the step it is asked about not done.
    var confirms = true

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let pieces = ["This is a fake answer ", "from the card check. ", "It arrives ", "in small pieces, ",
                              "like a real one, ", "then three steps follow."]
                continuation.yield(.route(.guide))
                for piece in pieces.prefix(failure == nil ? pieces.count : 2) {
                    try? await Task.sleep(for: .milliseconds(200))
                    continuation.yield(.text(piece))
                }
                if let failure { return continuation.finish(throwing: failure) }
                continuation.yield(.steps(targets.enumerated().map {
                    GuideStep(instruction: "Fake step \($0.offset + 1).", target: $0.element, click: clicks.indices.contains($0.offset) && clicks[$0.offset])
                }))
                continuation.yield(.done)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// One step further per call, pointing where that step pointed, after half a second, as a short model call.
    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress {
        try await Task.sleep(for: .milliseconds(500))
        if let lookFailure { throw lookFailure }
        let next = min(max(current + (confirms ? 1 : 0), 0), steps.count)
        return GuideProgress(current: next, target: next < steps.count ? steps[next].target : nil)
    }
}

/// A stand-in Brain for Recently deleted: two made-up forgets. Restore and Delete now remove the item and record
/// the call; an unknown id returns false.
final class DeletedStubBrain: Brain, @unchecked Sendable {
    private let lock = NSLock()
    private var items = [DeletedItem(id: 1, label: "Made-up person: Ada Example", daysLeft: 29),
                         DeletedItem(id: 2, label: "Made-up note about a test project", daysLeft: 1)]
    private var log: [String] = []
    var calls: [String] { lock.withLock { log } }

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        FakeBrain().answer(question, packet: packet)
    }
    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress {
        try await FakeBrain().progress(steps: steps, current: current, packet: packet)
    }
    func recentlyDeleted() async -> [DeletedItem] { lock.withLock { items } }
    func restore(_ id: Int64) async -> Bool { remove(id, "restore") }
    func deleteNow(_ id: Int64) async -> Bool { remove(id, "deleteNow") }

    private func remove(_ id: Int64, _ call: String) -> Bool {
        lock.withLock {
            log.append("\(call) \(id)")
            guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
            items.remove(at: index)
            return true
        }
    }
}

/// A stand-in Brain for the export check: exports a Map it was given (nil: no Map) and records what it was asked.
final class ExportStubBrain: Brain, @unchecked Sendable {
    private let lock = NSLock()
    private let store: MapStore?
    private var calls: [Bool] = []
    private var text: String?
    /// The `includeSensitive` of each call, in order.
    var asked: [Bool] { lock.withLock { calls } }
    var lastText: String? { lock.withLock { text } }

    init(store: MapStore?) { self.store = store }

    func answer(_ question: String, packet: ContextPacket?) -> AsyncThrowingStream<BrainEvent, Error> {
        FakeBrain().answer(question, packet: packet)
    }
    func progress(steps: [GuideStep], current: Int, packet: ContextPacket?) async throws -> GuideProgress {
        try await FakeBrain().progress(steps: steps, current: current, packet: packet)
    }
    func exportMap(includeSensitive: Bool) async -> String? {
        lock.withLock { calls.append(includeSensitive) }
        let out = await store?.export(includeSensitive: includeSensitive)
        lock.withLock { text = out }
        return out
    }
}

/// A made-up Map in memory, for the export check and its tests: a Project with a Task (and one old due date), a
/// Person, a Tool, a Topic, Notes, links, past questions, one sensitive Person with a sensitive Note and past
/// question, and one forgotten Person with a Note.
enum MadeUpMap {
    static let sensitiveName = "Bruno Hiddenname"
    static let forgottenName = "Carla Forgotten"

    static func build() async throws -> MapStore {
        let store = try MapStore()
        let me = try await store.count("SELECT id FROM all_nodes WHERE class = 'Me'")
        func node(_ mapClass: MapClass, _ name: String = "", kind: String = "", text: String = "", properties: String = "{}",
                  origin: Origin = .told, sensitive: Bool = false) async throws -> Int64 {
            try await store.add(MapNode(mapClass: mapClass, kind: kind, name: name, text: text, properties: properties, origin: origin,
                                        sensitive: sensitive, validFrom: "2026-11-10T09:00:00Z", created: "2026-11-10T09:00:00Z",
                                        updated: "2026-11-10T09:00:00Z"))
        }
        func link(_ from: Int64, _ link: MapLink, _ to: Int64, origin: Origin = .told, strength: Double? = nil) async throws {
            try await store.add(MapEdge(from: from, to: to, link: link, strength: strength, origin: origin, validFrom: "2026-11-10T09:00:00Z",
                                        created: "2026-11-10T09:00:00Z", updated: "2026-11-10T09:00:00Z"))
        }
        let project = try await node(.project, "Example rebrand", kind: "client job")
        let task = try await node(.task, "Example poster", kind: "assignment",
                                  properties: MapStore.properties(["due": ("2026-11-20", Origin.told)]))
        try await store.add(MapNode(mapClass: .task, kind: "assignment", name: "Example poster",
                                    properties: MapStore.properties(["due": ("2026-11-18", Origin.told)]), origin: .told,
                                    validFrom: "2026-11-09T09:00:00Z", validTo: "2026-11-10T09:00:00Z", supersededBy: task,
                                    created: "2026-11-09T09:00:00Z", updated: "2026-11-09T09:00:00Z"))
        let ada = try await node(.person, "Ada Example", kind: "client", origin: .observed)
        let tool = try await node(.tool, "Sketchpad", kind: "app", origin: .observed)
        let topic = try await node(.topic, "Kerning", kind: "concept", origin: .observed)
        let decision = try await node(.note, kind: "decision", text: "Client approved logo v3", origin: .observed)
        let preference = try await node(.note, kind: "preference", text: "I prefer short answers")
        try await link(task, .partOf, project)
        try await link(project, .involves, ada, origin: .observed)
        try await link(project, .uses, tool, origin: .observed)
        try await link(task, .requires, topic, origin: .observed)
        try await link(me, .understands, topic, origin: .observed, strength: 0.3)
        try await link(decision, .about, project, origin: .observed)
        try await link(preference, .about, me)
        try await store.add(MapEvent(time: "2026-11-11T10:00:00Z", app: "Sketchpad", kind: .ask,
                                     summary: "Asked how to set kerning on the poster.", project: project, mentions: [project, task, topic]))

        let bruno = try await node(.person, sensitiveName, kind: "friend", sensitive: true)
        let matter = try await node(.note, kind: "reference", text: "Bruno has a made-up private matter", sensitive: true)
        try await link(matter, .about, bruno)
        try await store.add(MapEvent(time: "2026-11-12T10:00:00Z", kind: .tell, summary: "Told about Bruno's made-up matter.",
                                     mentions: [bruno, matter]))

        let carla = try await node(.person, forgottenName, kind: "teammate")
        let gone = try await node(.note, kind: "reference", text: "Carla Forgotten likes made-up tea")
        try await link(gone, .about, carla)
        try await store.forget([carla])
        return store
    }
}
#endif
