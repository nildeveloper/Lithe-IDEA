import LitheModuleAPI
import Testing

struct DurationCompatibilityTests {
    @Test
    func monotonicInstantArithmetic() {
        let start = LitheModuleAPI.ContinuousClock.Instant(uptimeNanoseconds: 100)
        let end = start.advanced(by: .nanoseconds(25))

        #expect(end.uptimeNanoseconds == 125)
        #expect(start.duration(to: end) == .nanoseconds(25))
        #expect((end - .nanoseconds(25)).uptimeNanoseconds == 100)
    }
}
