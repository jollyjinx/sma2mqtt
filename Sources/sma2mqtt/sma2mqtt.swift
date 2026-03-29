//
//  sma2mqtt.swift
//

import ArgumentParser
import Dispatch
import Foundation
import JLog
import sma2mqttLibrary

extension JLog.Level: @retroactive ExpressibleByArgument {}
#if DEBUG
    let defaultLoglevel: JLog.Level = .debug
#else
    let defaultLoglevel: JLog.Level = .notice
#endif

@MainActor
var globalLighthouse: SMALighthouse?

@MainActor
var globalSignalSources = [DispatchSourceSignal]()

@main
struct sma2mqtt: AsyncParsableCommand
{
    @Option(help: "Set the log level.") var logLevel: JLog.Level = defaultLoglevel

    @Flag(name: .long, help: "send json output to stdout") var jsonOutput: Bool = false

    @Option(name: .long, help: "MQTT Server hostname") var mqttServername: String = "mqtt"
    @Option(name: .long, help: "MQTT Server port") var mqttPort: UInt16 = 1883
    @Option(name: .long, help: "MQTT Server username") var mqttUsername: String = "mqtt"
    @Option(name: .long, help: "MQTT Server password") var mqttPassword: String = ""
    @Option(name: .shortAndLong, help: "Minimum Emit Interval to send updates to mqtt Server.") var emitInterval: Double = 1.0
    #if DEBUG
        @Option(name: .shortAndLong, help: "MQTT Server topic.") var basetopic: String = "example/sma/"
    #else
        @Option(name: .shortAndLong, help: "MQTT Server topic.") var basetopic: String = "sma/"
    #endif

    @Option(name: .long, help: "Multicast Binding Listening Interface Address.") var bindAddress: String = "0.0.0.0"
    @Option(name: .long, help: "Multicast Binding Listening Port number.") var bindPort: UInt16 = 9522
    @Option(name: .long, help: "Multicast Group Address.") var mcastAddress: String = "239.12.255.254"
    @Option(name: .long, help: "Multicast Group Port number.") var mcastPort: UInt16 = 9522

    @Option(name: .long, help: "Inverter Password.") var inverterPassword: String = "0000"
    @Option(name: .long, help: "Array of path:interval values we are interested in") var interestingPathsAndValues: [String] = [
        "dc-side/dc-measurements/power:2",
        "ac-side/grid-measurements/power:2",
        "ac-side/measured-values/daily-yield:30",

        "battery/state-of-charge:20",
        "battery/battery/temperature:30",
        "battery/battery-charge/battery-charge:20",
//        "*:600", // all once
    ]

    @MainActor
    func run() async throws
    {
        JLog.loglevel = logLevel
        globalSignalSources = installSignalHandlers()

        if logLevel != defaultLoglevel
        {
            JLog.info("Loglevel: \(logLevel)")
        }

        let mqttPublisher = try await MQTTPublisher(hostname: mqttServername, port: Int(mqttPort), username: mqttUsername, password: mqttPassword, emitInterval: emitInterval, baseTopic: basetopic, jsonOutput: jsonOutput)

        let interestingPaths = Dictionary(uniqueKeysWithValues: interestingPathsAndValues.compactMap
        {
            let kv = $0.split(separator: ":")
            if kv.count == 2,
               let (path, interval) = (String(kv[0]), Int(kv[1])) as? (String, Int)
            {
                return (path, TimeInterval(interval))
            }
            return nil
        })

        let lightHouse = try await SMALighthouse(mqttPublisher: mqttPublisher,
                                                 multicastAddress: mcastAddress,
                                                 multicastPort: mcastPort,
                                                 bindAddress: bindAddress,
                                                 bindPort: bindPort,
                                                 password: inverterPassword,
                                                 interestingPaths: interestingPaths)
        globalLighthouse = lightHouse
        while true
        {
            #if DEBUG
                let description = await globalLighthouse?.asyncDescription ?? "no Lighthouse"
                JLog.debug("\(description)")
            #endif
            try await lightHouse.receiveNext()
        }
    }
}

func handleSIGUSR1(signal: Int32)
{
    JLog.notice("Received \(signal) signal.")
    JLog.notice("Switching Log level from \(JLog.loglevel)")
    JLog.loglevel = nextLogLevel(after: JLog.loglevel)
    JLog.notice("to \(JLog.loglevel)")
    dumpLighthouseState()
}

func handleSIGUSR2(signal: Int32)
{
    JLog.notice("Received \(signal) signal.")
    dumpLighthouseState()
}

func nextLogLevel(after level: JLog.Level) -> JLog.Level
{
    switch level
    {
        case .trace: .info
        case .debug: .trace
        case .info: .debug
        default: .debug
    }
}

@MainActor
func installSignalHandlers() -> [DispatchSourceSignal]
{
    signal(SIGUSR1, SIG_IGN)
    signal(SIGUSR2, SIG_IGN)

    let sigusr1 = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
    sigusr1.setEventHandler
    {
        Task
        { @MainActor in
            handleSIGUSR1(signal: SIGUSR1)
        }
    }
    sigusr1.resume()

    let sigusr2 = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
    sigusr2.setEventHandler
    {
        Task
        { @MainActor in
            handleSIGUSR2(signal: SIGUSR2)
        }
    }
    sigusr2.resume()

    return [sigusr1, sigusr2]
}

func dumpLighthouseState()
{
    Task
    { @MainActor in
        let description = await globalLighthouse?.asyncDescription ?? "no Lighthouse"
        JLog.notice("\(description)")
    }
}
