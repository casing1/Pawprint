import Foundation

/// Caches `DailySummary` computation per day. A finished day's raw counters never change again
/// (barring an explicit delete), so its derived summary can be cached forever — this is what
/// makes the Activity Calendar / Records tabs fast on repeat visits instead of recomputing
/// ~100+ days of aggregation from scratch every time they're opened. "Today" is deliberately
/// never cached here since it changes constantly — callers should use `ActivityCenter.todaySummary`.
final package class SummaryCache {
    static package let shared = SummaryCache()

    private var cache: [String: DailySummary] = [:]
    private let lock = NSLock()

    private init() {}

    package func summary(for raw: DailyRawCounters, dayStartHour: Int) -> DailySummary {
        lock.lock()
        if let cached = cache[raw.day] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let computed = StatsEngine.summary(for: raw, dayStartHour: dayStartHour)
        lock.lock()
        cache[raw.day] = computed
        lock.unlock()
        return computed
    }

    package func invalidate(_ day: String) {
        lock.lock()
        cache.removeValue(forKey: day)
        lock.unlock()
    }

    package func invalidateAll() {
        lock.lock()
        cache.removeAll()
        lock.unlock()
    }
}
