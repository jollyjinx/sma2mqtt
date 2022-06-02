import XCTest
import class Foundation.Bundle

@testable import JLog
@testable import BinaryCoder
@testable import sma2mqttLibrary

func hex(from string: String) -> Data
{
    let stringWithoutSpaces = string.replacingOccurrences(of:" ", with:"")

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

    init(data: Data,splitData:Data) {
        self.data = data
        self.splitData = splitData
        self.index = data.startIndex
        print("init")
    }

    mutating func next() -> Data?
    {
//        print("\(#line) index:\(index)")

        guard self.index != self.data.endIndex else { return nil }

//        print("\(#line) index:\(index)")

        guard let range = data[index ..< data.endIndex].range(of: splitData)
        else
        {
//        print("\(#line) index:\(index)")
            if index == data.startIndex
            {
                index = data.endIndex
                return nil
            }

            let returnData = data[ (index-splitData.count) ..< data.endIndex]
            index = data.endIndex
            return returnData
        }
//        print("\(#line) index:\(index) range:\(range) ")

        if index == data.startIndex
        {
//        print("\(#line) index:\(index) range:\(range) ")
            index = range.endIndex
            return next()
        }
//        print("\(#line) index:\(index) range:\(range) ")

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
        while let r = self[pos...].range(of: separator)
        {
            // Append if non-empty:
            if r.lowerBound > pos
            {
                chunks.append(self[(pos - separator.count)..<r.lowerBound])
            }
            // Update current position:
            pos = r.upperBound
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
        JLog.loglevel = .debug

        let data1  = hex(from:"534d 4100 0004 02a0 0000 0001 003a 0010 6065 0ea0 ffff ffff ffff 0001 1234 25f6 4321 0001 0000 0000 0180 0c04 fdff 0700 0000 8403 0000 4c20 cb51 0000 0000 dbb8 f4e9 fae7 ddfb edfa 8888 0000")
        let binaryDecoder1 = BinaryDecoder(data: [UInt8](data1) )

        let packet1 = try? SMAPacket(fromBinary:binaryDecoder1)

        assert(binaryDecoder1.isAtEnd)

        let data = try Data(contentsOf: URL(fileURLWithPath:"/Users/jolly/Documents/GitHub/sma2mqtt/Temp/Reverseengineering/sb4.out"),options:.mappedRead)
        let separator = Data(bytes: [0x53, 0x4d, 0x41, 0x00] )

        var counter = 0
        let splitter = DataSplitter(data: data, splitData: separator)
        for chunk in splitter
        {
//            counter += 1
            let binaryDecoder = BinaryDecoder(data: [UInt8](chunk) )
//            print(counter)
            let packet = try? SMAPacket(fromBinary:binaryDecoder)

//            JLog.debug("Packet:\(packet)")
        }

        XCTAssert(true)
    }

    
}
