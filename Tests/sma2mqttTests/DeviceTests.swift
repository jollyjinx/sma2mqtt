//
//  DeviceTests.swift
//

import BinaryCoder
import Foundation
import JLog
@testable import sma2mqttLibrary
import Testing

struct DeviceTests
{
    @Test(.enabled(if: ProcessInfo.processInfo.shouldRunIntegrationTests, "Requires --run-integration-tests or SMA_INTEGRATION_TESTS=1."))
    func sunnyManager() async throws
    {
        let smaDevice = try await SMADevice(address: "10.112.16.10")
        let isHomeManager = await smaDevice.isHomeManager

        #expect(isHomeManager)
    }

    @Test
    func sunnyDiscoveryPacketResponse() throws
    {
        let data = """
        534d 4100 0004 02a0 0000 0001 0002 0000 0001 0004 0010 0001 0003 0004 0020 0000 0001 0004 0030 0a70 100a 0004 0040 0000 0000 0002 0070 ef0c 0001 0080 0000 0000 00
        534d 4100 0004 02a0 0000 0001 0002 0000 0001 0004 0010 0001 0003 0004 0020 0000 0001 0004 0030 0a70 100d                     0002 0070 ef0c 00             0000 00
        534d 4100 0004 02a0 0000 0001 0002 0000 0001 0004 0010 0001 0003 0004 0020 0000 0001 0004 0030 0a70 100e 0004 0040 0000 0000 0002 0070 ef0c 0001 0080 0000 0000 00
        534d 4100 0004 02a0 0000 0001 0002 0000 0001 0004 0010 0001 0003 0004 0020 0000 0001 0004 0030 0a70 100f 0004 0040 0000 0000 0002 0070 ef0c 0001 0080 0000 0000 00
        """.hexStringToData()
        let binaryDecoder = BinaryDecoder(data: [UInt8](data))

        while !binaryDecoder.isAtEnd
        {
            let packet = try SMAPacket(fromBinary: binaryDecoder)
            JLog.debug("Packet:\(packet.json)")
        }

        #expect(binaryDecoder.isAtEnd)
    }
}
