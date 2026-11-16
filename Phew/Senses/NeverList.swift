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
    ]
    /// Terminals: also left out of a whole-display picture.
    static let terminals: Set<String> = [
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty", "io.alacritty", "com.github.wez.wezterm",
    ]
    /// Whole families: System Settings' panes, JetBrains editors.
    static let appPrefixes = ["com.apple.preference.", "com.apple.settings.", "com.jetbrains."]

    /// Words in a control's name, its menu path or its window title. English and Italian; folded to lower case
    /// without accents before matching, whole words only.
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
        let folded = texts.map(fold)
        let text = " " + folded.joined(separator: " ") + " "
        for (reason, list) in words where list.contains(where: { text.contains(" \($0) ") }) { return reason }
        if folded.contains(where: payingNames.contains) { return .paying }
        return nil
    }

    /// Paying as a control's whole name only (R7): a button named "Order" orders, "Order by date" sorts.
    static let payingNames: Set<String> = ["order", "ordina", "dona", "transfer", "trasferisci"]

    /// Where the code cannot judge by words: a control with no name, or names in a language with no word list.
    /// Such a step still runs, with a mark (13.5).
    static func careful(name: String, texts: [String]) -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(([name] + texts).joined(separator: ". "))
        guard let (language, p) = recognizer.languageHypotheses(withMaximum: 1).first, p >= 0.6 else { return false }
        return ![.english, .italian].contains(language)
    }

    /// The "cannot be undone or leaves your Mac" class (13.5): words in a control's name or menu path. English and
    /// Italian, matched as `words` are.
    static let finalWords = [
        "send", "submit", "post", "publish", "share", "invite", "forward", "delete", "remove", "erase", "clear", "empty",
        "discard", "replace", "overwrite", "revert", "don't save", "quit", "sign out", "log out", "print", "export",
        "invia", "inoltra", "pubblica", "condividi", "invita", "elimina", "cancella", "rimuovi", "svuota", "scarta",
        "sostituisci", "sovrascrivi", "ripristina", "non salvare", "esci", "disconnetti", "stampa", "esporta",
    ]

    /// Whether `step` is in the "cannot be undone or leaves your Mac" class. Decided by this code only, never by the
    /// model. In a job the user watches it still runs, tagged on the card; an agent's waits for one confirm.
    /// `names`: the control's name and menu path, as read; `replaces`: a `set` over text already there; `facts`: what
    /// was read of the item a script changes; `agent`: a research agent's job, where any change or delete counts:
    /// a background task has no card, so no Undo can reach the old value.
    static func final(_ step: HandStep, names: [String]? = nil, replaces: Bool = false, facts: HandFacts = HandFacts(),
                      agent: Bool = false) -> Bool {
        switch step.kind {
        case .front: return false
        case .set: return replaces
        case .press, .pick, .click:
            let text = " " + (names ?? [step.name] + step.menuPath).map(fold).joined(separator: " ") + " "
            return finalWords.contains { text.contains(" \($0) ") }
        case .script:
            switch step.script {
            // Invitations or updates go out to guests; a repeat cannot be put back whole.
            case .delete?, .rename?, .noteBody?, .complete?, .move?: return agent || facts.guests || facts.repeats
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
