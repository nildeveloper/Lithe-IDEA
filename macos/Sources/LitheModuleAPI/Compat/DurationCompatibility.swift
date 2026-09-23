import Foundation

public struct Duration: Sendable, Equatable, Comparable, Hashable, CustomStringConvertible {
    public let nanoseconds: UInt64

    public init(nanoseconds: UInt64) {
        self.nanoseconds = nanoseconds
    }

    public static var zero: Duration {
        Duration(nanoseconds: 0)
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
        // Keep deadlines independent of wall-clock changes on macOS 12.
        public let uptimeNanoseconds: UInt64

        public init(uptimeNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds) {
            self.uptimeNanoseconds = uptimeNanoseconds
        }

        public static var now: Instant {
            Instant()
        }

        public static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.uptimeNanoseconds < rhs.uptimeNanoseconds
        }

        public func advanced(by duration: Duration) -> Instant {
            let (result, overflow) = uptimeNanoseconds.addingReportingOverflow(duration.nanoseconds)
            return Instant(uptimeNanoseconds: overflow ? .max : result)
        }

        public func duration(to other: Instant) -> Duration {
            Duration(nanoseconds: other.uptimeNanoseconds > uptimeNanoseconds
                ? other.uptimeNanoseconds - uptimeNanoseconds : 0)
        }

        public static func + (lhs: Instant, rhs: Duration) -> Instant {
            lhs.advanced(by: rhs)
        }

        public static func - (lhs: Instant, rhs: Duration) -> Instant {
            Instant(uptimeNanoseconds: lhs.uptimeNanoseconds > rhs.nanoseconds
                ? lhs.uptimeNanoseconds - rhs.nanoseconds : 0)
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
        let now = DispatchTime.now().uptimeNanoseconds
        if deadline.uptimeNanoseconds > now {
            try await Task.sleep(nanoseconds: deadline.uptimeNanoseconds - now)
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
