import AppKit
import Security
import SwiftUI

/// What first run knows (15.5 G), as plain values so its rules can be tested without the system.
struct SetupState: Equatable {
    var hasKey: Bool
    var accessibility: Bool
    /// Screen Recording as the system says now, and as it was when Phew started: a grant made since then takes
    /// effect only when Phew reopens.
    var screen: Bool
    var screenAtLaunch: Bool
    /// Allow was pressed before, in any run: macOS shows its prompt only once, so the button opens System Settings.
    var askedAccessibility = false
    var askedScreen = false
    /// "Open System Settings" was pressed for Screen Recording in this run. The system may go on saying "not
    /// granted" until Phew reopens, so the row offers the reopen rather than sending the user to Settings again.
    var screenSentToSettings = false
    /// The Microphone (P6.1): nil until the user holds the shortcut to talk with it missing. Voice is optional, so
    /// its row never shows at launch.
    var voice: VoicePermissions?

    /// The one control of a row. `done`: the row shows its tick and no control.
    enum Control: Equatable { case done, keyField, allow, openSettings, reopen }

    var key: Control { hasKey ? .done : .keyField }
    var accessibilityRow: Control { accessibility ? .done : askedAccessibility ? .openSettings : .allow }
    var screenRow: Control {
        if screen { return screenAtLaunch ? .done : .reopen }
        if screenSentToSettings { return .reopen }
        return askedScreen ? .openSettings : .allow
    }

    /// First run shows at launch only when this is true; once false, the rows fold into "Phew is ready".
    var missing: Bool { [key, accessibilityRow, screenRow].contains { $0 != .done } }

    /// The voice row; nil while it is not shown. macOS asks once, then System Settings.
    var microphoneRow: Control? { voice.map { Self.row($0.microphone) } }
    /// The voice row shows and is not done: once false, it folds into "Phew can hear you".
    var voiceMissing: Bool { microphoneRow != nil && microphoneRow != .done }

    private static func row(_ state: VoicePermissions.State) -> Control {
        switch state {
        case .granted: .done
        case .notAsked: .allow
        case .refused: .openSettings
        }
    }
}

extension KeyStore {
    /// Whether a key is saved, without reading it: no data is asked for, so the secret stays in the Keychain.
    var exists: Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service, kSecAttrAccount as String: account]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}

/// First run as one panel (15.5 G): the Claude API key, Accessibility and Screen Recording, each with its state and
/// one control, then the shortcut. It replaces the old permissions and key panels. Shown at launch only when something
/// is missing; "API Key…" in the menu and an answer that needed a key show the key row alone.
/// Non-activating like the other panels. Only while the key field shows does it take the keyboard, so Command+V
/// pastes at once (as the key panel always did); the front app stays the active app.
@MainActor
final class SetupPanel {
    static let askedAccessibilityKey = "setupAskedAccessibility"
    static let askedScreenKey = "setupAskedScreenRecording"
    /// Given to the new copy when "Reopen Phew" restarts it, so the flow ends on the shortcut even with nothing missing.
    static let reopenedFlag = "--setup-reopened"

    private(set) var panel: NSPanel?
    private var observer: Any?
    /// Read when Phew starts (this object is made at launch).
    private let screenAtLaunch = CGPreflightScreenCaptureAccess()
    /// Called when Accessibility turns on while the panel is open, so the shortcut works without a relaunch.
    var onAccessibilityGranted: () -> Void = {}

    var isShown: Bool { panel?.isVisible ?? false }
    private(set) var model: SetupModel?
    /// The Microphone now, and its system prompt (P6.1). The app delegate gives the real ones; by default granted,
    /// so the voice row never shows.
    var voicePermissions: () -> VoicePermissions = { .granted }
    var askMicrophone: () -> Void = {}

    /// The system's values now. No prompt: these only look.
    func read() -> SetupState {
        let defaults = UserDefaults.standard
        return SetupState(hasKey: KeyStore().exists, accessibility: AXIsProcessTrusted(),
                          screen: CGPreflightScreenCaptureAccess(), screenAtLaunch: screenAtLaunch,
                          askedAccessibility: defaults.bool(forKey: Self.askedAccessibilityKey),
                          askedScreen: defaults.bool(forKey: Self.askedScreenKey))
    }

