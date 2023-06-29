//
//  SMANetPacketHeader.swift
//

import BinaryCoder
import Foundation
import JLog

struct SMANetPacketHeader: Codable
{
//    let quaterlength: UInt8 // 0
    let u8type: UInt8 // 1

    let destinationSystemId: UInt16 // 2,3
    let destinationSerial: UInt32 // 4-7

    let u8padding8: UInt8 // 8    always 0x00
    let u8p9: UInt8 // 9    0x01 0xa1 0xe1

    let sourceSystemId: UInt16 // 10, 11
    let sourceSerial: UInt32 // 12-15

    let u8padding16: UInt8 // 16    0x100
    let u8jobid: UInt8 // 17

    let u16result: UInt16 // 18-19    0x00 , 0x14, 0x15

    let u16remainingpackets: UInt16 // 20-21

    private let _packetId: UInt16 // 22-23

    let u8unknown6: UInt8 // 24
    let u8valuestype: UInt8 // 25
    let u16command: UInt16 // 26-27
}

extension SMANetPacketHeader // calculated
{
    var packetId: UInt16 { _packetId & 0x7FFF }
    var direction: Bool { _packetId & 0x8000 != 0 }
    static var size: Int { 28 }
//    private var followingdatasize: Int { (Int(quaterlength) * 4) - Self.size }
}

extension SMANetPacketHeader: BinaryDecodable
{
    enum SMANetPacketHeaderDecodingError: Error { case decoding(String) }

    //    var description:String { self.json }

    init(fromBinary decoder: BinaryDecoder) throws
    {
        let startposition = decoder.position

        let quaterlength = try decoder.decode(UInt8.self).littleEndian

        guard Int(quaterlength) * 4 == (decoder.countToEnd + 1) else { throw SMANetPacketHeaderDecodingError.decoding("quaterlength \(quaterlength) != countToEnd \(decoder.countToEnd)") }

        u8type = try decoder.decode(UInt8.self).littleEndian

        destinationSystemId = try decoder.decode(UInt16.self).littleEndian
        destinationSerial = try decoder.decode(UInt32.self).littleEndian
        u8padding8 = try decoder.decode(UInt8.self).littleEndian

        u8p9 = try decoder.decode(UInt8.self).littleEndian

        sourceSystemId = try decoder.decode(UInt16.self).littleEndian
        sourceSerial = try decoder.decode(UInt32.self).littleEndian
        u8padding16 = try decoder.decode(UInt8.self).littleEndian

        u8jobid = try decoder.decode(UInt8.self).littleEndian

        u16result = try decoder.decode(UInt16.self).littleEndian

        u16remainingpackets = try decoder.decode(UInt16.self).littleEndian

        _packetId = try decoder.decode(UInt16.self).littleEndian

        u8unknown6 = try decoder.decode(UInt8.self).littleEndian
        u8valuestype = try decoder.decode(UInt8.self).littleEndian

        u16command = try decoder.decode(UInt16.self).littleEndian

        assert(Self.size == decoder.position - startposition)
    }
}
