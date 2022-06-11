import XCTest
import class Foundation.Bundle

@testable import JLog
@testable import BinaryCoder
@testable import sma2mqttLibrary

func hex(from string: String) -> Data
{
    let stringWithoutSpaces = string.replacingOccurrences(of:" ", with:"")
                                .replacingOccurrences(of:"\n", with:"")
                                .replacingOccurrences(of:"\t", with:"")

    let uInt8Array = stride(from: 0, to: stringWithoutSpaces.count, by: 2)
        .map{ stringWithoutSpaces[stringWithoutSpaces.index(stringWithoutSpaces.startIndex, offsetBy: $0) ... stringWithoutSpaces.index(stringWithoutSpaces.startIndex, offsetBy: $0 + 1)] }
        .map{ UInt8($0, radix: 16)! }
    return Data(uInt8Array)
}

struct DataSplitter:Sequence, IteratorProtocol
{
    let data : Data
    var index : Data.Index
    let splitData:Data

    init(data: Data,splitData:Data)
    {
        self.data = data
        self.splitData = splitData
        self.index = data.startIndex
        JLog.debug("init")
    }

    mutating func next() -> Data?
    {
        guard self.index != self.data.endIndex else { return nil }

        guard let range = data[index ..< data.endIndex].range(of: splitData)
        else
        {
            if index == data.startIndex
            {
                index = data.endIndex
                return nil
            }

            let returnData = data[ (index-splitData.count) ..< data.endIndex]
            index = data.endIndex
            return returnData
        }
        if index == data.startIndex
        {
            index = range.endIndex
            return next()
        }

        let returnData = data[ (index-splitData.count) ..< range.startIndex]
        index = range.endIndex

        return returnData
    }
}

extension Data {
    func split(separator: Data) -> [Data]
    {
        var chunks: [Data] = []
        var pos = startIndex
        // Find next occurrence of separator after current position:
        while let matchedRange = self[pos...].range(of: separator)
        {
            // Append if non-empty:
            if matchedRange.lowerBound > pos
            {
                chunks.append(self[(pos - separator.count)..<matchedRange.lowerBound])
            }
            // Update current position:
            pos = matchedRange.upperBound
        }
        // Append final chunk, if non-empty:
        if pos < endIndex
        {
            chunks.append(self[pos..<endIndex])
        }
        return chunks
    }
}


final class sma2mqttTests: XCTestCase
{
    func testSMADecoding() throws
    {
        JLog.loglevel = .trace
        
        let data  = hex(from:"534d4100 0004 02a0 00000001 0046 0010 6065 11 e0 07050102030400a19901f6 a22fb3 0001 0000 0000f1b10102005400000000010000000101260068d50f613b975300000000000122260068d50f61b81f00000000000000000000")

        let binaryDecoder = BinaryDecoder(data: [UInt8](data) )
        let packet = try? SMAPacket(fromBinary:binaryDecoder)
        JLog.debug("Packet:\(packet)")
        let packet2 = try? SMAPacket(data:data)
        JLog.debug("Packet2:\(packet2)")

        XCTAssert(true)
    }


    func testSMANetDecoding() throws
    {
        JLog.loglevel = .trace

        let data1  = hex(from:"534d 4100 0004 02a0 0000 0001 003a 0010 6065 0ea0 ffff ffff ffff 0001 1234 25f6 4321 0001 0000 0000 0180 0c04 fdff 0700 0000 8403 0000 4c20 cb51 0000 0000 dbb8 f4e9 fae7 ddfb edfa 8888 0000")
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )

        let packet1 = try? SMAPacket(fromBinary:binaryDecoder1)