    /// At launch: the whole flow when something is missing, or its last state when "Reopen Phew" started this copy.
    func showAtLaunch() {
        let state = read()
        shellLog("setup at launch: missing \(state.missing), reopened \(CommandLine.arguments.contains(Self.reopenedFlag))")
        guard state.missing || CommandLine.arguments.contains(Self.reopenedFlag) else { return }
        show(SetupModel(state: state, keyOnly: false, live: true))
    }

    /// "API Key…" in the menu, or an answer that needed a key: the key row alone. `rejected`: Claude refused the saved key.
    func showKey(rejected: Bool = false) {
        show(SetupModel(state: read(), keyOnly: true, rejected: rejected, live: true))
    }

    /// A hold to talk found a voice permission missing: the two voice rows alone.
    func showVoice() {
        var state = read()
        state.voice = voicePermissions()
        show(SetupModel(state: state, keyOnly: false, voice: true, live: true))
    }

    /// `live` false: made-up values for the debug check; nothing is read, asked or written.
    func show(_ model: SetupModel) {
        dismiss()
        model.onClose = { [weak self] in self?.dismiss() }
        model.readVoice = { [weak self] in self?.voicePermissions() ?? .granted }
        model.askMicrophone = { [weak self] in self?.askMicrophone() }
        model.onAccessibilityGranted = { [weak self] in self?.onAccessibilityGranted() }
        let panel = EditPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = model.keyOnly ? "API Key" : ""
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating  // stays above the browser while the user copies the key
        panel.contentView = NSHostingView(rootView: SetupView(model: model))
        panel.setContentSize(panel.contentView?.fittingSize ?? NSSize(width: Design.Size.consentWidth, height: 300))
        panel.center()
        panel.orderFrontRegardless()
        if model.showsKeyField {
            panel.makeKey()
            panel.contentView?.layoutSubtreeIfNeeded()
            panel.makeFirstResponder(panel.contentView?.firstTextField)  // so Command+V pastes at once
        }
        // The close button: drop the view, its typed key and its recheck timer with it.
        observer = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.forget() }
        }
        self.panel = panel
        self.model = model
        shellLog("setup shown: key only \(model.keyOnly), voice \(model.voice), missing \(model.state.missing), rows \([model.state.key, model.state.accessibilityRow, model.state.screenRow]), visible \(panel.isVisible), nonactivating \(panel.styleMask.contains(.nonactivatingPanel)), key \(panel.isKeyWindow), field focused \(panel.firstResponder is NSTextView), app active \(NSRunningApplication.current.isActive), phew front \(phewIsFront)")
    }

    func dismiss() {
        let panel = self.panel
        forget()
        panel?.close()
    }

    private func forget() {
        observer.map(NotificationCenter.default.removeObserver)
        observer = nil
        panel?.contentView = nil
        panel = nil
        model = nil
    }
}

/// The panel's state and its buttons' work.
@MainActor
final class SetupModel: ObservableObject {
    @Published var state: SetupState
    /// The why-line of the key row is replaced by this sentence.
    @Published var keyProblem: String?
    let keyOnly: Bool
    /// The voice row alone (P6.1).
    let voice: Bool
    let live: Bool
    var onClose: () -> Void = {}
    var onAccessibilityGranted: () -> Void = {}
    var readVoice: () -> VoicePermissions = { .granted }
    var askMicrophone: () -> Void = {}

    init(state: SetupState, keyOnly: Bool, voice: Bool = false, rejected: Bool = false, live: Bool) {
        self.state = state
        self.keyOnly = keyOnly
        self.voice = voice
        self.live = live
        keyProblem = rejected ? "Claude did not accept the saved API key. Paste a new one." : nil
    }

    var showsKeyField: Bool { !voice && (keyOnly || state.key == .keyField) }
    var ready: Bool { voice ? !state.voiceMissing : !keyOnly && !state.missing }

    /// Every second while open: Accessibility and Screen Recording as the system says now.
    func recheck() {
        guard live else { return }
        let trusted = AXIsProcessTrusted()
        if trusted && !state.accessibility { onAccessibilityGranted() }
        state.accessibility = trusted
        state.screen = CGPreflightScreenCaptureAccess()
        if voice { state.voice = readVoice() }
    }

