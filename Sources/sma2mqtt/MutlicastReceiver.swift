import Foundation
#if os(Linux)
import Glibc
#else
import Darwin
#endif

import JLog

struct Packet
{
    let data: Data
    let sourceAddress: String
}

enum MulticastReceiverError: Error {
    case socketCreationFailed(Int32)
    case socketOptionsSettingFailed(Int32)
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

    init(groups: [String], listenAddress:String, listenPort:UInt16,bufferSize: Int = 65536) throws
    {
        self.bufferSize = bufferSize
        receiveBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        JLog.debug("Started listening on \(listenAddress)")

        let socketFileDescriptor = socket(AF_INET, SOCK_DGRAM, 0 ) // IPPROTO_UDP) // 0 , IPPROTO_MTP
        self.socketFileDescriptor = socketFileDescriptor
        guard socketFileDescriptor != -1 else {
            throw MulticastReceiverError.socketCreationFailed(errno)
        }

        var reuseAddress: Int32 = 1
        guard setsockopt(socketFileDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout<Int32>.size)) != -1
        else {
            throw MulticastReceiverError.socketOptionsSettingFailed(errno)
        }

        var socketAddress = sockaddr_in()
            socketAddress.sin_family = sa_family_t(AF_INET)
            socketAddress.sin_port = listenPort.bigEndian
            socketAddress.sin_addr.s_addr =  INADDR_ANY // inet_addr(listenAddress) // INADDR_ANY

         guard  bind(socketFileDescriptor, sockaddr_cast(&socketAddress),socklen_t(MemoryLayout<sockaddr_in>.size)) != -1
         else {
            throw MulticastReceiverError.socketBindingFailed(errno)
        }

        for group in groups
        {
            var multicastRequest = ip_mreq(imr_multiaddr: in_addr(s_addr: inet_addr(group)),
                                           imr_interface: in_addr(s_addr: inet_addr(listenAddress))) // INADDR_ANY)) //
            guard setsockopt(socketFileDescriptor, IPPROTO_IP, IP_ADD_MEMBERSHIP, &multicastRequest, socklen_t(MemoryLayout<ip_mreq>.size)) != -1
            else {
                throw MulticastReceiverError.multicastJoinFailed(errno)
            }
            JLog.debug("added group:\(group)")
        }
    }

    nonisolated
    private func sockaddr_cast<T>(_ ptr: UnsafeMutablePointer<T>) -> UnsafeMutablePointer<sockaddr>
    {
        return UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: sockaddr.self)
    }

    deinit
    {
        if socketFileDescriptor != -1
        {
            close(socketFileDescriptor)
        }
        receiveBuffer?.deallocate()
    }

    func startListening()
    {
        guard !isListening else { return }
        isListening = true
    }

    func stopListening()
    {
        isListening = false
    }

    func shutdown()
    {
        isListening = false
        close(socketFileDescriptor)
    }

    func receiveNextPacket() async throws -> Packet
    {
        return try await withUnsafeThrowingContinuation
        {  continuation in

            do
            {
                let receiveNext = try receiveNext()

                continuation.resume(returning: receiveNext)
            }
            catch
            {
                continuation.resume(throwing: error)
            }
        }
    }


    private func receiveNext() throws -> Packet
    {
        var socketAddress = sockaddr_in()
        var socketAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        JLog.debug("recvfrom")

        let bytesRead = recvfrom(socketFileDescriptor, receiveBuffer, bufferSize, 0,sockaddr_cast(&socketAddress), &socketAddressLength )
        guard bytesRead != -1 else { throw MulticastReceiverError.receiveError(errno) }

        var addr = socketAddress.sin_addr // sa.sin_addr
        var addrBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard let addrString = inet_ntop(AF_INET, &addr, &addrBuffer, socklen_t(INET_ADDRSTRLEN)) else { throw MulticastReceiverError.addressStringConversionFailed(errno) }

        return Packet(data: Data(bytes: receiveBuffer!, count: bytesRead), sourceAddress: String(cString:addrString) )
    }

}

//func main() async {
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
//}
//
//// Run the main function
//Task {
//    await main()
//}
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
//print("end")
