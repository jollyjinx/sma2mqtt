import Dispatch
import Foundation

import NIO
import MQTTNIO
import BinaryCoder
import ArgumentParser
import JLog

struct JNXServer
{
    let hostname: String
    let port: UInt16
}

struct JNXMQTTServer
{
    let server: JNXServer
    let emitInterval: Double
    let topic: String
}

struct JNXMCASTGroup
{
    let server: JNXServer
    let bind: JNXServer
}

struct sma2mqtt: ParsableCommand
{
    @Flag(name: .shortAndLong, help: "optional debug output")
    var debug: Int

    @Flag(name: .long, help: "send json output to stdout")
    var json:Bool = false

    @Option(name: .long, help: "MQTT Server hostname")
    var mqttServername: String = "mqtt"

    @Option(name: .long, help: "MQTT Server port")
    var mqttPort: UInt16 = 1883;

    @Option(name: .shortAndLong, help: "Interval to send updates to mqtt Server.")
    var interval: Double = 1.0

    @Option(name: .shortAndLong, help: "MQTT Server topic.")
    var topic: String = "sma/sunnymanager"

    @Option(name: .long, help: "Multicast Binding Listening Interface Address.")
    var bindAddress: String = "0.0.0.0"

    @Option(name: .long, help: "Multicast Binding Listening Port number.")
    var bindPort: UInt16 = 0;

    @Option(name: .long, help: "Multicast Group Address.")
    var mcastAddress: String = "239.12.255.254"

    @Option(name: .long, help: "Multicast Group Port number.")
    var mcastPort: UInt16 = 9522;

    mutating func run() throws
    {
        let mqttServer  = JNXMQTTServer(server: JNXServer(hostname: mqttServername, port: mqttPort), emitInterval: interval, topic: topic)
        let mcastServer = JNXMCASTGroup(server: JNXServer(hostname: mcastAddress, port: mcastPort), bind: JNXServer(hostname: bindAddress, port: bindPort) )

        if debug > 0
        {
            JLog.loglevel =  debug > 1 ? .trace : .debug
        }
        startSma2mqtt(mcastServer:mcastServer,mqttServer:mqttServer,jsonOutput:json)
    }
}
sma2mqtt.main()



func startSma2mqtt(mcastServer:JNXMCASTGroup,mqttServer:JNXMQTTServer,jsonOutput:Bool)
{
    let mqttEventLoopGroup  = MultiThreadedEventLoopGroup(numberOfThreads: 2)
    let mqttClient          = MQTTClient(configuration: .init(target: .host(mqttServer.server.hostname, port: Int(mqttServer.server.port)) ), eventLoopGroup: mqttEventLoopGroup  )
        mqttClient.connect()

    // We allow users to specify the interface they want to use here.
    var targetDevice: NIONetworkDevice? = nil
    if      mcastServer.bind.hostname != "0.0.0.0",
        let targetAddress = try? SocketAddress(ipAddress: mcastServer.bind.hostname, port: Int(mcastServer.bind.port))
    {
        for device in try! System.enumerateDevices()
        {
            if device.address == targetAddress
            {
                targetDevice = device
                break
            }
        }

        if targetDevice == nil
        {
            fatalError("Could not find device for \(targetAddress)")
        }
    }

    let smaMulticastAddress = try! SocketAddress(ipAddress: mcastServer.server.hostname, port: Int(mcastServer.server.port))
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    // Begin by setting up the basics of the bootstrap.
    let datagramBootstrap = DatagramBootstrap(group: group)
        .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        .channelInitializer { channel in
            return channel.pipeline.addHandler(ChatMessageEncoder()).flatMap {
                channel.pipeline.addHandler( SMAMessageReceiver(mqttClient:mqttClient,mqttServer:mqttServer,jsonOutput:jsonOutput) )
            }
        }

        // We cast our channel to MulticastChannel to obtain the multicast operations.
    let datagramChannel = try! datagramBootstrap
        .bind(host:mcastServer.server.hostname, port: Int(mcastServer.server.port))
        .flatMap { channel -> EventLoopFuture<Channel> in
            let channel = channel as! MulticastChannel
            return channel.joinGroup(smaMulticastAddress, device: targetDevice).map { channel }
        }.flatMap { channel -> EventLoopFuture<Channel> in
            guard let targetDevice = targetDevice else {
                return channel.eventLoop.makeSucceededFuture(channel)
            }

            let provider = channel as! SocketOptionProvider
            switch targetDevice.address {
            case .some(.v4(let addr)):
                return provider.setIPMulticastIF(addr.address.sin_addr).map { channel }
            case .some(.v6):
                return provider.setIPv6MulticastIF(CUnsignedInt(targetDevice.interfaceIndex)).map { channel }
            case .some(.unixDomainSocket):
                preconditionFailure("Should not be possible to create a multicast socket on a unix domain socket")
            case .none:
                preconditionFailure("Should not be possible to create a multicast socket on an interface without an address")
            }
        }.wait()

    JLog.info("Receiving SMA Data\nPress ^C to exit.")
    RunLoop.current.run()
//
//    while let line = readLine(strippingNewline: false) {
//        datagramChannel.writeAndFlush(AddressedEnvelope(remoteAddress: chatMulticastGroup, data: line), promise: nil)
//    }
//
    // Close the channel.
    try! datagramChannel.close().wait()
    try! group.syncShutdownGracefully()


    }



/// Implements a simple chat protocol
final class SMAMessageReceiver: ChannelInboundHandler
{
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    var lasttime:Date = Date.distantPast
    let mqttServer:JNXMQTTServer
    let mqttClient:MQTTClient
    let jsonOutput:Bool


    init(mqttClient:MQTTClient,mqttServer:JNXMQTTServer,jsonOutput:Bool = false)
    {
        self.mqttClient = mqttClient
        self.mqttServer = mqttServer
        self.jsonOutput = jsonOutput
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny)
    {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data

        let timenow = Date()

        if  timenow.timeIntervalSince(lasttime) > mqttServer.emitInterval,
            let byteData = buffer.readBytes(length: buffer.readableBytes)
        {
            JLog.debug("\(timenow) Data: \(byteData.count) from: \(envelope.remoteAddress) ")

            let binaryDecoder = BinaryDecoder(data: byteData )
            if let sma = try? binaryDecoder.decode(SMAMulticastPacket.self)
            {
                JLog.debug("Decoded: \(sma)")

                for var obisvalue in sma.obis
                {
                    if obisvalue.mqtt
                    {
                        let topic = "\(mqttServer.topic)/\(obisvalue.topic)"
                        mqttClient.publish( topic: topic,
                                            payload: obisvalue.json,
                                            retain: obisvalue.retain
                                           )
                    }
                    if jsonOutput
                    {
                        obisvalue.includeTopic = true
                        print("\(obisvalue.json)")
                    }
                }
                lasttime = timenow
            }
            else
            {
                JLog.error("did not decode")
            }
        }
    }
}


private final class ChatMessageEncoder: ChannelOutboundHandler {
    public typealias OutboundIn = AddressedEnvelope<String>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let message = self.unwrapOutboundIn(data)
        let buffer = context.channel.allocator.buffer(string: message.data)
        context.write(self.wrapOutboundOut(AddressedEnvelope(remoteAddress: message.remoteAddress, data: buffer)), promise: promise)
    }
}
