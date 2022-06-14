//
//  MQTTPublisher.swift
//  
//
//  Created by Patrick Stein on 12.06.22.
//

import Foundation
import JLog

import NIO
import MQTTNIO


actor MQTTPublisher
{
    let mqttClient:MQTTClient
    let emitInterval: Double
    let baseTopic: String

    var lasttimeused = [String:Date]()

    init(hostname:String,port:Int,username:String? = nil, password:String? = nil,emitInterval:Double = 1.0 ,baseTopic:String = "") async throws
    {
        self.emitInterval = emitInterval
        self.baseTopic = baseTopic

        self.mqttClient = MQTTClient(host: hostname,
                                    port: port,
                                    identifier: ProcessInfo().processName,
                                    eventLoopGroupProvider: .createNew,
                                    configuration: .init(userName: username, password: password)
                                )
        try await activateClient()
    }

    private func activateClient() async throws
    {
        if !mqttClient.isActive()
        {
            try await mqttClient.connect()
        }
    }

    func publish(to topic:String,payload:String,qos: MQTTQoS,retain: Bool) async throws
    {
        let topic = "\(baseTopic)/\(topic)"

        let timenow = Date()
        let lasttime = lasttimeused[topic,default:.distantPast]

        guard timenow.timeIntervalSince(lasttime) > emitInterval else { return }
        lasttimeused[topic] = timenow

        let byteBuffer = ByteBuffer(string:payload)

        try await activateClient()
        try await mqttClient.publish(to: topic, payload: byteBuffer, qos:qos , retain:retain)
    }
}
