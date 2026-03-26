//
//  sma2mqttTests.swift
//

import BinaryCoder
import Foundation
import JLog
@testable import sma2mqttLibrary
import Testing

struct Sma2mqttTests
{
    @Test
    func sMANetDecoding1() throws
    {
        let packets = [
            "07 2c4a 08 8856 9c64 2e01 0000 6f24 0001 9f24 0000 a024 0000 dd24 0000 634a 0000 feff ff00 0000 0000",
            "0ea0 ffff ffff ffff 0001 1234 25f6 4321 0001 0000 0000 0180 0c04 fdff 0700 0000 8403 0000 4c20 cb51 0000 0000 dbb8 f4e9 fae7 ddfb edfa 8888",
            " 0aa0  ffff ffff ffff 00   c5  6901 6d33 26b3 00   05   0000 0000 7ba7 0c00   fdff    4c 4f43 4b      4544 0000        0000 0000",
        ]

        for packet in packets
        {
            let data = packet.hexStringToData()
            let binaryDecoder = BinaryDecoder(data: [UInt8](data))
            let decodedPacket = try SMANetPacketValue(fromBinary: binaryDecoder)

            JLog.debug("Packet:\(decodedPacket)")
            #expect(binaryDecoder.isAtEnd)
        }
    }

    @Test
    func sMADecoding() throws
    {
        let packets = [
            "534d 4100 0004 02a0 0000 0001 0026 0010 6065 09a0 ffff ffff ffff 0000 9901 f6a2 2fb3 0000 0000 0000 82ae 0002 8051 0048 2100 ff4a 4100 0000 0000",
            "534d 4100 0004 02a0 0000 0001 0026 0010 6065 09a0 1234 b87b 4321 00e1 9901 f6a2 2fb3 0001 1400 0000 b381 0102 5271 005b 4940 ff5b 4940 0000 0000",
        ]

        for packet in packets
        {
            JLog.debug("Working on:\n\n\(packet)\n")

            let data = packet.hexStringToData()
            let binaryDecoder = BinaryDecoder(data: [UInt8](data))
            let smaPacket = try SMAPacket(fromBinary: binaryDecoder)

            JLog.debug("SMAPacket:\(smaPacket)")
            JLog.debug("NetPacketValues:\n\n\(smaPacket.netPacket?.values.map(\.json).joined(separator: "\n") ?? "")\n")

            #expect(binaryDecoder.isAtEnd)
        }
    }

    @Test
    func sMAPacketGeneration() throws
    {
        let dataString = try SMAPacketGenerator.generatePacketForObjectID(packetcounter: 1, objectID: "6180_08414E00")
        let data = dataString.hexStringToData()

        let binaryDecoder = BinaryDecoder(data: [UInt8](data))

        let packet = try SMAPacket(fromBinary: binaryDecoder)
        JLog.debug("Packet:\(packet)")
        #expect(binaryDecoder.isAtEnd)

        let packet2 = try SMAPacket(data: data)
        JLog.debug("Packet2:\(packet2)")
    }

    @Test
    func sHMWeird() throws
    {
        let data = """
        534d 4100
        0004 02a0
             0000 0001
        000c 0010
             6081
             0001 0199 b32f a2f6
             ffff
        0000 0000
        """.hexStringToData()
        let binaryDecoder = BinaryDecoder(data: [UInt8](data))

        let packet = try SMAPacket(fromBinary: binaryDecoder)
        JLog.debug("Packet:\(packet)")
        #expect(binaryDecoder.isAtEnd)
    }

