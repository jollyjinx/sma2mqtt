import Foundation
import ArgumentParser
import JLog

@main
struct sma2mqtt: AsyncParsableCommand
{
    @Flag(name: .shortAndLong, help: "optional debug output")
    var debug: Int

    @Flag(name: .long, help: "send json output to stdout")
    var json:Bool = false



    @Option(name: .long, help: "MQTT Server hostname")
    var mqttServername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server port")
    var mqttPort: UInt16 = 1883;

    @Option(name: .long, help: "MQTT Server username")
    var mqttUsername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server password")
    var mqttPassword: String = ""

    @Option(name: .shortAndLong, help: "Interval to send updates to mqtt Server.")
    var interval: Double = 1.0

    #if DEBUG
    @Option(name: .shortAndLong, help: "MQTT Server topic.")
    var topic: String = "test/sma/sunnymanager"
    #else
    @Option(name: .shortAndLong, help: "MQTT Server topic.")
    var topic: String = "sma/sunnymanager"
    #endif


    @Option(name: .long, help: "Multicast Binding Listening Interface Address.")
    var bindAddress: String = "0.0.0.0"

    @Option(name: .long, help: "Multicast Binding Listening Port number.")
    var bindPort: UInt16 = 0;

    @Option(name: .long, help: "Multicast Group Address.")
    var mcastAddress: String = "239.12.255.254"

    @Option(name: .long, help: "Multicast Group Port number.")
    var mcastPort: UInt16 = 9522;
}


extension sma2mqtt
{
    mutating func run() async throws
    {
        let mqttServer  = JNXMQTTServer(server: JNXServer(hostname: mqttServername, port: Int(mqttPort),username:mqttUsername,password:mqttPassword), emitInterval: interval, topic: topic)
        let mcastServer = JNXMCASTGroup(server: JNXServer(hostname: mcastAddress, port: Int(mcastPort)), bind: JNXServer(hostname: bindAddress, port: Int(bindPort)) )

        if debug > 0
        {
            JLog.loglevel =  debug > 1 ? .trace : .debug
        }
        try await startSma2mqtt(mcastServer:mcastServer,mqttServer:mqttServer,jsonOutput:json)
    }
}
//sma2mqtt.main()

