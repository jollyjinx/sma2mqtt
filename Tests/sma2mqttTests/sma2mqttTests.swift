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



final class sma2mqttTests: XCTestCase
{
    func testExample() throws
    {
        JLog.loglevel = .trace
        
        let data  = hex(from:"534d4100 0004 02a0 00000001 0046 0010 6065 11 e0 07050102030400a19901f6 a22fb3 0001 0000 0000f1b10102005400000000010000000101260068d50f613b975300000000000122260068d50f61b81f00000000000000000000")
        let binaryDecoder = BinaryDecoder(data: [UInt8](data) )

        
        let packet = try? SMAMulticastPacket(fromBinary:binaryDecoder)

        JLog.debug("Packet:\(packet)")

        XCTAssert(true)
    }
}
