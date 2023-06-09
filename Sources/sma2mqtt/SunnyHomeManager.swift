//
//  SunnyHomeManager.swift
//
//
//  Created by Patrick Stein on 14.06.22.
//

import Foundation
import JLog
import sma2mqttLibrary

protocol SunnyHomeManagerDelegate: AnyObject { func addRemote(remoteAddress: String) }

class SunnyHomeManager: SunnyHomeManagerDelegate
{
    let password: String
    let bindAddress: String
    let mqttPublisher: MQTTPublisher
    let jsonOutput: Bool

    let receiver: MulticastReceiver
    var knownDevices = [String: SMADevice]()

    var lastDiscoveryRequestDate = Date.distantPast
    let disoveryRequestInterval = 10.0

    struct SMADevice
    {
        let address: String
        var lastSeen = Date()
        var inverter: SMAInverter

        init(address: String, userright: SMAInverter.UserRight = .user, password: String = "00000", bindAddress: String = "0.0.0.0")
        {
            self.address = address
            let inverter = SMAInverter(address: address, userright: userright, password: password)
            self.inverter = inverter

            Task { await inverter.values() }
        }
    }

    init(mqttPublisher: MQTTPublisher, multicastAddresses: [String], multicastPort: UInt16, bindAddress: String = "0.0.0.0", bindPort _: UInt16 = 0, password: String = "0000", jsonOutput: Bool) async throws
    {
        self.password = password
        self.bindAddress = bindAddress
        self.mqttPublisher = mqttPublisher
        self.jsonOutput = jsonOutput
        receiver = try MulticastReceiver(groups: multicastAddresses, bindAddress: bindAddress, listenPort: multicastPort)
        await receiver.startListening()
    }

    func addRemote(remoteAddress: String)
    {
        defer { knownDevices[remoteAddress]?.lastSeen = Date() }
        guard knownDevices[remoteAddress] == nil else { return }

        JLog.debug("Got new SMA Device with remoteAddress:\(remoteAddress)")

        knownDevices[remoteAddress] = SMADevice(address: remoteAddress, password: password, bindAddress: bindAddress)
    }

    func shutdown() async throws { await receiver.shutdown() }

    func sendDiscoveryPacketIfNeeded() async
    {
        guard Date().timeIntervalSince(lastDiscoveryRequestDate) > disoveryRequestInterval else { return }

        let data: [UInt8] = [0x53, 0x4D, 0x41, 0x00, 0x00, 0x04, 0x02, 0xA0, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00]
        let address = "239.12.255.254"
        let port: UInt16 = 9522

        await receiver.sendPacket(data: data, address: address, port: port)
        lastDiscoveryRequestDate = Date()
    }

    func receiveNext() async throws
    {
        await sendDiscoveryPacketIfNeeded()

        let packet = try await receiver.receiveNextPacket()

        JLog.debug("Received packet from \(packet.sourceAddress)")
//        JLog.debug("Received packet from \(packet.sourceAddress): \(packet.data.hexDump)")

        addRemote(remoteAddress: packet.sourceAddress)

        if !packet.data.isEmpty
        {
            if let sma = try? SMAPacket(data: packet.data)
            {
                JLog.debug("Decoded from \(packet.sourceAddress)")
                JLog.trace("Decoded json:\(sma.json)")

                for obisvalue in sma.obis
                {
                    if obisvalue.mqtt != .invisible
                    {
                        try? await mqttPublisher.publish(to: obisvalue.topic, payload: obisvalue.json, qos: .atLeastOnce, retain: obisvalue.mqtt == .retained)
                    }

                    if jsonOutput
                    {
                        var obisvalue = obisvalue
                        obisvalue.includeTopicInJSON = true
                        print("\(obisvalue.json)")
                    }
                }
            }
            else
            {
                JLog.error("did not decode")
            }
        }
    }
}
