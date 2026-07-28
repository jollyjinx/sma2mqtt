//
//  MQTTPublisher.swift
//

import Foundation
import JLog
import MQTTNIO
import NIOCore

public protocol SMAPublisher: Sendable
{
    func publish(to topic: String, payload: String, qos: MQTTQoS, retain: Bool) async throws
}

public actor MQTTPublisher: SMAPublisher
{
    let jsonOutput: Bool
    let emitInterval: Double
    let unchangedPublishInterval: TimeInterval
    let baseTopic: String
    private let address: MQTTServerAddress
    private let configuration: MQTTConnectionConfiguration
    private let identifier: String
    private var connection: MQTTConnection?
    private var connectionTask: Task<Void, Never>?
    var publicationGate = MQTTPublicationGate()

    public init(hostname: String, port: Int, username: String? = nil, password: String? = nil, emitInterval: Double = 1.0, unchangedPublishInterval: TimeInterval = 15.0, baseTopic: String = "", jsonOutput: Bool = false) async throws
    {
        self.emitInterval = emitInterval
        self.unchangedPublishInterval = unchangedPublishInterval
        self.jsonOutput = jsonOutput
        self.baseTopic = baseTopic.hasSuffix("/") ? String(baseTopic.dropLast(1)) : baseTopic
        address = .hostname(hostname, port: port)
        configuration = .init(userName: username, password: password)
        identifier = ProcessInfo.processInfo.processName

        connectionTask = Task { await maintainConnection() }
    }

    public func publish(to topic: String, payload: String, qos: MQTTQoS, retain: Bool) async throws
    {
        let topic = baseTopic + "/" + topic

        guard let connection
        else
        {
            publicationGate.reset()
            return
        }

        let now = Date()
        guard publicationGate.shouldPublish(topic: topic,
                                            payload: payload,
                                            retained: retain,
                                            at: now,
                                            minimumEmitInterval: emitInterval,
                                            unchangedPublishInterval: unchangedPublishInterval)
        else { return }
        do
        {
            JLog.debug("publish:\(topic) payload:\(payload)")
            try await connection.publish(to: topic, payload: ByteBuffer(string: payload), qos: qos, retain: retain)
            publicationGate.recordPublication(topic: topic, payload: payload, at: now)

            if jsonOutput
            {
                print("{\"topic\":\"\(topic)\",\"payload\":\(payload)}")
            }
        }
        catch
        {
            if self.connection === connection
            {
                self.connection = nil
                publicationGate.reset()
                connection.close()
            }
            throw error
        }
    }

    public func shutdown()
    {
        connectionTask?.cancel()
        connectionTask = nil
        connection?.close()
        connection = nil
        publicationGate.reset()
    }

    private func maintainConnection() async
    {
        while !Task.isCancelled
        {
            do
            {
                try await MQTTConnection.withConnection(address: address,
                                                        configuration: configuration,
                                                        identifier: identifier)
                { connection in
                    connectionOpened(connection)
                    await withTaskCancellationHandler
                    {
                        await connection.waitOnClose()
                    }
                    onCancel:
                    {
                        connection.close()
                    }
                    connectionClosed(connection)
                }
            }
            catch
            {
                connection = nil
                publicationGate.reset()
                if !Task.isCancelled
                {
                    JLog.error("MQTT connection failed: \(error)")
                }
            }

            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func connectionOpened(_ connection: MQTTConnection)
    {
        self.connection = connection
        publicationGate.reset()
    }

    private func connectionClosed(_ connection: MQTTConnection)
    {
        if self.connection === connection
        {
            self.connection = nil
            publicationGate.reset()
        }
    }
}
