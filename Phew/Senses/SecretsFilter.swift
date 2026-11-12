import Foundation

/// Keeps secrets out of everything Senses hands on: password fields are never read,
/// and keys and card numbers are replaced with a short marker.
enum SecretsFilter {
    static let keyMarker = "[key removed]"
    static let cardMarker = "[card removed]"

    /// Password fields. Checked before any value is read, so their content never reaches Phew.
    static func isSecure(role: String, subrole: String) -> Bool {
        role == "AXSecureTextField" || subrole == "AXSecureTextField"
    }

    /// Removes API keys, tokens and card numbers. Ordinary numbers, dates and phone numbers stay.
    static func clean(_ text: String) -> String {
        let noKeys = keys.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: (text as NSString).length), withTemplate: keyMarker)
        let out = NSMutableString(string: noKeys)
        for match in cards.matches(in: noKeys, range: NSRange(location: 0, length: out.length)).reversed()
        where luhn(out.substring(with: match.range)) {
            out.replaceCharacters(in: match.range, with: cardMarker)
        }
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