    func microphonePressed() {
        guard live else { return }
        if state.microphoneRow == .openSettings { return openSettings("Privacy_Microphone") }
        askMicrophone()
        shellLog("setup: microphone prompt asked")
    }

    func keySaved() {
        shellLog("key saved")
        if keyOnly { return onClose() }
        keyProblem = nil
        state.hasKey = true
    }

    func accessibilityPressed() {
        guard live else { return }
        if state.accessibilityRow == .openSettings { return openSettings("Privacy_Accessibility") }
        UserDefaults.standard.set(true, forKey: SetupPanel.askedAccessibilityKey)
        state.askedAccessibility = true
        let prompt = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(prompt)
        shellLog("setup: accessibility prompt asked")
    }

    func screenPressed() {
        guard live else { return }
        switch state.screenRow {
        case .openSettings:
            state.screenSentToSettings = true
            openSettings("Privacy_ScreenCapture")
        case .reopen:
            reopen()
        default:
            UserDefaults.standard.set(true, forKey: SetupPanel.askedScreenKey)
            state.askedScreen = true
            _ = CGRequestScreenCaptureAccess()
            shellLog("setup: screen recording prompt asked")
        }
    }

    /// The right page of System Settings, because macOS will not show its prompt twice. The user's own click opens it.
    private func openSettings(_ pane: String) {
        let opened = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)").map { NSWorkspace.shared.open($0) } ?? false
        shellLog("setup: system settings opened \(opened)")
    }

    /// A new copy of Phew, in the background, then this one quits. The new one ends the flow on the shortcut.
    private func reopen() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false
        configuration.arguments = [SetupPanel.reopenedFlag]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                shellLog("setup: reopen started \(error == nil)")
                if error == nil { NSApp.terminate(nil) }
            }
        }
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel
    private let recheck = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            if model.voice {
                if model.ready { voiceReady } else { voiceRows }
            } else if model.ready {
                ready
            } else {
                if !model.keyOnly {
                    VStack(alignment: .leading, spacing: Design.Space.s4) {
                        Text("Set up Phew").font(Design.Text.title)
                        Text("Three things, once.").font(Design.Text.small).foregroundStyle(Design.Ink.secondary)
                    }
                    .padding(.bottom, Design.Space.s4)
                }
                KeyRow(model: model)
                if !model.keyOnly {
                    divider
                    SetupRow(control: model.state.accessibilityRow, title: "Accessibility",
                             why: "So he can read the window you are in.", action: model.accessibilityPressed)
                    divider
                    SetupRow(control: model.state.screenRow, title: "Screen Recording",
                             why: model.state.screenRow == .reopen ? "Takes effect when Phew reopens."
                                                                    : "So he can see what the text leaves out.",
                             action: model.screenPressed)
                }
            }
        }
        .foregroundStyle(Design.Ink.primary)
        .padding(Design.Space.s24)
        .frame(width: Design.Size.consentWidth, alignment: .leading)
        .background(Color(nsColor: .windowBackgroundColor))  // `panel`
        .onReceive(recheck) { _ in model.recheck() }
    }

    private var divider: some View { Design.Ink.hairline.frame(height: Design.Size.hairline) }

    /// P6.1: the one row talking needs, shown at the first hold with it missing.
    private var voiceRows: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            VStack(alignment: .leading, spacing: Design.Space.s4) {
                Text("Talk to Phew").font(Design.Text.title)
                Text("One thing, once.").font(Design.Text.small).foregroundStyle(Design.Ink.secondary)
            }
            .padding(.bottom, Design.Space.s4)
            SetupRow(control: model.state.microphoneRow ?? .done, title: "Microphone",
                     why: "So he can hear you while you hold the shortcut. Your words become text on this Mac.",
                     action: model.microphonePressed)
        }
    }

    private var voiceReady: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            HStack(spacing: Design.Space.s8) {
                TickMark()
                Text("Phew can hear you").font(Design.Text.title)
            }
            VStack(alignment: .leading, spacing: Design.Space.s4) {
                HStack(spacing: Design.Space.s4) {
                    Text("Hold")
                    Keycap(key: "right ⌥")
                    Text("and")
                    Keycap(key: "right ⌘")
                    Text("and speak.")
                }
                Text("Let go and your words are sent.")
            }
            .font(Design.Text.body)
            .accessibilityElement(children: .combine)
            HStack {
                Spacer()
                Button("Done") { model.onClose() }.buttonStyle(MainButton())
            }
        }
    }

    /// The rows folded into one last state: how to call him. The panel waits for the user to close it.
    private var ready: some View {
        VStack(alignment: .leading, spacing: Design.Space.s12) {
            HStack(spacing: Design.Space.s8) {
                TickMark()
                Text("Phew is ready").font(Design.Text.title)
            }
            VStack(alignment: .leading, spacing: Design.Space.s4) {
                HStack(spacing: Design.Space.s4) {
                    Text("Press")
                    Keycap(key: "right ⌥")
                    Text("and")
                    Keycap(key: "right ⌘")
                    Text("together,")
                }
                Text("in any app. He is in the menu bar.")
            }
            .font(Design.Text.body)
            .accessibilityElement(children: .combine)
            HStack {
                Spacer()
                Button("Done") { model.onClose() }.buttonStyle(MainButton())
            }
        }
    }
}

