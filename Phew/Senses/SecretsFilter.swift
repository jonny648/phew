import Foundation

/// Keeps secrets out of everything Senses hands on: password fields are never read,
/// and keys, card numbers and passwords written in plain text are replaced with a short marker.
enum SecretsFilter {
    static let keyMarker = "[key removed]"
    static let cardMarker = "[card removed]"
    static let secretMarker = "[secret removed]"

    /// Password fields. Checked before any value is read, so their content never reaches Phew.
    static func isSecure(role: String, subrole: String) -> Bool {
        role == "AXSecureTextField" || subrole == "AXSecureTextField"
    }

    /// `read` called only for a field that is not a password field: what every reader of a value goes through (R19).
    static func unlessSecure(role: String, subrole: String, _ read: () -> String?) -> String? {
        isSecure(role: role, subrole: subrole) ? nil : read()
    }

    /// Removes API keys, tokens, card numbers and the value after a password word. Ordinary numbers, dates and phone numbers stay.
    static func clean(_ text: String) -> String {
        let noKeys = keys.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: keyMarker)
        let out = NSMutableString(string: noKeys)
        for match in cards.matches(in: noKeys, range: NSRange(location: 0, length: out.length)).reversed()
        where luhn(out.substring(with: match.range)) {
            out.replaceCharacters(in: match.range, with: cardMarker)
        }
        // Last, so a key or card after the word is already one marker; a marker is never taken as the value.
        passwords.replaceMatches(in: out, range: NSRange(location: 0, length: out.length), withTemplate: "$1 \(secretMarker)")
        return out as String
    }

    // One alternative per kind of key: known prefixes, bearer tokens, JWTs, PEM private keys.
    private static let keys = try! NSRegularExpression(pattern: [
        #"-----BEGIN[A-Z ]*PRIVATE KEY-----[\s\S]*?(?:-----END[A-Z ]*PRIVATE KEY-----|\z)"#,
        #"\bsk-[A-Za-z0-9_-]{20,}"#,                       // Anthropic sk-ant-, OpenAI sk-, sk-proj-
        #"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})"#,
        #"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b"#,                 // AWS access key id
        #"\bxox[abprs]-[A-Za-z0-9-]{10,}"#,                // Slack
        #"\bAIza[0-9A-Za-z_-]{35}"#,                       // Google API key
        #"\b[rs]k_(?:live|test)_[A-Za-z0-9]{16,}"#,        // Stripe
        #"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"#,  // JWT
        #"(?i:\bbearer)\s+[A-Za-z0-9._~+/-]{20,}=*"#,
    ].joined(separator: "|"))

    // A password word, then its value, which is replaced:
    // - after "is", "was", "è", ":", "=" or " - " within a few words ("the wifi password is gatto", "PIN = 4421");
    // - right after the word when the value holds a digit or a symbol ("the password Brisk-Otter-77", "pin 4421");
    // - right after "pw" or "pwd", always ("pw tango").
    // The word may be glued to others by "_" or "-", as settings files and JSON write it ("DB_PASSWORD=", "API_KEY:",
    // "access_token"), but not followed by more of a name ("input_tokens", "PASSWORD_HASH_ROUNDS") (R24). Bare "secret"
    // counts only before ":" or "=" ("client_secret=…"), so "the secret garden" stays.
    // So "password manager", "Forgot password?" and "reset the PIN code" stay. Bare Italian "codice" is not a word
    // here ("il codice è pronto" is about code); "parola chiave" is not either (it means keyword).
    // shortcut: "The password is incorrect" loses "incorrect"; a word list of harmless values would fix it if it matters.
    private static let passwords = try! NSRegularExpression(pattern:
        #"(?i)(?<![A-Za-z0-9])(password|passwort|passcode|passphrase|pwd?|pin|otp|parola d['’]ordine|codice (?:pin|segreto|d['’]accesso|di accesso)|chiave api|api[ _-]?(?:key|secret)|secret[ _-]?access[ _-]?key|secret[ _-]?key|client[ _-]?secret|private[ _-]?key|access[ _-]?token|auth[ _-]?token|token|secret(?=\s*[:=]))(?![A-Za-z0-9_])"#
        + #"(?:[^.?!\n]{0,30}?(?:\bis\b|\bwas\b|\bè\b|:|=|\s[-–]\s)\s*(?!\[(?:key|card|secret) removed\])\S+"#
        + #"|\s+["'“]?(?=[^\s"'”]*[0-9_!@#$%^&*+=-])(?!\[(?:key|card|secret) removed\])[^\s"'”]{3,}"#
        + #"|(?<=pw|pwd)\s+["'“]?(?!\[(?:key|card|secret) removed\])[^\s"'”]+)"#)

    // 13 to 19 digits, single spaces or dashes allowed between them. First digit 2 to 6: the card
    // networks' ranges, so numbers starting 0 or 1 (international phone prefixes, timestamps) stay.
    // shortcut: a card glued to another digit group ("4111 … 1111 2") is not caught, upgrade if seen.
    private static let cards = try! NSRegularExpression(pattern: #"\b[2-6](?:[ -]?[0-9]){12,18}\b"#)

    private static func luhn(_ number: String) -> Bool {
        let digits = number.compactMap(\.wholeNumberValue)
        guard (13...19).contains(digits.count) else { return false }
        let sum = digits.reversed().enumerated().reduce(0) { sum, item in
            let doubled = item.element * 2
            return sum + (item.offset % 2 == 0 ? item.element : (doubled > 9 ? doubled - 9 : doubled))
        }
        return sum % 10 == 0
    }
}
