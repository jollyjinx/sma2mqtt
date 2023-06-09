//
//  MQTTPublisher.swift
//
//
//  Created by Patrick Stein on 12.06.22.
//

import Foundation
import JLog
import MQTTNIO
import NIO

actor MQTTPublisher
{
    let mqttClient: MQTTClient
    let emitInterval: Double
    let baseTopic: String
    let mqttQueue = DispatchQueue(label: "mqttQueue")
    var lasttimeused = [String: Date]()

    init(hostname: String, port: Int, username: String? = nil, password _: String? = nil, emitInterval: Double = 1.0, baseTopic: String = "") async throws
    {
        self.emitInterval = emitInterval
        self.baseTopic = baseTopic

        mqttClient = MQTTClient(host: hostname, port: port, identifier: ProcessInfo.processInfo.processName, eventLoopGroupProvider: .createNew, configuration: .init(userName: username, password: ""))

        mqttQueue.async { _ = self.mqttClient.connect() }
    }

    func publish(to topic: String, payload: String, qos: MQTTQoS, retain: Bool) async throws
    {
        let topic = "\(baseTopic)/\(topic)"

        let timenow = Date()
        let lasttime = lasttimeused[topic, default: .distantPast]

        guard timenow.timeIntervalSince(lasttime) > emitInterval else { return }
        lasttimeused[topic] = timenow

        mqttQueue.async
        {
            let byteBuffer = ByteBuffer(string: payload)

            if !self.mqttClient.isActive()
            {
                _ = self.mqttClient.connect()
            }
            _ = self.mqttClient.publish(to: topic, payload: byteBuffer, qos: qos, retain: retain)
        }
    }
}
