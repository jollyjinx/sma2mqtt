//
//  SunnyHomeManager.swift
//
//
//  Created by Patrick Stein on 14.06.22.
//

import Foundation
import JLog

public actor SMALighthouse
{
    let password: String
    let bindAddress: String
    let mqttPublisher: MQTTPublisher
    let interestingPaths: [String]
    let jsonOutput: Bool

    let mcastReceiver: MulticastReceiver

    private enum SMADeviceCacheEntry
    {
        case inProgress(Task<SMADevice, Error>)
        case ready(SMADevice)
        case failed
    }

    private var smaDeviceCache = [String: SMADeviceCacheEntry]()

    var lastDiscoveryRequestDate = Date.distantPast
    let disoveryRequestInterval = 10.0

    public init(mqttPublisher: MQTTPublisher, multicastAddresses: [String], multicastPort: UInt16, bindAddress: String = "0.0.0.0", bindPort _: UInt16 = 0, password: String = "0000", interestingPaths: [String] = [], jsonOutput: Bool = false) async throws
    {
        self.password = password
        self.bindAddress = bindAddress
        self.mqttPublisher = mqttPublisher
        self.jsonOutput = jsonOutput
        self.interestingPaths = interestingPaths

        mcastReceiver = try MulticastReceiver(groups: multicastAddresses, bindAddress: bindAddress, listenPort: multicastPort)
        await mcastReceiver.startListening()

        Task
        {
            while !Task.isCancelled
            {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                JLog.debug("sending discovery packet")
                await sendDiscoveryPacketIfNeeded()
            }
        }
    }

    public func remote(for remoteAddress: String) async -> SMADevice?
    {
        if let cacheEntry = smaDeviceCache[remoteAddress]
        {
            switch cacheEntry
            {
                case let .ready(smaDevice):
                    return smaDevice
                case let .inProgress(task):
                    return try? await task.value
                case .failed:
                    return nil
            }
        }

        JLog.debug("Got new SMA Device with remoteAddress:\(remoteAddress)")

        let task = Task { try await SMADevice(address: remoteAddress, userright: .user, password: password, publisher: mqttPublisher, interestingPaths: interestingPaths) }
        smaDeviceCache[remoteAddress] = .inProgress(task)

        do
        {
            let smaDevice = try await task.value
            smaDeviceCache[remoteAddress] = .ready(smaDevice)
            return smaDevice
        }
        catch
        {
            JLog.error("\(remoteAddress): was not able to initialize:\(error) - ignoring address")

            smaDeviceCache[remoteAddress] = .failed
            return nil
        }
    }

    public func shutdown() async throws { await mcastReceiver.shutdown() }

    private func sendDiscoveryPacketIfNeeded() async
    {
        guard Date().timeIntervalSince(lastDiscoveryRequestDate) > disoveryRequestInterval else { return }

        let data: [UInt8] = [0x53, 0x4D, 0x41, 0x00, 0x00, 0x04, 0x02, 0xA0, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00]
        let address = "239.12.255.254"
        let port: UInt16 = 9522

        await mcastReceiver.sendPacket(data: data, address: address, port: port)
        lastDiscoveryRequestDate = Date()
    }

    public func receiveNext() async throws
    {
//        await sendDiscoveryPacketIfNeeded()

        let packet = try await mcastReceiver.receiveNextPacket()

        JLog.debug("Received packet from \(packet.sourceAddress)")
//        JLog.debug("Received packet from \(packet.sourceAddress): \(packet.data.hexDump)")

        guard let smaDevice = await remote(for: packet.sourceAddress)
        else
        {
            JLog.debug("\(packet.sourceAddress) ignoring as failed to initialize device")
            return
        }
//
        Task.detached
        {
            await smaDevice.receivedData(packet.data)
        }
//            {
//                for obisvalue in smaPacket.obis
//                {
//                    if obisvalue.mqtt != .invisible
//                    {
//                        try? await self.mqttPublisher.publish(to: obisvalue.topic, payload: obisvalue.json, qos: .atLeastOnce, retain: obisvalue.mqtt == .retained)
//                    }
//
//                    if self.jsonOutput
//                    {
//                        var obisvalue = obisvalue
//                        obisvalue.includeTopicInJSON = true
//                        print("\(obisvalue.json)")
//                    }
//                }
//            }
//        }
    }
}
