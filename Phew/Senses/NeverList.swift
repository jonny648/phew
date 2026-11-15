import Foundation
import NaturalLanguage

/// What Phew never acts on, whatever the words (docs/13-hand.md 13.5). Decided by this code only: never by the model,
/// the screen or the web. The app list and the word lists live here and nowhere else.
enum NeverList {
    /// Apps he never acts in, by bundle id: System Settings, Keychain Access and password managers, terminals,
    /// code editors and script runners (a click there can run commands).
    static let apps: Set<String> = [
        "com.apple.systempreferences", "com.apple.keychainaccess", "com.apple.Passwords",
        "com.1password.1password", "com.agilebits.onepassword7", "com.bitwarden.desktop", "com.lastpass.LastPass",
        "com.dashlane.dashlanephonefinal", "in.sinew.Enpass-Desktop", "com.nordpass.macos.NordPass",
        "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty", "io.alacritty", "com.github.wez.wezterm",
        "com.apple.dt.Xcode", "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf", "dev.zed.Zed", "com.sublimetext.4", "com.panic.Nova", "com.barebones.bbedit",
        "com.apple.ScriptEditor2", "com.apple.Automator",
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
                   "effettua l'ordine", "procedi all'ordine"]),
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
        let text = " " + texts.map(fold).joined(separator: " ") + " "
        for (reason, list) in words where list.contains(where: { text.contains(" \($0) ") }) { return reason }
        return nil
    }

    /// Where the code cannot judge by words: a control with no name, or names in a language with no word list.
    /// Such a step still runs, with a mark (13.5).
    static func careful(name: String, texts: [String]) -> Bool {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return true }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(([name] + texts).joined(separator: ". "))
        guard let (language, p) = recognizer.languageHypotheses(withMaximum: 1).first, p >= 0.6 else { return false }
        return ![.english, .italian].contains(language)
    }

    /// Lower case, no accents, curly apostrophes straight, every other sign a space.
    static func fold(_ s: String) -> String {
        let plain = s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).replacingOccurrences(of: "’", with: "'")
        let spaced = String(plain.map { $0.isLetter || $0.isNumber || $0 == "'" ? $0 : " " })
        return spaced.split(separator: " ").joined(separator: " ")
    }
}
