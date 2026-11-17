import Foundation

/// Phew's own ceilings on what the user's key spends: requests a minute, requests a day and dollars a day. Checked
/// before each new request from the user (a question, a reply, a task, an import sort), never inside one already
/// started: a guide's looks and a job's actions keep their own brakes, and their cost counts in the day's sum anyway,
/// since it comes from calls.log. Ceilings live in UserDefaults, so they change without a rebuild; 0 dollars means no
/// limit. The two request counts always have one, kept within `minuteBounds` and `dayBounds` whatever is stored (NA.13).
/// Reads only numbers: the times of started requests, and `ts` and `usd` from calls.log. calls.log is read once at
/// launch and again when the day changes; between, `Spend` keeps the running total (N2.12).
struct Limits: @unchecked Sendable {  // UserDefaults is thread-safe
    static let usdKey = "limitUSDPerDay", requestsKey = "limitRequestsPerDay", minuteKey = "limitRequestsPerMinute"
    /// The start times of recent requests, seconds since 1970: today's, and the last minute's.
    static let startsKey = "limitStarts"
    static let usdDefault = 3.0, requestsDefault = 400, minuteDefault = 30

    var defaults: UserDefaults = .standard
    var now: @Sendable () -> Date = { Date() }
    var calendar = Calendar.current
    var log: @Sendable () -> [CallLog.Line] = { CallLog.lines() }
    /// Today's running total and the tasks' reserves. The app's is the one every logged call updates.
    var spend: Spend = CallLog.spend

    var usdPerDay: Double { defaults.object(forKey: Self.usdKey) as? Double ?? Self.usdDefault }
    var requestsPerDay: Int { Self.bounded(defaults.object(forKey: Self.requestsKey) as? Int ?? Self.requestsDefault, Self.dayBounds) }
    var requestsPerMinute: Int { Self.bounded(defaults.object(forKey: Self.minuteKey) as? Int ?? Self.minuteDefault, Self.minuteBounds) }

    /// NA.13: what the Limits panel may set the request counts to, decided here and never by what is stored.
    static let minuteBounds = 5...60, dayBounds = 50...2000
    static func bounded(_ value: Int, _ bounds: ClosedRange<Int>) -> Int { min(max(value, bounds.lowerBound), bounds.upperBound) }

    private static let lock = NSLock()

    /// Before a new request: throws `BrainError.limited` when a ceiling is hit, and nothing is sent; otherwise counts
    /// it. Also chooses the cache life for the calls that follow (D1).
    func start() throws {
        let now = now()
        let (spent, mainTimes) = spend.today(now, calendar: calendar, log: log)
        CallLog.hourCache = CacheLife.hour(mainTimes)
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

    /// Dollars today's ceiling still allows, before any task's reserve; infinity with no ceiling.
    func dayLeft() -> Double {
        usdPerDay > 0 ? usdPerDay - spend.today(now(), calendar: calendar, log: log).usd : .infinity
    }

    /// N2.12: sets aside up to `usd` of today's ceiling for task `task`, so tasks running side by side cannot pass it
    /// together. Returns the dollars set aside, the task's own cost cap; 0 when nothing is left (the task does not
    /// start); infinity with no ceiling. `release` gives back what the task did not spend.
    func reserve(task: Int, usd: Double) -> Double {
        guard usdPerDay > 0 else { return .infinity }
        let reserved = spend.reserve(task, usd: usd, ceiling: usdPerDay, now: now(), calendar: calendar, log: log)
        shellLog(reserved > 0 ? "limits: task \(task) reserved $\(String(format: "%.2f", reserved))" : "limits: task \(task) refused, nothing left today")
        return reserved
    }

    /// When the task ends or is stopped. Twice is harmless.
    func release(task: Int) { spend.release(task) }

    /// Today so far, for the Limits panel.
    func today() -> LimitsToday {
        let now = now()
        return LimitsToday(spentUSD: spend.today(now, calendar: calendar, log: log).usd,
                           requests: recent(now).filter { calendar.isDate($0, inSameDayAs: now) }.count,
                           usdPerDay: usdPerDay, requestsPerDay: requestsPerDay, requestsPerMinute: requestsPerMinute)
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

/// N2.12: today's dollars and the main model's call times, in memory. calls.log is read when first needed (at launch)
/// and again when the day changes; in between every logged call adds its line here (`CallLog.record`), so a request
/// never reads the file. Also the reserves of running tasks. Numbers only.
final class Spend: @unchecked Sendable {  // state under `lock`
    private let lock = NSLock()
    /// A moment of the day `usd` is for, and the calendar that says which day; nil until calls.log was read.
    private var day: Date?
    private var calendar = Calendar.current
    private var usd = 0.0
    /// The main model's call times, for `CacheLife`: the most recent `keep`.
    private var mainTimes: [Date] = []
    private static let keep = 1000
    /// Each running task's reserve, and what its calls cost since it was set aside.
    private var reserves: [Int: (usd: Double, spent: Double)] = [:]
    private var readCount = 0

    /// How many times calls.log was read: the proof there is no read per request.
    var reads: Int { lock.withLock { readCount } }

    func today(_ now: Date, calendar: Calendar, log: () -> [CallLog.Line]) -> (usd: Double, mainTimes: [Date]) {
        lock.withLock {
            read(now, calendar, log)
            return (usd, mainTimes)
        }
    }

    /// Up to `budget`, out of what the ceiling leaves once today's spend and the other tasks' unspent reserves are taken.
    func reserve(_ task: Int, usd budget: Double, ceiling: Double, now: Date, calendar: Calendar, log: () -> [CallLog.Line]) -> Double {
        lock.withLock {
            read(now, calendar, log)
            let held = reserves.values.reduce(0) { $0 + max(0, $1.usd - $1.spent) }
            let amount = min(budget, ceiling - usd - held)
            guard amount >= 0.01 else { return 0 }  // under a cent: nothing left, and no rounding crumb starts a task
            reserves[task] = (amount, 0)
            return amount
        }
    }

    func release(_ task: Int) { lock.withLock { _ = reserves.removeValue(forKey: task) } }

    /// Every logged call, as it is logged. Before the first read it is skipped: that read finds it in calls.log.
    /// A line of a later day is left for the read the next request makes.
    func add(_ line: CallLog.Line) {
        guard let date = line.date else { return }
        lock.withLock {
            guard let day else { return }
            if calendar.isDate(date, inSameDayAs: day) { usd += line.usd }
            if line.tier == Tier.main.rawValue { mainTimes = Array((mainTimes + [date]).suffix(Self.keep)) }
            if let task = line.task { reserves[task]?.spent += line.usd }
        }
    }

    /// Under `lock`. calls.log's writes never take `lock`, so waiting for them here cannot deadlock; a line logged
    /// while this reads waits for `lock`, then is added once.
    private func read(_ now: Date, _ calendar: Calendar, _ log: () -> [CallLog.Line]) {
        if let day, calendar == self.calendar, calendar.isDate(day, inSameDayAs: now) { return }
        let lines = log()
        readCount += 1
        (day, self.calendar) = (now, calendar)
        usd = CallLog.spent(lines, on: now, calendar: calendar)
        mainTimes = Array(lines.filter { $0.tier == Tier.main.rawValue }.compactMap(\.date).suffix(Self.keep))
    }
}

/// Today's spend and requests against the ceilings (0: no limit). Numbers only.
struct LimitsToday: Sendable, Equatable {
    var spentUSD = 0.0
    var requests = 0
    var usdPerDay = 0.0
    var requestsPerDay = 0
    var requestsPerMinute = 0
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
