//
//  UDPReceiver.swift
//

import Foundation
import JLog

import CNative

// public struct Packet
// {
//    let data: Data
//    let sourceAddress: String
// }

private enum UDPReceiverError: Error
{
    case socketCreationFailed(Int32)
    case socketOptionReuseAddressFailed(Int32)
    case socketOptionBroadcastFailed(Int32)
    case socketOptionPreventMulticastLoopbackFailed(Int32)
    case socketBindingFailed(Int32)
    case multicastJoinFailed(Int32)
    case receiveError(Int32)
    case invalidSocketAddress
    case invalidReceiveBuffer
    case addressStringConversionFailed(Int32)
    case timeoutErrorOuter
    case timeoutErrorRecv
    case timeoutErrorReceived([SMAPacket])
}

class UDPReceiver: UDPEmitter
{
    private let socketFileDescriptor: Int32
    private let bufferSize: Int
    private var isListening: Bool = true
    private var readSet = fd_set()

    init(bindAddress: String, listenPort: UInt16, bufferSize: Int = 65536) throws
    {
        JLog.debug("bindAddress:\(bindAddress) listenPort:\(listenPort)")
        self.bufferSize = bufferSize

        socketFileDescriptor = socket(AF_INET, SOCK_DGRAM_VALUE, 0) // IPPROTO_UDP) // 0 , IPPROTO_MTP
        guard socketFileDescriptor != -1 else { throw UDPReceiverError.socketCreationFailed(errno) }

        var reuseAddress: Int32 = 1
        guard setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout<Int32>.size)) != -1
        else
        {
            throw UDPReceiverError.socketOptionReuseAddressFailed(errno)
        }

        var enableBroadcast: Int32 = 1
        guard setsockopt(socketFileDescriptor, SOL_SOCKET, SO_BROADCAST, &enableBroadcast, socklen_t(MemoryLayout<Int32>.size)) != -1
        else
        {
            throw UDPReceiverError.socketOptionBroadcastFailed(errno)
        }

        var preventReceivingOwnPacket: Int32 = 0
        guard setsockopt(socketFileDescriptor, Int32(IPPROTO_IP), IP_MULTICAST_LOOP, &preventReceivingOwnPacket, socklen_t(MemoryLayout<Int32>.size)) != -1
        else
        {
            throw UDPReceiverError.socketOptionPreventMulticastLoopbackFailed(errno)
        }

        var socketAddress = sockaddr_in()
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_port = listenPort.bigEndian
        socketAddress.sin_addr.s_addr = inet_addr(bindAddress) // INADDR_ANY