    @Test
    func sMADiscoveryResponseDecoding() throws
    {
        let data = """
        534d 4100  0004 02a0 0000 0001  0002 0000 0001  0004 0010 0001 0003  0004 0020 0000 0001  0004 0030 0a70 100a  0004 0040 0000 0000  0002 0070 ef0c  0001 0080 00  0000 0000
        534d 4100  0004 02a0 0000 0001  0002 0000 0001  0004 0010 0001 0003  0004 0020 0000 0001  0004 0030 0a70 100d                       0002 0070 ef0c                0000 0000
        534d 4100  0004 02a0 0000 0001  0002 0000 0001  0004 0010 0001 0003  0004 0020 0000 0001  0004 0030 0a70 100e  0004 0040 0000 0000  0002 0070 ef0c  0001 0080 00  0000 0000
        534d 4100  0004 02a0 0000 0001  0002 0000 0001  0004 0010 0001 0003  0004 0020 0000 0001  0004 0030 0a70 100f  0004 0040 0000 0000  0002 0070 ef0c  0001 0080 00  0000 0000
        """.hexStringToData()
        let binaryDecoder = BinaryDecoder(data: [UInt8](data))

        while !binaryDecoder.isAtEnd
        {
            let packet = try SMAPacket(fromBinary: binaryDecoder)
            JLog.debug("Packet:\(packet.json)")
        }

        #expect(binaryDecoder.isAtEnd)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.hasPcapFixture, "Requires a pcap fixture via --pcap-file or the default local path."))
    func sMAFile() throws
    {
        let fixturePath = ProcessInfo.processInfo.pcapFixturePath
        let fixtureURL = URL(fileURLWithPath: fixturePath)

        JLog.debug("loading data")
        let filedata = try Data(contentsOf: fixtureURL, options: .mappedIfSafe)
        JLog.debug("data loaded")

        let separator = Data([0x53, 0x4D, 0x41, 0x00])
        var splitter = DataSplitter(data: filedata, splitData: separator)

        JLog.debug("splitter instanciated")

        var goodcounter = 0
        var badcounter = 0

        var position = 0
        let binaryDecoder = BinaryDecoder(data: [UInt8](filedata))

        while position < (filedata.count - separator.count)
        {
            let chunk = filedata[position ..< position + separator.count]

            if chunk == separator
            {
                binaryDecoder.position = position

                do
                {
                    let packet = try SMAPacket(fromBinary: binaryDecoder)

                    goodcounter += 1
                    position = binaryDecoder.position
                    JLog.debug("Packet \(goodcounter):\(packet)")
                }
                catch
                {
                    badcounter += 1
                    position += 1

                    JLog.error("Packet \(goodcounter): got error: \(error) data:\(chunk.hexDump)")
                }
                if (goodcounter + badcounter) % 1000 == 0
                {
                    print("Good:\(goodcounter)  Bad:\(badcounter)")
                }
            }
            else
            {
                position += 1
            }
        }

        goodcounter = 0
        badcounter = 0

        while let chunk = splitter.next()
        {
            let binaryDecoder = BinaryDecoder(data: [UInt8](chunk))

            do
            {
                let packet = try SMAPacket(fromBinary: binaryDecoder)
                goodcounter += 1

                JLog.debug("Packet \(goodcounter):\(packet)")
            }
            catch
            {
                badcounter += 1

                JLog.error("Packet \(goodcounter): got error: \(error) data:\(chunk.hexDump)")
            }
            if (goodcounter + badcounter) % 1000 == 0
            {
                print("Good:\(goodcounter)  Bad:\(badcounter)")
            }
        }
    }

    @Test
    func sMAPacketDecoding1()
    {
        let data = """
        534d 4100 0004 02a0 0000 0001 03e6 0010 6065
        f9a0 1234 e419 4321 00a1 9901 f6a2 2fb3 0001 0000 0300 5804 0102 8051
        1800 0000 2f00 0000
        01aa 4a08 d6df 9462 3301 0001 b706 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
        01b7 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
        01b8 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
        01b9 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
        01ba 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 01bb 4a08 02e0 9462 260d 0001 270d 0000 280d 0000 290d 0000 feff ff00 0000 0000 0000 0000 0000 0000 01bc 4a08 03e0 9462 2f01 0001 3301 0000 bd06 0000 5208 0000 fd0c 0000 620d 0000 feff ff00 0000 0000 011e 4b08 03e0 9462 2f01 0001 3301 0000 b706 0000 bd06 0000 f007 0000 f107 0000 f207 0000 f707 0000 011e 4b08 03e0 9462 2508 0000 5208 0000 6c08 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0127 5200 03e0 9462 0000 0000 0000 0000 321e 0000 321e 0000 a00f 0000 a00f 0000 ffff ffff ffff ffff 0128 5240 03e0 9462 0000 0000 0000 0000 321e 0000 321e 0000 0000 0080 0000 0080 0000 0080 0000 0080 0129 5200 03e0 9462 0000 0000 0000 0000 1027 0000 1027 0000 ffff ffff ffff ffff ffff ffff ffff ffff 012a 5208 03e0 9462 1104 0000 1204 0000 fdff ff01 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 012f 5208 03e0 9462 2f01 0000 3401 0001 2203 0000 1f0d 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
        """.hexStringToData()
        let binaryDecoder = BinaryDecoder(data: [UInt8](data))
        let packet = try? SMAPacket(fromBinary: binaryDecoder)

        #expect(packet != nil)
    }
}
