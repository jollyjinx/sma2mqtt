//
//  SunnyHomeManager.swift
//  
//
//  Created by Patrick Stein on 14.06.22.
//

import Foundation
import NIO
import MQTTNIO
import JLog
import sma2mqttLibrary

class SunnyHomeManager
{
    let datagramBootstrap:DatagramBootstrap
    let datagramChannel:Channel
    let group:MultiThreadedEventLoopGroup

    init(mqttPublisher:MQTTPublisher,multicastAddress:String, multicastPort:Int, bindAddress:String = "0.0.0.0",bindPort:Int = 12222) throws
    {
        var targetDevice: NIONetworkDevice? = nil

        if bindAddress != "0.0.0.0"
        {
            let targetAddress = try SocketAddress(ipAddress: bindAddress, port: bindPort)

            targetDevice = try System.enumerateDevices().filter{$0.address == targetAddress}.first
            guard targetDevice != nil else { fatalError("Could not find device for \(targetAddress)") }
        }


        let smaMulticastAddress = try SocketAddress(ipAddress: multicastAddress, port: multicastPort)
        self.group              = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        self.datagramBootstrap = DatagramBootstrap(group: self.group)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer
            {
                channel in

                return channel.pipeline.addHandler(SMAMessageEncoder()).flatMap {
                                                                                    channel.pipeline.addHandler( SMAMessageReceiver(mqttPublisher:mqttPublisher) )
                                                                                }
            }

        // We cast our channel to MulticastChannel to obtain the multicast operations.
        self.datagramChannel = try! datagramBootstrap
            .bind(host:multicastAddress, port: multicastPort)
            .flatMap
            {
                channel -> EventLoopFuture<Channel> in

                let channel = channel as! MulticastChannel
                return channel.joinGroup(smaMulticastAddress, device: targetDevice).map { channel }
            }.flatMap
            {
                channel -> EventLoopFuture<Channel> in

                guard let targetDevice = targetDevice else {
                                                            return channel.eventLoop.makeSucceededFuture(channel)
                                                            }

                let provider = channel as! SocketOptionProvider

                switch targetDevice.address
                {
                    case .some(.v4(let addr)):      return provider.setIPMulticastIF(addr.address.sin_addr).map { channel }
                    case .some(.v6):                return provider.setIPv6MulticastIF(CUnsignedInt(targetDevice.interfaceIndex)).map { channel }
                    case .some(.unixDomainSocket):  preconditionFailure("Should not be possible to create a multicast socket on a unix domain socket")
                    case .none:                     preconditionFailure("Should not be possible to create a multicast socket on an interface without an address")
                }
            }.wait()
    }


    func shutdown() async throws
    {
        try datagramChannel.close().wait()
        try group.syncShutdownGracefully()
    }
}


final class SMAMessageReceiver: ChannelInboundHandler
{
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>
    let mqttPublisher:MQTTPublisher

    init(mqttPublisher:MQTTPublisher)
    {
        self.mqttPublisher = mqttPublisher
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny)
    {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data
        var lasttime:Date = Date.distantPast
        let timenow = Date()

        print("remoteAddress:\(envelope.remoteAddress.ipAddress)")

        if let byteArray = buffer.readBytes(length: buffer.readableBytes)
        {
            JLog.debug("\(timenow) Data: \(byteArray.count) from: \(envelope.remoteAddress) ")

            if let sma = try? SMAPacket(byteArray:byteArray)
            {
                JLog.debug("Decoded: \(sma.json)")

                for obisvalue in sma.obis
                {
                    if obisvalue.mqtt != .invisible
                    {
                        Task.detached
                        {
                            try? await self.mqttPublisher.publish(to: obisvalue.topic, payload: obisvalue.json, qos:.atLeastOnce , retain:obisvalue.mqtt == .retained)
                        }
                    }
//                    if jsonOutput
//                    {
//                        var obisvalue = obisvalue
//                        obisvalue.includeTopicInJSON = true
//                        print("\(obisvalue.json)")
//                    }
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
