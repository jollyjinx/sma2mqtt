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

    let receiver: MulticastReceiver
    var knownDevices = [String: SMADevice]()

    struct SMADevice
    {
        let address: String
        var lastSeen = Date()
        var inverter: SMAInverter

        init(address: String, userright: SMAInverter.UserRight = .user, password: String = "00000", bindAddress: String = "0.0.0.0")
        {
            self.address = address
            let inverter = SMAInverter(address: address, userright: userright, password: password, bindAddress: bindAddress)
            self.inverter = inverter

            Task { await inverter.values() }
        }
    }

    init(mqttPublisher: MQTTPublisher, multicastAddresses: [String], multicastPort: UInt16, bindAddress: String = "0.0.0.0", bindPort _: UInt16 = 0, password: String = "0000") async throws
    {
        self.password = password
        self.bindAddress = bindAddress
        self.mqttPublisher = mqttPublisher
        receiver = try MulticastReceiver(groups: multicastAddresses, listenAddress: bindAddress, listenPort: multicastPort)
        await receiver.startListening()
    }

    func addRemote(remoteAddress: String)
    {
        defer { knownDevices[remoteAddress]?.lastSeen = Date() }
        guard knownDevices[remoteAddress] == nil else { return }

        JLog.debug("remoteAddress:\(remoteAddress)")

        knownDevices[remoteAddress] = SMADevice(address: remoteAddress, password: password, bindAddress: bindAddress)
    }

    func shutdown() async throws { await receiver.shutdown() }

    func receiveNext() async throws
    {
        let packet = try await receiver.receiveNextPacket()

        let hexEncodedData = packet.data.map { String(format: "%02X", $0) }.joined(separator: " ")
        //        print("Received packet from \(packet.sourceAddress)")
        print("Received packet from \(packet.sourceAddress): \(hexEncodedData)")

        addRemote(remoteAddress: packet.sourceAddress)

        if !packet.data.isEmpty
        {
            if let sma = try? SMAPacket(data: packet.data)
            {
                //                JLog.debug("Decoded from \(packet.sourceAddress)")
                JLog.debug("Decoded from \(packet.sourceAddress): \(sma.json)")

                for obisvalue in sma.obis
                {
                    if obisvalue.mqtt != .invisible
                    {
                        // Task.detached
                        // {
                        //                            try? await self.mqttPublisher.publish(to: obisvalue.topic, payload: obisvalue.json, qos:.atLeastOnce , retain:obisvalue.mqtt == .retained)
                        // }
                    } //                    if jsonOutput
                    //                    {
                    //                        var obisvalue = obisvalue
                    //                        obisvalue.includeTopicInJSON = true
                    //                        print("\(obisvalue.json)")
                    //                    }
                }
            }
            else
            {
                JLog.error("did not decode")
            }
        }
    }
}
