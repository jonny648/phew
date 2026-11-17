import Foundation

/// Phase N4's hidden switches: UserDefaults keys only, with no interface. Read at each use, so a change needs no
/// rebuild. `batch` is on unless set to false; the three of N4.7 are off until a live check at the owner's word.
struct CostSwitches: @unchecked Sendable {  // UserDefaults is thread-safe
    /// N4.5: a job's call may plan up to five actions. False: one action per call, as before.
    static let batchKey = "costBatchActions"
    /// N4.7 (a): an explanation sends a half-size picture when the window gave at least `halfPictureText` characters.
    static let halfPictureKey = "costHalfPicture"
    /// N4.7 (b): the small model follows a guide first; the main model looks only when the small one is unsure.
    static let smallFollowerKey = "costSmallFollower"
    /// N4.7 (c): plain explanations (not about Phew, no earlier screen, no reading more) on the small model.
    static let smallExplainKey = "costSmallExplain"

    var defaults: UserDefaults = .standard

    var batch: Bool { defaults.object(forKey: Self.batchKey) as? Bool ?? true }
    var halfPicture: Bool { defaults.bool(forKey: Self.halfPictureKey) }
    var smallFollower: Bool { defaults.bool(forKey: Self.smallFollowerKey) }
    var smallExplain: Bool { defaults.bool(forKey: Self.smallExplainKey) }
}
