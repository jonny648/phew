import Foundation

/// Phew's own ceilings on what the user's key spends: requests a minute, requests a day and dollars a day. Checked
/// before each new request from the user (a question, a reply, a task, an import sort), never inside one already
/// started: a guide's looks and a job's actions keep their own brakes, and their cost counts in the day's sum anyway,
/// since it comes from calls.log. Ceilings live in UserDefaults, so they change without a rebuild; 0 means no limit.
/// Reads only numbers: the times of started requests, and `ts` and `usd` from calls.log.
struct Limits: @unchecked Sendable {  // UserDefaults is thread-safe
    static let usdKey = "limitUSDPerDay", requestsKey = "limitRequestsPerDay", minuteKey = "limitRequestsPerMinute"
    /// The start times of recent requests, seconds since 1970: today's, and the last minute's.
    static let startsKey = "limitStarts"
    static let usdDefault = 3.0, requestsDefault = 400, minuteDefault = 30

    var defaults: UserDefaults = .standard
    var now: @Sendable () -> Date = { Date() }
    var calendar = Calendar.current
    var log: @Sendable () -> [CallLog.Line] = { CallLog.lines() }

    var usdPerDay: Double { defaults.object(forKey: Self.usdKey) as? Double ?? Self.usdDefault }
    var requestsPerDay: Int { defaults.object(forKey: Self.requestsKey) as? Int ?? Self.requestsDefault }
    var requestsPerMinute: Int { defaults.object(forKey: Self.minuteKey) as? Int ?? Self.minuteDefault }

    private static let lock = NSLock()

    /// Before a new request: throws `BrainError.limited` when a ceiling is hit, and nothing is sent; otherwise counts
    /// it. Also chooses the cache life for the calls that follow (D1).
    func start() throws {
        let lines = log(), now = now()
        CallLog.hourCache = CacheLife.hour(lines.filter { $0.tier == Tier.main.rawValue }.compactMap(\.date))
        let spent = CallLog.spent(lines, on: now, calendar: calendar)
        try Self.lock.withLock {
            let starts = recent(now)
            if let limit = Self.refusal(starts: starts, spent: spent, now: now, calendar: calendar, perMinute: requestsPerMinute,
                                        perDay: requestsPerDay, usdPerDay: usdPerDay) {
                shellLog("limits: request refused, \(limit.word)")
                throw BrainError.limited(limit)
            }
            defaults.set((starts + [now]).map(\.timeIntervalSince1970), forKey: Self.startsKey)
        }
    }

    /// Dollars today's ceiling still allows, for a task's own cost limit; infinity with no ceiling.
    func dayLeft() -> Double {
        usdPerDay > 0 ? usdPerDay - CallLog.spent(log(), on: now(), calendar: calendar) : .infinity
    }

    /// Today so far, for the Limits panel.
    func today() -> LimitsToday {
        let now = now()
        return LimitsToday(spentUSD: CallLog.spent(log(), on: now, calendar: calendar),
                           requests: recent(now).filter { calendar.isDate($0, inSameDayAs: now) }.count,
                           usdPerDay: usdPerDay, requestsPerDay: requestsPerDay)
    }

    /// The stored start times still needed: today's, and those of the last minute (which may be yesterday's).
    private func recent(_ now: Date) -> [Date] {
        ((defaults.array(forKey: Self.startsKey) as? [Double]) ?? []).map(Date.init(timeIntervalSince1970:))
            .filter { calendar.isDate($0, inSameDayAs: now) || abs(now.timeIntervalSince($0)) < 60 }
    }

    /// The ceiling a new request would pass, or nil. `starts`: earlier started requests; `spent`: today's dollars.
    static func refusal(starts: [Date], spent: Double, now: Date, calendar: Calendar, perMinute: Int, perDay: Int,
                        usdPerDay: Double) -> BrainError.Limit? {
        if perMinute > 0, starts.filter({ abs(now.timeIntervalSince($0)) < 60 }).count >= perMinute { return .minute }
        if usdPerDay > 0, spent >= usdPerDay { return .dayUSD(usdPerDay) }
        if perDay > 0, starts.filter({ calendar.isDate($0, inSameDayAs: now) }).count >= perDay { return .dayRequests(perDay) }
        return nil
    }
}

/// Today's spend and requests against the ceilings (0: no limit). Numbers only.
struct LimitsToday: Sendable, Equatable {
    var spentUSD = 0.0
    var requests = 0
    var usdPerDay = 0.0
    var requestsPerDay = 0
}

/// D1: how long the fixed part of a request stays in the cache, from the times of this Mac's recent main-model calls.
/// Gaps under 5 minutes find the cache warm either way. A gap of 5 to 60 minutes costs a 5-minute write (1.25x the
/// input price) on the short cache and only a read on the hour cache; a gap over an hour costs a write on both, 2x on
/// the hour cache. So the hour cache is cheaper when the 5-to-60 gaps outnumber 0.625 of the longer ones
/// (1.25a + 1.25b > 2b). The last 20 pauses (gaps over 5 minutes) decide, and at least 2 must fall in the window.
enum CacheLife {
    static func hour(_ times: [Date]) -> Bool {
        let sorted = times.sorted()
        let pauses = zip(sorted, sorted.dropFirst()).map { $1.timeIntervalSince($0) }.filter { $0 > 300 }.suffix(20)
        let inWindow = pauses.filter { $0 <= 3600 }.count
        return inWindow >= 2 && Double(inWindow) > 0.625 * Double(pauses.count - inWindow)
    }
}
