//
//  sma2mqtt.swift
//

import ArgumentParser
import Foundation
import JLog
import sma2mqttLibrary

extension JLog.Level: ExpressibleByArgument {}
#if DEBUG
    let defaultLoglevel: JLog.Level = .debug
#else
    let defaultLoglevel: JLog.Level = .notice
#endif

var globalLighthouse: SMALighthouse?

@main struct sma2mqtt: AsyncParsableCommand
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
    func run() async throws
    {
        JLog.loglevel = logLevel
        signal(SIGINT, SIG_IGN)
        signal(SIGINT, handleSIGINT)
        signal(SIGUSR1, SIG_IGN)
        signal(SIGUSR1, handleSIGUSR1)

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
        while true { try await lightHouse.receiveNext() }
    }
}

func handleSIGINT(signal: Int32)
{
    DispatchQueue.main.async
    {
        JLog.notice("Received \(signal) signal.")
        JLog.notice("Switching Log level from \(JLog.loglevel)")
        switch JLog.loglevel
        {
            case .trace: JLog.loglevel = .info
            case .debug: JLog.loglevel = .trace
            case .info: JLog.loglevel = .debug
            default: JLog.loglevel = .debug
        }

        JLog.notice("to \(JLog.loglevel)")
    }
}

func handleSIGUSR1(signal: Int32)
{
    JLog.notice("Received \(signal) signal.")
    DispatchQueue.main.async
    {
        Task
        {
            let description = await globalLighthouse?.asyncDescription ?? "no Lighthouse"
            JLog.notice("\(description)")
        }
    }
}
