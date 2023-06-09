import Foundation
import JLog

#if os(Linux)
    import Glibc
    let SOCK_DGRAM_VALUE = Int32(SOCK_DGRAM.rawValue)
#else
    import Darwin
    let SOCK_DGRAM_VALUE = SOCK_DGRAM
#endif

struct Packet
{
    let data: Data
    let sourceAddress: String
}

enum MulticastReceiverError: Error
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

actor MulticastReceiver
{
    private var socketFileDescriptor: Int32 = -1
    private var receiveBuffer: UnsafeMutablePointer<UInt8>?
    private var bufferSize: Int = 0
    private var isListening: Bool = true

    init(groups: [String], bindAddress: String, listenPort: UInt16, bufferSize: Int = 65536) throws
    {
        self.bufferSize = bufferSize
        receiveBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        let socketFileDescriptor = socket(AF_INET, SOCK_DGRAM_VALUE, 0) // IPPROTO_UDP) // 0 , IPPROTO_MTP
        self.socketFileDescriptor = socketFileDescriptor
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
        receiveBuffer?.deallocate()
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
            do
            {
                let receiveNext = try receiveNext()

                continuation.resume(returning: receiveNext)
            }
            catch { continuation.resume(throwing: error) }
        }
    }

    private func receiveNext() throws -> Packet
    {
        var socketAddress = sockaddr_in()
        var socketAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        JLog.debug("recvfrom")

        let bytesRead = recvfrom(socketFileDescriptor, receiveBuffer, bufferSize, 0, sockaddr_cast(&socketAddress), &socketAddressLength)
        guard bytesRead != -1 else { throw MulticastReceiverError.receiveError(errno) }

        var addr = socketAddress.sin_addr // sa.sin_addr
        var addrBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard let addrString = inet_ntop(AF_INET, &addr, &addrBuffer, socklen_t(INET_ADDRSTRLEN)) else { throw MulticastReceiverError.addressStringConversionFailed(errno) }

        return Packet(data: Data(bytes: receiveBuffer!, count: bytesRead), sourceAddress: String(cString: addrString))
    }

    func sendPacket(data: [UInt8], address: String, port: UInt16)
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

// func main() async {
//    // Define the multicast groups and port
//    let multicastGroups: [MulticastGroup] = [
//        MulticastGroup(address: "239.12.0.78", port: 955),
//        MulticastGroup(address: "239.12.1.105", port: 955)
//    ]
//
//    // Create an instance of MulticastReceiver
//    do {
//        let receiver = try MulticastReceiver(groups: multicastGroups)
//
//        // Start listening for packets
//        receiver.startListening()
//
//        // Receive and process packets in a loop
//        while true {
//            if let packet = await receiver.receiveNextPacket() {
//                let hexEncodedData = packet.data.map { String(format: "%02X", $0) }.joined(separator: " ")
//                print("Received packet from \(packet.sourceAddress): \(hexEncodedData)")
//            }
//        }
//    } catch {
//        print("Error creating MulticastReceiver:", error)
//    }
// }
//
//// Run the main function
// Task {
//    await main()
// }
//
//
//
//    let multicastGroups: [String] = [
//                                "239.12.255.253",
//                                "239.12.255.254",
//                                "239.12.255.255",
//
//                                "239.12.0.78",
//                                "239.12.1.105",     // 10.112.16.166
//                                "239.12.1.153",     // 10.112.16.127
//                                "239.12.1.55",      // 10.112.16.166
//                                "239.12.1.87",      // 10.112.16.107
//    ]
//
//    // Create an instance of MulticastReceiver
//    do
//    {
////        let receiver = try MulticastReceiver(groups: multicastGroups,listenAddress: "0.0.0.0", listenPort:9522)
//        let receiver = try MulticastReceiver(groups: multicastGroups,listenAddress: "10.112.16.115", listenPort:9522)
//        // Start listening for packets
//        await receiver.startListening()
//        print("Starting to listen")
//
//        // Receive and process packets in a loop
//
//        while true
//        {
//            print("awaiting next packet")
//            let packet = try await receiver.receiveNextPacket()
//
//            let hexEncodedData = packet.data.map { String(format: "%02X", $0) }.joined(separator: " ")
//            print("Received packet from \(packet.sourceAddress): \(hexEncodedData)")
//        }
//    }
//    catch
//    {
//        print("Error creating MulticastReceiver:", error)
//    }
//
//
// print("end")
