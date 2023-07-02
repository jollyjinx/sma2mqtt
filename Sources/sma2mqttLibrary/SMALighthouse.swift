//
//  SMALighthouse.swift
//

import Foundation
import JLog

public enum UserRight: String
{
    case user = "usr"
    case installer = "istl"
    case service = "svc"
    case developer = "dvlp"
}

public actor SMALighthouse
{
    let password: String
    let bindAddress: String
    let mqttPublisher: MQTTPublisher
    let interestingPaths: [String: Int]
    let jsonOutput: Bool

    let mcastAddress: String
    let mcastPort: UInt16
    let mcastReceiver: MulticastReceiver

    private enum SMADeviceCacheEntry
    {
        case inProgress(Task<SMADevice, Error>)
        case ready(SMADevice)
        case failed(Date)
    }

    private var smaDeviceCache = [String: SMADeviceCacheEntry]()

    var lastDiscoveryRequestDate = Date.distantPast
    let disoveryRequestInterval = 10.0

    public init(mqttPublisher: MQTTPublisher, multicastAddress: String, multicastPort: UInt16, bindAddress: String = "0.0.0.0", bindPort _: UInt16 = 0, password: String = "0000", interestingPaths: [String: Int] = [:], jsonOutput: Bool = false) async throws
    {
        self.password = password
        mcastAddress = multicastAddress
        mcastPort = multicastPort

        self.bindAddress = bindAddress
        self.mqttPublisher = mqttPublisher
        self.jsonOutput = jsonOutput
        self.interestingPaths = interestingPaths

        mcastReceiver = try MulticastReceiver(groups: [mcastAddress], bindAddress: bindAddress, listenPort: multicastPort)
        await mcastReceiver.startListening()

        Task
        {
            while !Task.isCancelled
            {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                JLog.debug("sending discovery packet")
                try? await sendDiscoveryPacketIfNeeded()
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
                case let .failed(date):
                    if date.timeIntervalSinceNow > -30
                    {
                        return nil
                    }
                    JLog.info("renabling:\(remoteAddress)")
                    smaDeviceCache.removeValue(forKey: remoteAddress)
            }
        }

        JLog.debug("Got new SMA Device with remoteAddress:\(remoteAddress)")

        let task = Task { try await SMADevice(address: remoteAddress, userright: .user, password: password, publisher: mqttPublisher, interestingPaths: interestingPaths, udpEmitter: mcastReceiver) }
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

            smaDeviceCache[remoteAddress] = .failed( Date() )
            return nil
        }
    }

    public func shutdown() async throws { await mcastReceiver.shutdown() }

    var hassentlogin = false
    private func sendDiscoveryPacketIfNeeded() async throws
    {
        guard Date().timeIntervalSince(lastDiscoveryRequestDate) > disoveryRequestInterval else { return }

        let dicoveryPacket = SMAPacketGenerator.generateDiscoveryPacket()
        await mcastReceiver.sendPacket(data: [UInt8](dicoveryPacket.hexStringToData()), address: mcastAddress, port: mcastPort)
        lastDiscoveryRequestDate = Date()
    }

    public func receiveNext() async throws
    {
        let packet = try await mcastReceiver.receiveNextPacket()

        JLog.debug("Received packet from \(packet.sourceAddress)")
        JLog.trace("Received packet from \(packet.sourceAddress): \(packet.data.hexDump)")

        guard let smaDevice = await remote(for: packet.sourceAddress)
        else
        {
            JLog.debug("\(packet.sourceAddress) ignoring as failed to initialize device")
            return
        }

        Task.detached
        {
            await smaDevice.receivedUDPData(packet.data)
        }
    }
}
