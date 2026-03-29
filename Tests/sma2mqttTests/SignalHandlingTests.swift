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

    @Test
    func handleSIGUSR1CyclesLogLevelWithoutCrashing() async
    {
        let originalLevel = JLog.loglevel
        defer { JLog.loglevel = originalLevel }

        JLog.loglevel = .notice
        handleSIGUSR1(signal: 10)
        await Task.yield()

        #expect(JLog.loglevel == .debug)

        handleSIGUSR1(signal: 10)
        await Task.yield()

        #expect(JLog.loglevel == .trace)
    }
}