//        socketAddress.sin_addr.s_addr = INADDR_ANY // INADDR_ANY

        guard bind(socketFileDescriptor, sockaddr_cast(&socketAddress), socklen_t(MemoryLayout<sockaddr_in>.size)) != -1
        else
        {
            throw UDPReceiverError.socketBindingFailed(errno)
        }

        JLog.debug("Started listening on \(bindAddress)")
    }

    private nonisolated func sockaddr_cast(_ ptr: UnsafeMutablePointer<some Any>) -> UnsafeMutablePointer<sockaddr> { UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self) }

    deinit
    {
        if socketFileDescriptor != -1 { close(socketFileDescriptor) }
//        receiveBuffer?.deallocate()
    }

    func startListening()
    {
        guard !isListening else { return }
        isListening = true
    }

    func stopListening() { isListening = false }

    func shutdown()
    {
        isListening = false
        close(socketFileDescriptor)
    }

    func receiveNextPacket(from address: String = "0.0.0.0", port: UInt16 = 0, timeout: Double) async throws -> Packet
    {
        let socket = socketFileDescriptor
        return try await withUnsafeThrowingContinuation
        { continuation in
            DispatchQueue.global().async
            {
                func sockaddr_cast(_ ptr: UnsafeMutablePointer<some Any>) -> UnsafeMutablePointer<sockaddr> { UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self) }
                var socketAddress = sockaddr_in()
                socketAddress.sin_family = sa_family_t(AF_INET)
                socketAddress.sin_port = port.bigEndian
                socketAddress.sin_addr.s_addr = inet_addr(address)

                var socketAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
                JLog.trace("recvfrom")

                let seconds = time_t(timeout)
                var timeout = timeval(tv_sec: seconds, tv_usec: suseconds_t((timeout - Double(seconds)) * Double(USEC_PER_SEC)))
                var readset: fd_set = .init()

                SWIFT_FD_SET(socket, &readset)

                let rv = select(socket + 1, &readset, nil, nil, &timeout)
                guard rv > 0 else { return continuation.resume(throwing: UDPReceiverError.timeoutErrorRecv) }

                let receiveBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.bufferSize)

                let bytesRead = recvfrom(self.socketFileDescriptor, receiveBuffer, self.bufferSize, 0, sockaddr_cast(&socketAddress), &socketAddressLength)
                guard bytesRead != -1 else { continuation.resume(throwing: UDPReceiverError.receiveError(errno)); return }

                var addr = socketAddress.sin_addr // sa.sin_addr
                var addrBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard let addrString = inet_ntop(AF_INET, &addr, &addrBuffer, socklen_t(INET_ADDRSTRLEN)) else { continuation.resume(throwing: UDPReceiverError.addressStringConversionFailed(errno)); return }

                let packet = Packet(data: Data(bytes: receiveBuffer, count: bytesRead), sourceAddress: String(cString: addrString))
                receiveBuffer.deallocate()

                continuation.resume(returning: packet)
            }
        }
    }

    func sendPacket(data: [UInt8], packetcounter: Int, address: String, port: UInt16)
    {
        var destinationAddress = sockaddr_in()

        destinationAddress.sin_family = sa_family_t(AF_INET)
        destinationAddress.sin_port = port.bigEndian
        destinationAddress.sin_addr.s_addr = inet_addr(address)

        let genericPointer = withUnsafePointer(to: &destinationAddress)
        {
            UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self)
        }

        let sent = sendto(socketFileDescriptor, data, data.count, 0, genericPointer, socklen_t(MemoryLayout<sockaddr_in>.size))

        if sent < 0
        {
            JLog.error("Could not sent Packet")
        }
        else
        {
            JLog.debug("Sent Packet to:\(address):\(port) packetcounter:\(String(format: "0x%04x", packetcounter)) sent:\(sent) == \(data.count)")
        }
    }

    func sendReceivePacket(data: [UInt8], packetcounter: Int, address: String, port: UInt16, receiveTimeout: Double) async throws -> [SMAPacket]
    {
        sendPacket(data: data, packetcounter: packetcounter, address: address, port: port)
        let startDate = Date()

        let endTime = Date(timeIntervalSinceNow: receiveTimeout)
        var smaPackets = [SMAPacket]()

        while endTime.timeIntervalSinceNow > 0
        {
            guard let packet = try? await receiveNextPacket(from: address, port: port, timeout: receiveTimeout),
                  let smaPacket = try? SMAPacket(data: packet.data),
                  packet.sourceAddress == address,
                  let packetid = smaPacket.netPacket?.header.packetId
            else
            {
                continue
            }

            smaPackets.append(smaPacket)

            guard packetid == packetcounter
            else
            {
                JLog.debug("packet from:\(address) packetcounter:\(String(format: "0x%04x", packetid)) - received wrong packet \(packetid) != \(packetcounter)")
                continue
            }
            JLog.debug("packet from:\(address) packetcounter:\(String(format: "0x%04x", packetid)) received in \(String(format: "%.1fms", startDate.timeIntervalSinceNow * -1000.0))")
            return smaPackets
        }
        JLog.notice("packet from:\(address) packetcounter:\(String(format: "0x%04x", packetcounter)) missing - did not arrive in time \(endTime.timeIntervalSinceNow + receiveTimeout)")

        return smaPackets
    }
}