        assert(binaryDecoder1.isAtEnd)
    }

    func testSMAFile() throws
    {
        JLog.loglevel = .info
        JLog.info("loading data")
        let data = try Data(contentsOf: URL(fileURLWithPath:"/Users/jolly/Documents/GitHub/sma2mqtt/Temp/Reverseengineering/testswift.sma"),options:.mappedRead)
        JLog.info("data loaded")
        
        let separator = Data(bytes: [0x53, 0x4d, 0x41, 0x00] )

        var counter = 0
        var splitter = DataSplitter(data: data, splitData: separator)

        while let chunk = splitter.next()
        {
            counter += 1
            let binaryDecoder = BinaryDecoder(data: [UInt8](chunk) )
            if counter % 1000 == 0
            {
                print(counter)
            }


            do
            {
                let packet = try SMAPacket(fromBinary:binaryDecoder)

                JLog.debug("Packet \(counter):\(packet)")
            }
            catch
            {
                JLog.error("Packet \(counter): got error: \(error) data:\(chunk.hexDump)")
            }
        }

        XCTAssert(true)
    }

    func testSMANetPacketDecoding() throws
    {
        JLog.loglevel = .trace
        let data1 = hex(from:"""
534d 4100 0004 02a0 0000 0001 03e6 0010 6065 f9a0 1234 e419 4321 00a1 9901 f6a2 2fb3 0001 0000 0300 5804 0102 8051 1800 0000 2f00 0000 01aa 4a08 d6df 9462 3301 0001 b706 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 01b7 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 01b8 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 01b9 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 01ba 4a10 02e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 01bb 4a08 02e0 9462 260d 0001 270d 0000 280d 0000 290d 0000 feff ff00 0000 0000 0000 0000 0000 0000 01bc 4a08 03e0 9462 2f01 0001 3301 0000 bd06 0000 5208 0000 fd0c 0000 620d 0000 feff ff00 0000 0000 011e 4b08 03e0 9462 2f01 0001 3301 0000 b706 0000 bd06 0000 f007 0000 f107 0000 f207 0000 f707 0000 011e 4b08 03e0 9462 2508 0000 5208 0000 6c08 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0127 5200 03e0 9462 0000 0000 0000 0000 321e 0000 321e 0000 a00f 0000 a00f 0000 ffff ffff ffff ffff 0128 5240 03e0 9462 0000 0000 0000 0000 321e 0000 321e 0000 0000 0080 0000 0080 0000 0080 0000 0080 0129 5200 03e0 9462 0000 0000 0000 0000 1027 0000 1027 0000 ffff ffff ffff ffff ffff ffff ffff ffff 012a 5208 03e0 9462 1104 0000 1204 0000 fdff ff01 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 012f 5208 03e0 9462 2f01 0000 3401 0001 2203 0000 1f0d 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
""")
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )
        let packet1 = try? SMAPacket(fromBinary:binaryDecoder1)
    }

    func testSMANetPacketDecoding2a() throws
    {
        JLog.loglevel = .trace
        let data1 = hex(from:"""
534d 4100 0004 02a0 0000 0001 03fa 0010 6065 fea0 1234 e419 4321 00a1 9901 f6a2 2fb3 0001 0000 0a00 5684 0102 0051 0000 0000 2200 0000 013f 2640 03e0 9462 f801 0000 f801 0000 f801 0000 f801 0000 0100 0000 011e 4100 fddf 9462 a00f 0000 a00f 0000 a00f 0000 a00f 0000 0100 0000 011f 4100 fddf 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0120 4100 fddf 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0166 4100 fddf 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0180 4100 fddf 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0136 4640 03e0 9462 4002 0000 4002 0000 4002 0000 4002 0000 0100 0000 0137 4640 03e0 9462 0000 0000 0000 0000 0000 0000 0000 0000 0100 0000 0140 4640 03e0 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0141 4640 03e0 9462 f801 0000 f801 0000 f801 0000 f801 0000 0100 0000 0142 4640 03e0 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0148 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0149 4600 03e0 9462 1d5c 0000 1d5c 0000 1d5c 0000 1d5c 0000 0100 0000 014a 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014b 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014c 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014d 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014e 4600 03e0 9462 6100 0000 6100 0000 6100 0000 6100 0000 0100 0000 0153 4640 03e0 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0154 4640 03e0 9462 d608 0000 d608 0000 d608 0000 d608 0000 0100 0000 0155 4640 03e0 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0157 4600 03e0 9462 8613 0000 8613 0000 8613 0000 8613 0000 0100 0000 0165 4640 03e0 9462 0f05 0000 0f05 0000 0f05 0000 0f05 0000 0100 0000 0166 4640 03e0 9462 cc07 0000 cc07 0000 cc07 0000 cc07 0000 0100 0000 016b 4640 03e0 9462 9103 0000 9103 0000 9103 0000 9103 0000 0100 0000 016c 4640 03e0 9462 2c01 0000 2c01 0000 2c01 0000 2c01 0000 0100 0000 016d 4640 03e0 9462 b601 0000 b601 0000 b601 0000 b601 0000 0100 0000 016e 4640 03e0 9462 ba00 0000 ba00 0000 ba00 0000 ba00 0000 0100 0000 0177 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0178 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0179 4600 03e0 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0181 4600 03e0 9462 8513 0000 8513 0000 8513 0000 8513 0000 0100 0000 018f 4640 03e0 9462 5002 0000 5002 0000 5002 0000 5002 0000 0100 0000 0199 4640 03e0 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 01c2 4600 03e0 9462 f801 0000 f801 0000 f801 0000 f801 0000 0100 0000 0000 0000
""")
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )
        let packet1 = try? SMAPacket(fromBinary:binaryDecoder1)
    }

    func testSMANetPacketDecoding2() throws
    {
        JLog.loglevel = .trace
        let data1 = hex(from:"""

534d 4100 0004 02a0 0000 0001 03fa 0010 6065 fea0 1234 25f6 4321 00a1 9901 f6a2 2fb3 0001 0000 0900 4604 0102 0051 2300 0000 4500 0000 01e5 4600 40d5 9462 275c 0000 275c 0000 275c 0000 275c 0000 0100 0000 01e6 4600 40d5 9462 305c 0000 305c 0000 305c 0000 305c 0000 0100 0000 01e7 4600 40d5 9462 175c 0000 175c 0000 175c 0000 175c 0000 0100 0000 01e8 4600 40d5 9462 5e02 0000 5e02 0000 5e02 0000 5e02 0000 0100 0000 01e9 4600 40d5 9462 6a03 0000 6a03 0000 6a03 0000 6a03 0000 0100 0000 01ea 4600 40d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0100 0000 01eb 4600 40d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0100 0000 01ec 4600 40d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0100 0000 01ed 4600 40d5 9462 a000 0000 a000 0000 a000 0000 a000 0000 0100 0000 01ee 4640 40d5 9462 0600 0000 0600 0000 0600 0000 0600 0000 0100 0000 01ef 4640 40d5 9462 2300 0000 2300 0000 2300 0000 2300 0000 0100 0000 01f0 4640 40d5 9462 5d00 0000 5d00 0000 5d00 0000 5d00 0000 0100 0000 01f1 4640 40d5 9462 8600 0000 8600 0000 8600 0000 8600 0000 0100 0000 01b6 4a00 37d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0100 0000 011f 5740 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0128 6540 0000 0000 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0000 0000
""")
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )
        let packet1 = try? SMAPacket(fromBinary:binaryDecoder1)
    }
    func testSMANetPacketDecoding3() throws
    {
        JLog.loglevel = .trace
        let data1 = hex(from:"""

534d 4100 0004 02a0 0000 0001 03fa 0010 6065 fea0 1234 25f6 4321 00a1 9901 f6a2 2fb3 0001 0000 0a00 4684 0102 0051 0000 0000 2200 0000 013f 2640 40d5 9462 ad03 0000 ad03 0000 ad03 0000 ad03 0000 0100 0000 011e 4100 3fd5 9462 a00f 0000 a00f 0000 a00f 0000 a00f 0000 0100 0000 011f 4100 3fd5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0120 4100 3fd5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0166 4100 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0180 4100 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0136 4640 40d5 9462 2805 0000 2805 0000 2805 0000 2805 0000 0100 0000 0137 4640 40d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0100 0000 0140 4640 40d5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0141 4640 40d5 9462 ad03 0000 ad03 0000 ad03 0000 ad03 0000 0100 0000 0142 4640 40d5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0148 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0149 4600 40d5 9462 275c 0000 275c 0000 275c 0000 275c 0000 0100 0000 014a 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014b 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014c 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014d 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014e 4600 40d5 9462 6300 0000 6300 0000 6300 0000 6300 0000 0100 0000 0153 4640 40d5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0154 4640 40d5 9462 f90f 0000 f90f 0000 f90f 0000 f90f 0000 0100 0000 0155 4640 40d5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0157 4600 40d5 9462 8513 0000 8513 0000 8513 0000 8513 0000 0100 0000 0165 4640 40d5 9462 1a0a 0000 1a0a 0000 1a0a 0000 1a0a 0000 0100 0000 0166 4640 40d5 9462 df0e 0000 df0e 0000 df0e 0000 df0e 0000 0100 0000 016b 4640 40d5 9462 8b03 0000 8b03 0000 8b03 0000 8b03 0000 0100 0000 016c 4640 40d5 9462 5e02 0000 5e02 0000 5e02 0000 5e02 0000 0100 0000 016d 4640 40d5 9462 6b03 0000 6b03 0000 6b03 0000 6b03 0000 0100 0000 016e 4640 40d5 9462 b900 0000 b900 0000 b900 0000 b900 0000 0100 0000 0177 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0178 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0179 4600 40d5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0181 4600 40d5 9462 8513 0000 8513 0000 8513 0000 8513 0000 0100 0000 018f 4640 40d5 9462 2f05 0000 2f05 0000 2f05 0000 2f05 0000 0100 0000 0199 4640 40d5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 01c2 4600 40d5 9462 ad03 0000 ad03 0000 ad03 0000 ad03 0000 0100 0000 0000 0000
""")
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )
        let packet1 = try? SMAPacket(fromBinary:binaryDecoder1)
    }
    func testSMANetPacketDecoding4() throws
    {
        JLog.loglevel = .trace
        let data1 = hex(from:"""
534d 4100 0004 02a0 0000 0001 03fa 0010 6065 fea0 1234 25f6 4321 00a1 9901 f6a2 2fb3 0001 0000 0a00 4284 0102 0051 0000 0000 2200 0000 013f 2640 3fd5 9462 a903 0000 a903 0000 a903 0000 a903 0000 0100 0000 011e 4100 3fd5 9462 a00f 0000 a00f 0000 a00f 0000 a00f 0000 0100 0000 011f 4100 3fd5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0120 4100 3fd5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0166 4100 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0180 4100 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0136 4640 3fd5 9462 2405 0000 2405 0000 2405 0000 2405 0000 0100 0000 0137 4640 3fd5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0100 0000 0140 4640 3fd5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0141 4640 3fd5 9462 a903 0000 a903 0000 a903 0000 a903 0000 0100 0000 0142 4640 3fd5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0148 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0149 4600 3fd5 9462 255c 0000 255c 0000 255c 0000 255c 0000 0100 0000 014a 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014b 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014c 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014d 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 014e 4600 3fd5 9462 6300 0000 6300 0000 6300 0000 6300 0000 0100 0000 0153 4640 3fd5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0154 4640 3fd5 9462 e30f 0000 e30f 0000 e30f 0000 e30f 0000 0100 0000 0155 4640 3fd5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 0157 4600 3fd5 9462 8513 0000 8513 0000 8513 0000 8513 0000 0100 0000 0165 4640 3fd5 9462 1b0a 0000 1b0a 0000 1b0a 0000 1b0a 0000 0100 0000 0166 4640 3fd5 9462 cf0e 0000 cf0e 0000 cf0e 0000 cf0e 0000 0100 0000 016b 4640 3fd5 9462 8603 0000 8603 0000 8603 0000 8603 0000 0100 0000 016c 4640 3fd5 9462 5e02 0000 5e02 0000 5e02 0000 5e02 0000 0100 0000 016d 4640 3fd5 9462 6603 0000 6603 0000 6603 0000 6603 0000 0100 0000 016e 4640 3fd5 9462 b800 0000 b800 0000 b800 0000 b800 0000 0100 0000 0177 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0178 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0179 4600 3fd5 9462 ffff ffff ffff ffff ffff ffff ffff ffff 0100 0000 0181 4600 3fd5 9462 8513 0000 8513 0000 8513 0000 8513 0000 0100 0000 018f 4640 3fd5 9462 2b05 0000 2b05 0000 2b05 0000 2b05 0000 0100 0000 0199 4640 3fd5 9462 0000 0080 0000 0080 0000 0080 0000 0080 0100 0000 01c2 4600 3fd5 9462 a903 0000 a903 0000 a903 0000 a903 0000 0100 0000 0000 0000
""")
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )
        let packet1 = try? SMAPacket(fromBinary:binaryDecoder1)
    }


    func testSMANetPacketDecoding5() throws
    {
        JLog.loglevel = .trace
        let data1 = hex(from:"""

534d 4100 0004 02a0 0000 0001 03e6 0010 6065
f9a0 1234 5737 4321 00a1 9901 f6a2 2fb3 0001 0000 0400 3480 0102 8051 0000 0000 1700 0000

0148 2108 747e a162 3301 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
0128 4108 747e a162 2701 0001 7d01 0000 bb01 0000 7005 0000 7105 0000 bb05 0000 bd05 0000 c805 0000
0128 4108 747e a162 3f07 0000 4708 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
0129 4108 737e a162 2e01 0001 6b0c 0000 6c0c 0000 6d0c 0000 6e0c 0000 feff ff00 0000 0000 0000 0000
0132 4108 747e a162 2f01 0000 3401 0001 2203 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0000 0000
0133 4108 747e a162 2f01 0000 3401 0001 2203 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0000 0000
0149 4108 6b7e a162 7603 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
014a 4108 6b7e a162 5001 0000 5101 0000 5201 0000 7703 0001 feff ff00 0000 0000 0000 0000 0000 0000
014b 4108 6b7e a162 7503 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
014c 4108 6b7e a162 2300 0000 2f01 0000 3301 0001 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0164 4108 747e a162 3300 0001 3701 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
0165 4108 747e a162 2d02 0000 7403 0001 a906 0000 c00d 0000 fdff ff00 feff ff00 0000 0000 0000 0000
0168 4308 747e a162 a005 0001 a105 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
015a 4608 747e a162 1104 0001 1204 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
01a6 4608 747e a162 f306 0000 f406 0001 f506 0000 fdff ff00 feff ff00 0000 0000 0000 0000 0000 0000
012c 4a08 447e a162 2e01 0000 6f24 0001 9f24 0000 a024 0000 dd24 0000 634a 0000 feff ff00 0000 0000
012e 4a08 249c 9a62 2e01 0001 3301 0000 b706 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
0164 4a08 6c7e a162 2f01 0001 3301 0000 620d 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
0196 4a08 6e7e a162 2300 0000 3301 0001 c701 0000 bd06 0000 feff ff00 0000 0000 0000 0000 0000 0000
0197 4a08 6e7e a162 2e01 0000 b806 0000 b906 0001 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
019a 4a10 727e a162 3130 2e31 3132 2e31 362e 3132 3700 0000 0000 0000 0000 0000 0000 0000 0000 0000
019b 4a10 727e a162 3235 352e 3235 352e 3235 352e 3000 0000 0000 0000 0000 0000 0000 0000 0000 0000
019c 4a10 727e a162 3130 2e31 3132 2e31 362e 3100 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
019d 4a10 727e a162 3130 2e31 3132 2e31 362e 3100 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
0000 0000


534d 4100 0004 02a0 0000 0001 03e6 0010 6065
f9a0 1234 5737 4321 00a1 9901 f6a2 2fb3 0001 0000 0300 3400 0102 8051 1800 0000 2f00 0000

01aa 4a08 547e a162 3301 0001 b706 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01b7 4a10 6c7e a162 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01b8 4a10 6c7e a162 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01b9 4a10 6c7e a162 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01ba 4a10 6c7e a162 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01bb 4a08 6c7e a162 260d 0001 270d 0000 280d 0000 290d 0000 feff ff00 0000 0000 0000 0000 0000 0000
01bc 4a08 727e a162 2f01 0001 3301 0000 bd06 0000 5208 0000 fd0c 0000 620d 0000 feff ff00 0000 0000
011e 4b08 747e a162 2f01 0001 3301 0000 b706 0000 bd06 0000 f007 0000 f107 0000 f207 0000 f707 0000
011e 4b08 747e a162 2508 0000 5208 0000 6c08 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
0127 5200 747e a162 0000 0000 0000 0000 321e 0000 321e 0000 a00f 0000 a00f 0000 ffff ffff ffff ffff
0128 5240 747e a162 0000 0000 0000 0000 321e 0000 321e 0000 0000 0080 0000 0080 0000 0080 0000 0080
0129 5200 747e a162 0000 0000 0000 0000 1027 0000 1027 0000 ffff ffff ffff ffff ffff ffff ffff ffff
012a 5208 747e a162 1104 0000 1204 0000 fdff ff01 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
012f 5208 747e a162 2f01 0000 3401 0001 2203 0000 1f0d 0000 fdff ff00 feff ff00 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0000 0000


534d 4100 0004 02a0 0000 0001 03e6 0010 6065
f9a0 1234 5737 4321 00a1 9901 f6a2 2fb3 0001 0000 0200 3400 0102 8051 3000 0000 4700 0000

0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000

534d 4100 0004 02a0 0000 0001 03e6 0010 6065
f9a0 1234 5737 4321 00a1 9901 f6a2 2fb3 0001 0000 0100 3400 0102 8051 4800 0000 5f00 0000

0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000


534d 4100 0004 02a0 0000 0001 0206 0010 6065
81a0 1234 5737 4321 00a1 9901 f6a2 2fb3 0001 0000 0000 3400 0102 8051 6000 0000 6b00 0000

0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0125 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0126 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0126 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0126 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0126 6508 249c 9a62 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
013a 6508 249c 9a62 2e01 0001 3301 0000 c701 0000 2203 0000 feff ff00 0000 0000 0000 0000 0000 0000
011e 6708 747e a162 1b00 0000 3201 0000 3901 0000 4d01 0000 b601 0000 af04 0000 561d 0001 591d 0000
011e 6708 747e a162 5a1d 0000 5d1d 0000 5e1d 0000 631d 0000 671d 0000 6c1d 0000 6d1d 0000 701d 0000
011e 6708 747e a162 721d 0000 731d 0000 7d1d 0000 7e1d 0000 7f1d 0000 841d 0000 851d 0000 8d1d 0000
011e 6708 747e a162 8e1d 0000 8f1d 0000 901d 0000 911d 0000 951d 0000 961d 0000 fdff ff00 feff ff00
0000 0000

""")
//        print(data1.hexDump)
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )

        var packetcounter = 0
        while !binaryDecoder1.isAtEnd
        {
            let packet = try? SMAPacket(fromBinary:binaryDecoder1)
            print(packet)
            packetcounter += 1
        }
        XCTAssert(packetcounter == 5)
    }



}


