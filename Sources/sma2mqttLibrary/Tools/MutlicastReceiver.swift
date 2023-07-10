//
//  MutlicastReceiver.swift
//

import Foundation
import JLog

#if os(Linux)
    import Glibc
    let SOCK_DGRAM_VALUE = Int32(SOCK_DGRAM.rawValue)
#else
    import Darwin
    let SOCK_DGRAM_VALUE = SOCK_DGRAM
#endif

public protocol UDPEmitter
{
    func sendPacket(data: [UInt8], packetcounter: Int, address: String, port: UInt16) async
}

public struct Packet
{
    let data: Data
    let sourceAddress: String
}

private enum MulticastReceiverError: Error
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
}

actor MulticastReceiver: UDPEmitter
{
    private let socketFileDescriptor: Int32
    private let bufferSize: Int
    private var isListening: Bool = true

    init(groups: [String], bindAddress: String, listenPort: UInt16, bufferSize: Int = 65536) throws
    {
        self.bufferSize = bufferSize

        socketFileDescriptor = socket(AF_INET, SOCK_DGRAM_VALUE, 0) // IPPROTO_UDP) // 0 , IPPROTO_MTP
        guard socketFileDescriptor != -1 else { throw MulticastReceiverError.socketCreationFailed(errno) }

        var reuseAddress: Int32 = 1
        guard setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout<Int32>.size)) != -1
        else
        {
            throw MulticastReceiverError.socketOptionReuseAddressFailed(errno)
        }

        var enableBroadcast: Int32 = 1
        guard setsockopt(socketFileDescriptor, SOL_SOCKET, SO_BROADCAST, &enableBroadcast, socklen_t(MemoryLayout<Int32>.size)) != -1
        else
        {
            throw MulticastReceiverError.socketOptionBroadcastFailed(errno)
        }

        var preventReceivingOwnPacket: Int32 = 0
        guard setsockopt(socketFileDescriptor, Int32(IPPROTO_IP), IP_MULTICAST_LOOP, &preventReceivingOwnPacket, socklen_t(MemoryLayout<Int32>.size)) != -1
        else
        {
            throw MulticastReceiverError.socketOptionPreventMulticastLoopbackFailed(errno)
        }

        var socketAddress = sockaddr_in()
        socketAddress.sin_family = sa_family_t(AF_INET)
        socketAddress.sin_port = listenPort.bigEndian
        socketAddress.sin_addr.s_addr = inet_addr(bindAddress) // INADDR_ANY
//        socketAddress.sin_addr.s_addr = INADDR_ANY // INADDR_ANY

        guard bind(socketFileDescriptor, sockaddr_cast(&socketAddress), socklen_t(MemoryLayout<sockaddr_in>.size)) != -1
        else
        {
            throw MulticastReceiverError.socketBindingFailed(errno)
        }

        JLog.debug("Started listening on \(bindAddress)")

        for group in groups
        {
            var multicastRequest = ip_mreq()
            multicastRequest.imr_multiaddr.s_addr = inet_addr(group)
            multicastRequest.imr_interface.s_addr = inet_addr(bindAddress)
//            multicastRequest.imr_interface.s_addr = INADDR_ANY

//            var multicastRequest = ip_mreq(imr_multiaddr: in_addr(s_addr: inet_addr(group)), imr_interface: in_addr(s_addr: INADDR_ANY)) // INADDR_ANY)) //
//            var multicastRequest = ip_mreq(imr_multiaddr: in_addr(s_addr: inet_addr(group)), imr_interface: in_addr(s_addr: inet_addr(bindAddress))) // INADDR_ANY)) //
            guard setsockopt(socketFileDescriptor, Int32(IPPROTO_IP), IP_ADD_MEMBERSHIP, &multicastRequest, socklen_t(MemoryLayout<ip_mreq>.size)) != -1
            else
            {
                throw MulticastReceiverError.multicastJoinFailed(errno)
            }
            JLog.debug("added group:\(group)")
        }
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

    func receiveNextPacket() async throws -> Packet
    {
        try await withUnsafeThrowingContinuation
        { continuation in
            DispatchQueue.global().async
            {
                func sockaddr_cast(_ ptr: UnsafeMutablePointer<some Any>) -> UnsafeMutablePointer<sockaddr> { UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self) }
                var socketAddress = sockaddr_in()
                var socketAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
                JLog.debug("recvfrom")

                let receiveBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.bufferSize)

                let bytesRead = recvfrom(self.socketFileDescriptor, receiveBuffer, self.bufferSize, 0, sockaddr_cast(&socketAddress), &socketAddressLength)
                guard bytesRead != -1 else { continuation.resume(throwing: MulticastReceiverError.receiveError(errno)); return }

                var addr = socketAddress.sin_addr // sa.sin_addr
                var addrBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard let addrString = inet_ntop(AF_INET, &addr, &addrBuffer, socklen_t(INET_ADDRSTRLEN)) else { continuation.resume(throwing: MulticastReceiverError.addressStringConversionFailed(errno)); return }

                let packet = Packet(data: Data(bytes: receiveBuffer, count: bytesRead), sourceAddress: String(cString: addrString))
                receiveBuffer.deallocate()

                continuation.resume(returning: packet)
            }
        }
    }

    func sendPacket(data: [UInt8], packetcounter _: Int, address: String, port: UInt16)
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
            JLog.debug("Sent Packet successfull to:\(address):\(port) sent:\(sent) == \(data.count)")
        }
    }
}
