import Foundation
import ArgumentParser
import JLog
import Logging

@main
struct sma2mqtt: AsyncParsableCommand
{
    #if DEBUG
    @Option(name: .shortAndLong, help: "optional debug output")
    var debug: String = "trace"
    #else
    @Option(name: .shortAndLong, help: "optional debug output")
    var debug: String = "notice"
    #endif

    @Flag(name: .long, help: "send json output to stdout")
    var json:Bool = false


    #if DEBUG
    @Option(name: .long, help: "MQTT Server hostname")
    var mqttServername: String = "pltmqtt.jinx.eu."
    #else
    @Option(name: .long, help: "MQTT Server hostname")
    var mqttServername: String = "mqtt"
    #endif

    @Option(name: .long, help: "MQTT Server port")
    var mqttPort: UInt16 = 1883

    @Option(name: .long, help: "MQTT Server username")
    var mqttUsername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server password")
    var mqttPassword: String = ""

    @Option(name: .shortAndLong, help: "Interval to send updates to mqtt Server.")
    var interval: Double = 1.0

    #if DEBUG
    @Option(name: .shortAndLong, help: "MQTT Server topic.")
    var basetopic: String = "test/sma/sunnymanager"
    #else
    @Option(name: .shortAndLong, help: "MQTT Server topic.")
    var basetopic: String = "sma/sunnymanager"
    #endif

    #if DEBUG
    @Option(name: .long, help: "Multicast Binding Listening Interface Address.")
    var bindAddress: String = "10.112.16.115"
    #else
    @Option(name: .long, help: "Multicast Binding Listening Interface Address.")
    var bindAddress: String = "0.0.0.0"
    #endif


    @Option(name: .long, help: "Multicast Binding Listening Port number.")
    var bindPort: UInt16 = 0;

    @Option(name: .long, help: "Multicast Group Address.")
    var mcastAddress: String = "239.12.255.254"

    @Option(name: .long, help: "Multicast Group Port number.")
    var mcastPort: UInt16 = 9522;

    func run() async throws
    {
        JLog.loglevel =  Logger.Level(rawValue:debug) ?? Logger.Level.notice

        let mqttPublisher = try await MQTTPublisher(    hostname: mqttServername,
                                                        port: Int(mqttPort),
                                                        username:mqttUsername,
                                                        password:mqttPassword,
                                                        emitInterval: interval,
                                                        baseTopic: basetopic
                                                    )
        let sunnyHome = try SunnyHomeManager(mqttPublisher:mqttPublisher,multicastAddress:mcastAddress, multicastPort: Int(mcastPort), bindAddress:bindAddress,bindPort:Int(bindPort))
        try await Task.sleep(nanoseconds: UInt64( Int64.max-10) )
        try await sunnyHome.shutdown()
    }
}

