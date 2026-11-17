import Foundation
import NaturalLanguage

/// What Phew never acts on, whatever the words (docs/13-hand.md 13.5). Decided by this code only: never by the model,
/// the screen or the web. The app list and the word lists live here and nowhere else.
enum NeverList {
    /// Apps he never acts in, by bundle id: System Settings, Keychain Access and password managers, terminals,
    /// code editors and script runners (a click there can run commands).
    static let apps: Set<String> = passwordApps.union(terminals).union([
        "com.apple.systempreferences",
        "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf", "dev.zed.Zed", "com.sublimetext.4", "com.panic.Nova", "com.barebones.bbedit",
        "com.apple.ScriptEditor2", "com.apple.Automator",
    ])
    /// Keychain Access and the password managers: also left out of a whole-display picture (`ScreenCapture.hides`).
    static let passwordApps: Set<String> = [
        "com.apple.keychainaccess", "com.apple.Passwords",
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop", "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal", "in.sinew.Enpass-Desktop", "com.nordpass.macos.NordPass",
        "org.keepassxc.keepassxc", "com.hicknhacksoftware.MacPass", "com.markmcguill.strongbox", "com.markmcguill.strongbox.mac",
    ]
    /// Terminals: also left out of a whole-display picture.
    static let terminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty", "io.alacritty", "com.github.wez.wezterm",
    ]
    /// Whole families: System Settings' panes, JetBrains editors.
    static let appPrefixes = ["com.apple.preference.", "com.apple.settings.", "com.jetbrains."]

    /// Words in a control's name or its menu path, never its window's title (R3, 17 November), and in a script's
    /// titles (F3, password and paying only). English and Italian; folded to lower case without accents before
    /// matching, whole words only.
    static let words: [(HandEnd, [String])] = [
        (.password, ["password", "passcode", "passkey", "security code", "cvv", "cvc",
                     "codice di sicurezza", "codice segreto", "codice di accesso"]),
        (.paying, ["pay", "payment", "buy", "purchase", "checkout", "check out", "place order",
                   "subscribe", "card number", "credit card", "billing",
                   "paga", "pagare", "pagamento", "acquista", "acquisto", "compra", "abbonati",
                   "abbonamento", "numero della carta", "numero carta", "carta di credito", "fatturazione",
                   "effettua l'ordine", "procedi all'ordine",
                   // Order and money buttons (R7). Never bare "order" or "ordina": "Order by date", "Ordina per nome".
                   "place your order", "confirm order", "confirm your order", "complete order", "complete your order",
                   "submit order", "order now", "donate", "donation", "send money", "transfer money",
                   "conferma ordine", "conferma l'ordine", "completa ordine", "completa l'ordine", "invia ordine",
                   "invia l'ordine", "ordina ora", "ordina adesso", "ordina subito", "dona ora", "donazione",
                   "fai una donazione", "bonifico", "invia denaro", "invia soldi", "trasferisci denaro"]),
        (.signIn, ["sign in", "signin", "log in", "login", "sign up", "create account", "account settings",
                   "accedi", "effettua l'accesso", "registrati", "iscriviti", "crea account",
                   "impostazioni account", "impostazioni dell'account"]),
    ]

    /// Before anything of the app is read: the off-limits apps. Nil when Phew may act in it.
    static func refusal(bundleID: String?, pid: pid_t, ownPID: pid_t, secureInput: Bool, list: NeverReadList) -> HandEnd? {
        if pid == ownPID { return .ownApp }
        if secureInput { return .secureInput }
        if list.contains(bundleID) { return .neverReadApp }
        // An app with no bundle id cannot be told apart from a terminal: careful side.
        guard let bundleID else { return .neverActApp }
        if apps.contains(bundleID) || appPrefixes.contains(where: bundleID.hasPrefix) { return .neverActApp }
        return nil
    }

    /// The target itself: a secure field (target or focus) or a never word in any of `texts`. Nil when allowed.
    static func refusal(role: String, subrole: String, focusedSecure: Bool, texts: [String]) -> HandEnd? {
        if focusedSecure || SecretsFilter.isSecure(role: role, subrole: subrole) { return .secureField }
        return word(in: texts, among: [.password, .paying, .signIn])
    }

    /// F3: the titles a script makes or names, against the password words only. Not the paying or sign-in words: a
    /// reminder "Pay the rent" or "Log in to the portal" is a reminder, it pays and signs in nothing (17 November:
    /// with the paying words, "Buy milk" was refused).
    static func refusal(titles: [String]) -> HandEnd? { word(in: titles, among: [.password]) }

    /// The first never word of `reasons` in any of `texts`, in the order of `words`.
    private static func word(in texts: [String], among reasons: Set<HandEnd>) -> HandEnd? {
        let folded = texts.map(fold)
        let text = " " + folded.joined(separator: " ") + " "
        for (reason, list) in words where reasons.contains(reason) && list.contains(where: { text.contains(" \($0) ") }) { return reason }
        if reasons.contains(.paying), folded.contains(where: payingNames.contains) { return .paying }
        return nil
    }

    /// Paying as a control's whole name only (R7): a button named "Order" orders, "Order by date" sorts.
    static let payingNames: Set<String> = ["order", "ordina", "dona", "transfer", "trasferisci"]

    /// Where the code cannot judge by words: a control with no name, or names in a language with no word list.
    /// Such a step still runs, with a mark (13.5).
    static func careful(name: String, texts: [String]) -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        guard let (language, p) = guessLanguage(([name] + texts).joined(separator: ". ")), p >= 0.6 else { return false }
        return ![.english, .italian].contains(language)
    }

    /// The system's guess of a text's language and how sure it is. Tests replace it, so they do not depend on the
    /// language model of the Mac they run on (R45).
    nonisolated(unsafe) static var guessLanguage: (String) -> (NLLanguage, Double)? = { text in
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.languageHypotheses(withMaximum: 1).first.map { ($0.key, $0.value) }
    }

    /// The "cannot be undone or leaves your Mac" class (13.5): words in a control's name or menu path. English and
    /// Italian, matched as `words` are.
    static let finalWords = [
        "send", "submit", "post", "publish", "share", "invite", "forward", "delete", "remove", "erase", "clear", "empty",
        "discard", "replace", "overwrite", "revert", "don't save", "quit", "sign out", "log out", "print", "export",
        "invia", "inoltra", "pubblica", "condividi", "invita", "elimina", "cancella", "rimuovi", "svuota", "scarta",
        "sostituisci", "sovrascrivi", "ripristina", "non salvare", "esci", "disconnetti", "stampa", "esporta",
    ]

    /// Shortcuts never sent, whatever the words (NA.5): quit, log out, lock, force quit, empty the Trash, and those
    /// that take the user out of the app (Spotlight, the app switcher, hiding, Spaces, the Dock, screenshots). A key
    /// with fn or the globe key cannot even be named (`HandChord.parse`).
    static let neverSend: Set<HandChord> = Set([
        "cmd+q", "cmd+option+q",                                        // quit
        "cmd+shift+q", "cmd+option+shift+q",                            // log out
        "control+cmd+q",                                                // lock the screen
        "cmd+option+escape", "cmd+option+shift+escape",                 // force quit
        "cmd+shift+delete", "cmd+option+shift+delete",                  // empty the Trash
        "cmd+space", "cmd+option+space", "control+space", "control+option+space",  // Spotlight, input sources
        "cmd+tab", "cmd+shift+tab", "cmd+h", "cmd+option+h", "cmd+option+d",       // other apps, hide, the Dock
        "control+up", "control+down", "control+left", "control+right",  // Mission Control and Spaces
        "cmd+shift+3", "cmd+shift+4", "cmd+shift+5", "control+cmd+shift+3", "control+cmd+shift+4",  // screenshots
    ].compactMap(HandChord.parse))

    /// Shortcuts in the "cannot be undone or leaves your Mac" class (NA.5), with the rules in `final`:
    ///
    /// | Keys                          | Why                                                   |
    /// |-------------------------------|-------------------------------------------------------|
    /// | cmd (+ others) + delete or    | moves to the Trash, deletes a message, a line, a word |
    /// | forward delete                |                                                       |
    /// | cmd + return (+ shift/option) | sends in chat and mail apps, submits a form           |
    /// | cmd + shift + D               | Send in Mail                                          |
    /// | return alone                  | while a sheet or dialog is open: its default button   |
    /// | return or space alone         | on a focused control named with a `finalWords` word   |
    /// | typed text with a new line    | Return in a web form                                  |
    ///
    /// Not in the class: cmd + S (it saves), cmd + Z, plain delete (one character, undone with cmd + Z).
    static let finalChords: Set<HandChord> = Set(["cmd+return", "cmd+shift+return", "cmd+option+return", "cmd+shift+d"]
        .compactMap(HandChord.parse))

    /// Whether `step` is in the "cannot be undone or leaves your Mac" class. Decided by this code only, never by the
    /// model. In a job the user watches it still runs, tagged on the card; an agent's waits for one confirm.
    /// `names`: the control's name and menu path, as read (for keys, the focused control's); `replaces`: a `set` over
    /// text already there; `facts`: what was read of the item a script changes; `agent`: a research agent's job, where
    /// any change or delete counts: a background task has no card, so no Undo can reach the old value; `isDefault`:
    /// the control is the default button of a sheet or dialog (F4); `dialogOpen`: one is open in the app now.
    static func final(_ step: HandStep, names: [String]? = nil, replaces: Bool = false, facts: HandFacts = HandFacts(),
                      agent: Bool = false, isDefault: Bool = false, dialogOpen: Bool = false) -> Bool {
        let names = names ?? [step.name] + step.menuPath
        let text = " " + names.map(fold).joined(separator: " ") + " "
        let worded = finalWords.contains { text.contains(" \($0) ") }
        switch step.kind {
        // A scroll changes nothing; a right click only opens a menu, whose item is a step of its own.
        case .front, .scroll, .rightClick: return false
        case .set: return replaces
        case .pick, .drag: return worded
        case .press, .click, .doubleClick:
            // F4: a dialog's default button, and a control with no name, which no word can judge. A click at a bare
            // point (no role: a canvas) is not on a control.
            return worded || isDefault || (!step.role.isEmpty && names.allSatisfy { fold($0).isEmpty })
        case .keys:
            guard let chord = step.chord else { return step.text.contains(where: \.isNewline) }
            if finalChords.contains(chord) { return true }
            if chord.modifiers.contains(.cmd), ["delete", "forwarddelete"].contains(chord.key) { return true }
            guard chord.modifiers.isEmpty else { return false }
            return chord.key == "return" && dialogOpen || ["return", "space"].contains(chord.key) && worded
        case .script:
            switch step.script {
            // Invitations or updates go out to guests; a repeat cannot be put back whole.
            case .delete?, .rename?, .noteBody?, .complete?, .move?: return agent || facts.guests || facts.repeats
            // R6: lines added to a note already there change it: an agent's waits, as every change.
            case let .append(_, title)?: return agent && !title.isEmpty
            // NA.12: an agent has no Undo, so cells it writes over wait for the confirm like every other change.
            case .changeCells?: return agent
            // Adds, cells written over with what they held kept, and Undo itself.
            default: return false
            }
        }
    }

    /// Lower case, no accents, curly apostrophes straight, every other sign a space.
    static func fold(_ s: String) -> String {
        let plain = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).replacingOccurrences(of: "’", with: "'")
        let spaced = String(plain.map { $0.isLetter || $0.isNumber || $0 == "'" ? $0 : " " })
        return spaced.split(separator: " ").joined(separator: " ")
    }
}
