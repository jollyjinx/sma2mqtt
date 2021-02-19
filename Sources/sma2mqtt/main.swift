import Dispatch
import Foundation

import BinaryCoder
import NIO
import MQTTNIO

let mqttEventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
let mqttClient = MQTTClient(    configuration: .init(target: .host("mqtt", port: 1883) ),
                                eventLoopGroup: mqttEventLoopGroup  )
mqttClient.connect()

var lasttime:Date = Date.distantPast
var emitInterval = 1.0

/// Implements a simple chat protocol.
private final class ChatMessageDecoder: ChannelInboundHandler {
    public typealias InboundIn = AddressedEnvelope<ByteBuffer>

    public func channelRead(context: ChannelHandlerContext, data: NIOAny)
    {
        let envelope = self.unwrapInboundIn(data)
        var buffer = envelope.data

        let timenow = Date()

        if  timenow.timeIntervalSince(lasttime) > emitInterval,
            let byteData = buffer.readBytes(length: buffer.readableBytes)
        {
            print("\(timenow) Data: \(buffer.readableBytes) from: \(envelope.remoteAddress) ") // onPort:\(address.port)")

            let binaryDecoder = BinaryDecoder(data: byteData )
            if let sma = try? binaryDecoder.decode(SMAMulticastPacket.self)
            {
                //print( "Decoded: \(sma)")
                let jsonEncoder = JSONEncoder()
               //     jsonEncoder.dateEncodingStrategy = .iso8601

                let jsonData = try! jsonEncoder.encode(sma.interestingValues)
                let jsonString = String(data: jsonData, encoding: .utf8)!
                //print("JSON:\(jsonString)")

                mqttClient.publish( topic: "sma/sunnymanager",
                                    payload: jsonString,
                                    retain: true
                                    )
                lasttime = timenow
            }
            else
            {
                print("did not decode")
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


// We allow users to specify the interface they want to use here.
var targetDevice: NIONetworkDevice? = nil
if let interfaceAddress = CommandLine.arguments.dropFirst().first,
   let targetAddress = try? SocketAddress(ipAddress: interfaceAddress, port: 0) {
    for device in try! System.enumerateDevices() {
        if device.address == targetAddress {
            targetDevice = device
            break
        }
    }

    if targetDevice == nil {
        fatalError("Could not find device for \(interfaceAddress)")
    }
}

// For this chat protocol we temporarily squat on 224.1.0.26. This is a reserved multicast IPv4 address,
// so your machine is unlikely to have already joined this group. That helps properly demonstrate correct
// operation. We use port 7654 because, well, because why not.
let chatMulticastGroup = try! SocketAddress(ipAddress: "239.12.255.254", port: 9522)
let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

// Begin by setting up the basics of the bootstrap.
var datagramBootstrap = DatagramBootstrap(group: group)
    .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .channelInitializer { channel in
        return channel.pipeline.addHandler(ChatMessageEncoder()).flatMap {
            channel.pipeline.addHandler(ChatMessageDecoder())
        }
    }

    // We cast our channel to MulticastChannel to obtain the multicast operations.
let datagramChannel = try datagramBootstrap
    .bind(host: "0.0.0.0", port: 9522)
    .flatMap { channel -> EventLoopFuture<Channel> in
        let channel = channel as! MulticastChannel
        return channel.joinGroup(chatMulticastGroup, device: targetDevice).map { channel }
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

print("Now broadcasting, happy chatting.\nPress ^D to exit.")


while let line = readLine(strippingNewline: false) {
    datagramChannel.writeAndFlush(AddressedEnvelope(remoteAddress: chatMulticastGroup, data: line), promise: nil)
}

// Close the channel.
try! datagramChannel.close().wait()
try! group.syncShutdownGracefully()


