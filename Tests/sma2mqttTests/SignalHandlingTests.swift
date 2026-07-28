//
//  SignalHandlingTests.swift
//

import JLog
@testable import sma2mqtt
import Testing

struct SignalHandlingTests
{
    @Test
    func inverterPasswordDefaultsToEnvironmentValue()
    {
        #expect(resolvedInverterPassword(commandLineValue: nil, environment: ["INVERTER_PASSWORD": "secret"]) == "secret")
    }

    @Test
    func inverterPasswordFallsBackToDefault()
    {
        #expect(resolvedInverterPassword(commandLineValue: nil, environment: [:]) == "0000")
    }

    @Test
    func commandLineInverterPasswordOverridesDefault() throws
    {
        let command = try sma2mqtt.parse(["--inverter-password", "command-line-secret"])

        #expect(resolvedInverterPassword(commandLineValue: command.inverterPassword,
                                         environment: ["INVERTER_PASSWORD": "environment-secret"]) == "command-line-secret")
    }

    @Test
    func logLevelParsesFromCommandLine() throws
    {
        let command = try sma2mqtt.parse(["--log-level", "trace"])

        #expect(command.logLevel == .trace)
    }

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
