//
//  File.swift
//  
//
//  Created by Patrick Stein on 12.06.22.
//

import Foundation
import JLog

import NIO
import MQTTNIO

import BinaryCoder

import sma2mqttLibrary

struct JNXServer
{
    let hostname: String
    let port: Int
    let username: String?
    let password: String?

    init(hostname:String,port:Int,username:String? = nil, password:String? = nil)
    {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
    }
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


func startSma2mqtt(mcastServer:JNXMCASTGroup,mqttServer:JNXMQTTServer,jsonOutput:Bool) async throws
{
    let mqttClient = MQTTClient(
        host: mqttServer.server.hostname,
        port: mqttServer.server.port,
        identifier: ProcessInfo().processName,
        eventLoopGroupProvider: .createNew,
        configuration: .init(userName: mqttServer.server.username, password: mqttServer.server.password)
    )

    let _ = try mqttClient.connect().wait()

    guard mqttClient.isActive() else
    {
        fatalError("Could not connect to mqtt server")
    }



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
            return channel.pipeline.addHandler(SMAMessageEncoder()).flatMap {
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
    Thread.sleep(until: Date.distantFuture)
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
        var lasttime:Date = Date.distantPast
        let timenow = Date()

        if  timenow.timeIntervalSince(lasttime) > mqttServer.emitInterval,
            let byteArray = buffer.readBytes(length: buffer.readableBytes)
        {
            JLog.debug("\(timenow) Data: \(byteArray.count) from: \(envelope.remoteAddress) ")


            if let sma = try? SMAPacket(byteArray:byteArray)
            {
                JLog.debug("Decoded: \(sma)")

                for var obisvalue in sma.obis
                {
                    if obisvalue.mqtt != .invisible
                    {
                        if !mqttClient.isActive()
                        {
                            JLog.error("No longer connected to mqtt server - reconnecting")

                            let _ = try? mqttClient.connect().wait()

                            guard self.mqttClient.isActive() else
                            {
                                fatalError("Could not connect to mqtt server")
                            }
                        }



                        let topic = "\(mqttServer.topic)/\(obisvalue.topic)"
                        let byteBuffer = ByteBuffer(string: obisvalue.json)
                        let _ = mqttClient.publish(to: topic, payload: byteBuffer, qos:.atLeastOnce , retain:obisvalue.mqtt == .retained)

                    }
                    if jsonOutput
                    {
                        obisvalue.includeTopicInJSON = true
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


private final class SMAMessageEncoder: ChannelOutboundHandler {
    public typealias OutboundIn = AddressedEnvelope<String>
    public typealias OutboundOut = AddressedEnvelope<ByteBuffer>

    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        let message = self.unwrapOutboundIn(data)
        let buffer = context.channel.allocator.buffer(string: message.data)
        context.write(self.wrapOutboundOut(AddressedEnvelope(remoteAddress: message.remoteAddress, data: buffer)), promise: promise)
    }
}
