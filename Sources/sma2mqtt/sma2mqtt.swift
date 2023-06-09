import ArgumentParser
import Foundation
import JLog
import Logging

@main struct sma2mqtt: AsyncParsableCommand
{
    #if DEBUG
        @Option(name: .shortAndLong, help: "optional debug output") var debug: String = "debug"
    #else
        @Option(name: .shortAndLong, help: "optional debug output") var debug: String = "notice"
    #endif

    @Flag(name: .long, help: "send json output to stdout") var json: Bool = false

    @Option(name: .long, help: "MQTT Server hostname") var mqttServername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server port") var mqttPort: UInt16 = 1883

    @Option(name: .long, help: "MQTT Server username") var mqttUsername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server password") var mqttPassword: String = ""

    @Option(name: .shortAndLong, help: "Interval to send updates to mqtt Server.") var interval: Double = 1.0

    #if DEBUG
        @Option(name: .shortAndLong, help: "MQTT Server topic.") var basetopic: String = "example/sma/sunnymanager"
    #else
        @Option(name: .shortAndLong, help: "MQTT Server topic.") var basetopic: String = "sma/sunnymanager"
    #endif

    @Option(name: .long, help: "Multicast Binding Listening Interface Address.") var bindAddress: String = "0.0.0.0"

    @Option(name: .long, help: "Multicast Binding Listening Port number.") var bindPort: UInt16 = 9522

    @Option(name: .long, help: "Multicast Group Address.") var mcastAddress: String = "239.12.255.254"

    @Option(name: .long, help: "Multicast Group Port number.") var mcastPort: UInt16 = 9522

    @Option(name: .long, help: "Inverter Password.") var inverterPassword: String = "0000"

    func run() async throws
    {
        var sunnyHomeManagers = [SunnyHomeManager]()
        JLog.loglevel = Logger.Level(rawValue: debug) ?? Logger.Level.notice
        let mqttPublisher = try await MQTTPublisher(hostname: mqttServername, port: Int(mqttPort), username: mqttUsername, password: mqttPassword, emitInterval: interval, baseTopic: basetopic)
        let multicastGroups = [
            //            "239.12.0.78",
//            "239.12.1.105",
//            "239.12.1.153",
//            "239.12.1.55",
//            "239.12.1.87",

//            "239.12.255.252",
//            "239.12.255.253",
            "239.12.255.254",
//            "239.12.255.255",
//
//            "239.192.0.0", //
//
//            "224.0.0.251", // 10.112.16.195
        ]

        let sunnyHome = try await SunnyHomeManager(mqttPublisher: mqttPublisher,
                                                   multicastAddresses: multicastGroups,
                                                   multicastPort: mcastPort,
                                                   bindAddress: bindAddress,
                                                   bindPort: bindPort,
                                                   password: inverterPassword,
                                                   jsonOutput: json)
        sunnyHomeManagers.append(sunnyHome)

        while true { try await sunnyHome.receiveNext() }
    }
}
