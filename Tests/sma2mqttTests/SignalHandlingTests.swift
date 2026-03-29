//
//  SignalHandlingTests.swift
//

import JLog
@testable import sma2mqtt
import Testing

struct SignalHandlingTests
{
    @Test
    func logLevelCyclesAsExpected()
    {
        #expect(nextLogLevel(after: .trace) == .info)
        #expect(nextLogLevel(after: .debug) == .trace)
        #expect(nextLogLevel(after: .info) == .debug)
        #expect(nextLogLevel(after: .notice) == .debug)
    }
}