/*




1800 0000 2f00 0000
01aa 4a08 0ed5 9462 3301 0001 b706 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01b7 4a10 37d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01b8 4a10 37d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01b9 4a10 37d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01ba 4a10 37d5 9462 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
01bb 4a08 37d5 9462 260d 0001 270d 0000 280d 0000 290d 0000 feff ff00 0000 0000 0000 0000 0000 0000
01bc 4a08 3ed5 9462 2f01 0001 3301 0000 bd06 0000 5208 0000 fd0c 0000 620d 0000 feff ff00 0000 0000
011e 4b08 40d5 9462 2f01 0001 3301 0000 b706 0000 bd06 0000 f007 0000 f107 0000 f207 0000 f707 0000
011e 4b08 40d5 9462 2508 0000 5208 0000 6c08 0000 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
0127 5200 3fd5 9462 0000 0000 0000 0000 321e 0000 321e 0000 a00f 0000 a00f 0000 ffff ffff ffff ffff
0128 5240 3fd5 9462 0000 0000 0000 0000 321e 0000 321e 0000 0000 0080 0000 0080 0000 0080 0000 0080
0129 5200 3fd5 9462 0000 0000 0000 0000 1027 0000 1027 0000 ffff ffff ffff ffff ffff ffff ffff ffff
012a 5208 3fd5 9462 1104 0000 1204 0000 fdff ff01 feff ff00 0000 0000 0000 0000 0000 0000 0000 0000
012f 5208 3fd5 9462 2f01 0000 3401 0001 2203 0000 1f0d 0000 fdff ff00 feff ff00 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000





3000 0000 4700 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000


4800 0000 5f00 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000
0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8465 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000 0124 6508 8565 9162 2300 0000 2f01 0001 3301 0000 c701 0000 feff ff00 0000 0000 0000 0000 0000 0000

*/
