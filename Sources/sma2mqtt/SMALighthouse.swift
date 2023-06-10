//
//  SunnyHomeManager.swift
//
//
//  Created by Patrick Stein on 14.06.22.
//

import Foundation
import JLog
import sma2mqttLibrary

actor SMALighthouse
{
    let password: String
    let bindAddress: String
    let mqttPublisher: MQTTPublisher
    let jsonOutput: Bool

    let mcastReceiver: MulticastReceiver
    var knownDevices = [String: SMADevice]()

    var lastDiscoveryRequestDate = Date.distantPast
    let disoveryRequestInterval = 10.0

//    struct SMADeviceCache
//    {
//        let address: String
//        var lastSeen = Date()
//        var inverter: SMADevice
//
//        init(address: String, userright: SMADevice.UserRight = .user, password: String = "00000", bindAddress: String = "0.0.0.0")
//        {
//            self.address = address
//            let inverter = SMADevice(address: address, userright: userright, password: password)
//            self.inverter = inverter
//
//            Task { await inverter.values() }
//        }
//    }

    init(mqttPublisher: MQTTPublisher, multicastAddresses: [String], multicastPort: UInt16, bindAddress: String = "0.0.0.0", bindPort _: UInt16 = 0, password: String = "0000", jsonOutput: Bool) async throws
    {
        self.password = password
        self.bindAddress = bindAddress
        self.mqttPublisher = mqttPublisher
        self.jsonOutput = jsonOutput
        mcastReceiver = try MulticastReceiver(groups: multicastAddresses, bindAddress: bindAddress, listenPort: multicastPort)
        await mcastReceiver.startListening()
        Task
        {
            while !Task.isCancelled
            {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                JLog.debug("waited")
                JLog.debug("sending discovery packet")
                await sendDiscoveryPacketIfNeeded()
            }
        }
    }

    func remote(for remoteAddress: String) -> SMADevice
    {
        if let smaDevice = knownDevices[remoteAddress]
        {
            return smaDevice
        }
        JLog.debug("Got new SMA Device with remoteAddress:\(remoteAddress)")
        let smaDevice = SMADevice(address: remoteAddress, userright: .user, password: password)
        knownDevices[remoteAddress] = smaDevice
        return smaDevice
    }

    func shutdown() async throws { await mcastReceiver.shutdown() }

    private func sendDiscoveryPacketIfNeeded() async
    {
        guard Date().timeIntervalSince(lastDiscoveryRequestDate) > disoveryRequestInterval else { return }

        let data: [UInt8] = [0x53, 0x4D, 0x41, 0x00, 0x00, 0x04, 0x02, 0xA0, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00]
        let address = "239.12.255.254"
        let port: UInt16 = 9522

        await mcastReceiver.sendPacket(data: data, address: address, port: port)
        lastDiscoveryRequestDate = Date()
    }

    func receiveNext() async throws
    {
//        await sendDiscoveryPacketIfNeeded()

        let packet = try await mcastReceiver.receiveNextPacket()

        JLog.debug("Received packet from \(packet.sourceAddress)")
//        JLog.debug("Received packet from \(packet.sourceAddress): \(packet.data.hexDump)")

        let smaDevice = remote(for: packet.sourceAddress)

        Task.detached
        {
            if let smaPacket = await smaDevice.receivedData(packet.data)
            {
                for obisvalue in smaPacket.obis
                {
                    if obisvalue.mqtt != .invisible
                    {
                        try? await self.mqttPublisher.publish(to: obisvalue.topic, payload: obisvalue.json, qos: .atLeastOnce, retain: obisvalue.mqtt == .retained)
                    }

                    if self.jsonOutput
                    {
                        var obisvalue = obisvalue
                        obisvalue.includeTopicInJSON = true
                        print("\(obisvalue.json)")
                    }
                }
            }
        }
    }
}
