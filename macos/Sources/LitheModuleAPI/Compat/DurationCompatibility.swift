import Foundation

public struct Duration: Sendable, Equatable, Comparable, Hashable, CustomStringConvertible {
    public let nanoseconds: UInt64

    public init(nanoseconds: UInt64) {
        self.nanoseconds = nanoseconds
    }

    public static var zero: Duration {
        Duration(nanoseconds: 0)
    }

    public static func nanoseconds(_ ns: UInt64) -> Duration {
        Duration(nanoseconds: ns)
    }

    public static func nanoseconds(_ ns: Int64) -> Duration {
        Duration(nanoseconds: UInt64(max(0, ns)))
    }

    public static func microseconds(_ us: Int64) -> Duration {
        Duration(nanoseconds: UInt64(max(0, us)) * 1_000)
    }

    public static func microseconds(_ us: Double) -> Duration {
        Duration(nanoseconds: UInt64(max(0, us * 1_000)))
    }

    public static func milliseconds(_ ms: Int64) -> Duration {
        Duration(nanoseconds: UInt64(max(0, ms)) * 1_000_000)
    }

    public static func milliseconds(_ ms: Double) -> Duration {
        Duration(nanoseconds: UInt64(max(0, ms * 1_000_000)))
    }

    public static func milliseconds(_ ms: Int) -> Duration {
        Duration(nanoseconds: UInt64(max(0, ms)) * 1_000_000)
    }

    public static func seconds(_ s: Int64) -> Duration {
        Duration(nanoseconds: UInt64(max(0, s)) * 1_000_000_000)
    }

    public static func seconds(_ s: Double) -> Duration {
        Duration(nanoseconds: UInt64(max(0, s * 1_000_000_000)))
    }

    public static func seconds(_ s: Int) -> Duration {
        Duration(nanoseconds: UInt64(max(0, s)) * 1_000_000_000)
    }

    public static func < (lhs: Duration, rhs: Duration) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }

    public static func + (lhs: Duration, rhs: Duration) -> Duration {
        Duration(nanoseconds: lhs.nanoseconds + rhs.nanoseconds)
    }

    public static func - (lhs: Duration, rhs: Duration) -> Duration {
        Duration(nanoseconds: lhs.nanoseconds > rhs.nanoseconds ? lhs.nanoseconds - rhs.nanoseconds : 0)
    }

    public static func * (lhs: Duration, rhs: Int) -> Duration {
        Duration(nanoseconds: lhs.nanoseconds * UInt64(max(0, rhs)))
    }

    public static func / (lhs: Duration, rhs: Int) -> Duration {
        guard rhs > 0 else { return .zero }
        return Duration(nanoseconds: lhs.nanoseconds / UInt64(rhs))
    }

    public var components: (seconds: Int64, attoseconds: Int64) {
        let sec = Int64(nanoseconds / 1_000_000_000)
        let remNano = Int64(nanoseconds % 1_000_000_000)
        return (seconds: sec, attoseconds: remNano * 1_000_000_000)
    }

    public var description: String {
        "\(Double(nanoseconds) / 1_000_000_000) seconds"
    }
}

public struct ContinuousClock: Sendable {
    public struct Instant: Sendable, Comparable, Equatable, Hashable {
        public let date: Date

        public init(date: Date = Date()) {
            self.date = date
        }

        public static var now: Instant {
            Instant(date: Date())
        }

        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.date < rhs.date
        }

        public func advanced(by duration: Duration) -> Instant {
            Instant(date: date.addingTimeInterval(Double(duration.nanoseconds) / 1_000_000_000))
        }

        public func duration(to other: Instant) -> Duration {
            let interval = other.date.timeIntervalSince(date)
            return Duration(nanoseconds: UInt64(max(0, interval * 1_000_000_000)))
        }

        public static func + (lhs: Instant, rhs: Duration) -> Instant {
            lhs.advanced(by: rhs)
        }

        public static func - (lhs: Instant, rhs: Duration) -> Instant {
            Instant(date: lhs.date.addingTimeInterval(-Double(rhs.nanoseconds) / 1_000_000_000))
        }

        public static func - (lhs: Instant, rhs: Instant) -> Duration {
            rhs.duration(to: lhs)
        }
    }

    public init() {}

    public static var now: Instant {
        Instant()
    }

    public var now: Instant {
        Instant()
    }

    public func sleep(until deadline: Instant) async throws {
        let remaining = deadline.date.timeIntervalSince(Date())
        if remaining > 0 {
            try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(nanoseconds: duration.nanoseconds)
    }
}

extension Task where Success == Never, Failure == Never {
    public static func sleep(for duration: Duration) async throws {
        try await Task.sleep(nanoseconds: duration.nanoseconds)
    }
}
