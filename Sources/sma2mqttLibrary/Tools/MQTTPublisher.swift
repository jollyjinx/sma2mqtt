//
//  MQTTPublisher.swift
//

import Foundation
import JLog
import MQTTNIO
import NIO

public protocol SMAPublisher: Sendable
{
    func publish(to topic: String, payload: String, qos: MQTTQoS, retain: Bool) async throws
}

public actor MQTTPublisher: SMAPublisher
{
    let mqttClient: MQTTClient
    let jsonOutput: Bool
    let emitInterval: Double
    let baseTopic: String
    let mqttQueue = DispatchQueue(label: "mqttQueue")
    var lasttimeused = [String: Date]()

    public init(hostname: String, port: Int, username: String? = nil, password _: String? = nil, emitInterval: Double = 1.0, baseTopic: String = "", jsonOutput: Bool = false) async throws
    {
        self.emitInterval = emitInterval
        self.jsonOutput = jsonOutput
        self.baseTopic = baseTopic.hasSuffix("/") ? String(baseTopic.dropLast(1)) : baseTopic

        mqttClient = MQTTClient(host: hostname, port: port, identifier: ProcessInfo.processInfo.processName, eventLoopGroupProvider: .createNew, configuration: .init(userName: username, password: ""))

        mqttQueue.async { _ = self.mqttClient.connect() }
    }

    public func publish(to topic: String, payload: String, qos: MQTTQoS, retain: Bool) async throws
    {
        let topic = baseTopic + "/" + topic

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
            JLog.debug("publish:\(topic) payload:\(payload)")
            _ = self.mqttClient.publish(to: topic, payload: byteBuffer, qos: qos, retain: retain)

            if self.jsonOutput
            {
                print("{\"topic\":\"\(topic)\",\"payload\":\(payload)}")
            }
        }
    }
}