/// One row of first run: a circle that becomes a tick when done, the heading in `strong`, one control on the right,
/// and under the heading the line saying why.
private struct SetupRow: View {
    let control: SetupState.Control
    let title: String
    let why: String
    let action: () -> Void

    var body: some View {
        StepShape(done: control == .done, title: title) {
            switch control {
            case .allow: Button("Allow", action: action).buttonStyle(QuietButton())
            case .openSettings: Button("Open System Settings", action: action).buttonStyle(QuietButton())
            case .reopen: Button("Reopen Phew", action: action).buttonStyle(QuietButton())
            case .done, .keyField: EmptyView()
            }
        } below: {
            HelpLine(text: why)
        }
    }
}

/// The key row: the secure field, Paste and Save. The typed key lives only in this view and goes to the Keychain.
private struct KeyRow: View {
    @ObservedObject var model: SetupModel
    @State private var key = ""
    @State private var saving = false

    var body: some View {
        StepShape(done: !model.showsKeyField, title: "Claude API key") {
            EmptyView()
        } below: {
            if model.showsKeyField {
                HStack(spacing: Design.Space.s8) {
                    SecureField("API key", text: $key)
                        .textFieldStyle(.plain)
                        .font(Design.Text.body)
                        .padding(.horizontal, Design.Space.s8)
                        .frame(minHeight: Design.Size.control)
                        .background(Design.Ink.fill, in: RoundedRectangle(cornerRadius: Design.Radius.bubble))
                        .onSubmit(save)
                    // Always works, even if keyboard shortcuts do not reach the field.
                    Button("Paste") { key = NSPasteboard.general.string(forType: .string) ?? key }.buttonStyle(QuietButton())
                    Button("Save", action: save)
                        .buttonStyle(MainButton())
                        .keyboardShortcut(.defaultAction)
                        .disabled(saving || key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            HelpLine(text: "Stored only in this Mac's Keychain.", problem: model.keyProblem)
        }
    }

    private func save() {
        guard model.live, !saving, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        saving = true
        let key = key
        Task {
            // Off the main thread: the Keychain call can block.
            let result = await Task.detached { Result { try KeyStore().save(key) } }.value
            saving = false
            switch result {
            case .success:
                self.key = ""
                model.keySaved()
            case .failure(let error):
                let status = (error as? KeyStore.Failure)?.status ?? 0
                shellLog("key not saved, keychain status \(status)")
                model.keyProblem = "The Keychain did not save the key (error \(status)). Please try again."
            }
        }
    }
}

/// The shape every first-run row shares.
private struct StepShape<Trailing: View, Below: View>: View {
    let done: Bool
    let title: String
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var below: Below

    var body: some View {
        HStack(alignment: .top, spacing: Design.Space.s12) {
            Group {
                if done { TickMark() } else { Image(systemName: "circle").foregroundStyle(Design.Ink.tertiary) }
            }
            .font(.system(size: 13))
            .frame(width: Design.Space.s16, height: Design.Size.control)
            VStack(alignment: .leading, spacing: Design.Space.s4) {
                HStack {
                    Text(title).font(Design.Text.strong)
                    Spacer(minLength: Design.Space.s8)
                    trailing
                }
                .frame(minHeight: Design.Size.control)
                below
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title), \(done ? "done" : "to do")")
    }
}
