//
//  sma2mqtt.swift
//

import ArgumentParser
import Foundation
import JLog
import Logging
import sma2mqttLibrary

extension Logger.Level: ExpressibleByArgument {}
#if DEBUG
    let defaultLoglevel: Logger.Level = .debug
#else
    let defaultLoglevel: Logger.Level = .notice
#endif

@main struct sma2mqtt: AsyncParsableCommand
{
    @Option(help: "Set the log level.") var logLevel: Logger.Level = defaultLoglevel

    @Flag(name: .long, help: "send json output to stdout") var json: Bool = false

    @Option(name: .long, help: "MQTT Server hostname") var mqttServername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server port") var mqttPort: UInt16 = 1883

    @Option(name: .long, help: "MQTT Server username") var mqttUsername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server password") var mqttPassword: String = ""

    @Option(name: .shortAndLong, help: "Interval to send updates to mqtt Server.") var emitInterval: Double = 1.0

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
        "dc-side/dc-measurements/power:1",
        "ac-side/grid-measurements/power:1",
        "ac-side/measured-values/daily-yield:30",
        "immediate/feedin:1",
        "immediate/usage:1",

//                                                                                                      "immediate/gridfrequency",
        "battery/state-of-charge:20",
//                                                                                                      "battery/battery-charge",
//                                                                                                      "battery/present-battery-charge",
//                                                                                                      "battery/present-battery-discharge",
        "battery/battery/temperature:30",
        "battery/battery/battery-charge/battery-charge:20",
//        "temperatures",
        "temperature:30",
    ]
    func run() async throws
    {
        var sunnyHomeManagers = [SMALighthouse]()
        JLog.loglevel = logLevel

        if logLevel != defaultLoglevel
        {
            JLog.info("Loglevel: \(logLevel)")
        }

        let mqttPublisher = try await MQTTPublisher(hostname: mqttServername, port: Int(mqttPort), username: mqttUsername, password: mqttPassword, emitInterval: emitInterval, baseTopic: basetopic)

        let interestingPaths = Dictionary(uniqueKeysWithValues: interestingPathsAndValues.compactMap { let kv = $0.split(separator: ":"); return (String(kv[0]), Int(kv[1])) as? (String, Int) })

        let sunnyHome = try await SMALighthouse(mqttPublisher: mqttPublisher,
                                                multicastAddress: mcastAddress,
                                                multicastPort: mcastPort,
                                                bindAddress: bindAddress,
                                                bindPort: bindPort,
                                                password: inverterPassword,
                                                interestingPaths: interestingPaths,
                                                jsonOutput: json)
        sunnyHomeManagers.append(sunnyHome)

        while true { try await sunnyHome.receiveNext() }
    }
}
