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
    let interestingPaths: [String: TimeInterval]

    let mcastAddress: String
    let mcastPort: UInt16
    let mcastReceiver: MulticastReceiver

    private enum SMADeviceCacheEntry
    {
        case inProgress(Task<SMADevice, Error>)
        case ready(SMADevice)
        case failed(Date)

        var asyncDescription: String
        { get async
        {
            switch self
            {
                case .inProgress: return "inProgress()\n"
                case let .ready(smaDevice): let deviceDescription = await smaDevice.asyncDescription
                    return "ready(\(smaDevice.address)): \(deviceDescription)\n"
                case let .failed(date): return "failed(\(date))\n"
            }
        }
        }
    }

    private var smaDeviceCache = [String: SMADeviceCacheEntry]()

    let disoveryRequestInterval = 10.0
    private var discoveryTask: Task<Void, Error>?

    public init(mqttPublisher: MQTTPublisher, multicastAddress: String, multicastPort: UInt16, bindAddress: String = "0.0.0.0", bindPort _: UInt16 = 0, password: String = "0000", interestingPaths: [String: TimeInterval] = [:]) async throws
    {
        self.password = password
        mcastAddress = multicastAddress
        mcastPort = multicastPort

        self.bindAddress = bindAddress
        self.mqttPublisher = mqttPublisher
        self.interestingPaths = interestingPaths

        mcastReceiver = try MulticastReceiver(groups: [mcastAddress], bindAddress: bindAddress, listenPort: multicastPort)
        await mcastReceiver.startListening()

        discoveryTask = Task(priority: .background)
        {
            let discoveryLoop = IntervalLoop(loopTime: self.disoveryRequestInterval)

            while !Task.isCancelled
            {
                JLog.debug("sending discovery packet")
                try? await self.sendDiscoveryPacket()
                try? await discoveryLoop.waitForNextIteration()
            }
        }
    }

    deinit
    {
        discoveryTask?.cancel()
    }
}

public extension SMALighthouse
{
    var asyncDescription: String
    { get async
    {
        var cacheDescription = [String]()
        for entry in smaDeviceCache
        {
            await cacheDescription.append(entry.value.asyncDescription)
        }

        return "SMALighthouse:\ninterestingPaths:\(interestingPaths.json)\nsmaDeviceCache: \(cacheDescription.joined(separator: "\n"))"
    }
    }

    func remote(for remoteAddress: String) async -> SMADevice?
    {
        if let cacheEntry = smaDeviceCache[remoteAddress]
        {
            switch cacheEntry
            {
                case let .ready(smaDevice):
                    if await smaDevice.isValid
                    {
                        return smaDevice
                    }
                    JLog.error("\(remoteAddress) is not responding - purging from cache")
                    smaDeviceCache.removeValue(forKey: remoteAddress)

                case let .inProgress(task):
                    return try? await task.value

                case let .failed(date):
                    if date.isWithin(timeInterval: 30.0)
                    {
                        JLog.info("still ignoring:\(remoteAddress)")
                        return nil
                    }
                    JLog.info("renabling:\(remoteAddress)")
                    smaDeviceCache.removeValue(forKey: remoteAddress)
            }
        }

        JLog.debug("Got new SMA Device with remoteAddress:\(remoteAddress)")

        let task = Task { try await SMADevice(address: remoteAddress, userright: .user, password: password, publisher: mqttPublisher, interestingPaths: interestingPaths, bindAddress: bindAddress, udpEmitter: mcastReceiver) }
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

            smaDeviceCache[remoteAddress] = .failed(Date())
            return nil
        }
    }

//    public nonisolated func shutdown() async throws { await mcastReceiver.shutdown() }

    private nonisolated func sendDiscoveryPacket() async throws
    {
        let dicoveryPacket = SMAPacketGenerator.generateDiscoveryPacket()
        await mcastReceiver.sendPacket(data: [UInt8](dicoveryPacket.hexStringToData()), packetcounter: 0, address: mcastAddress, port: mcastPort)
    }

    nonisolated func receiveNext() async throws
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

        Task
        {
            await smaDevice.receivedMulticast(packet.data)
        }
    }
}
