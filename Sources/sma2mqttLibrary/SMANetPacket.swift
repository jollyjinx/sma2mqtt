//
//  SMANetPacketHeader.swift
//
//
//  Created by Patrick Stein on 01.06.2022.
//
import Foundation
import BinaryCoder
import JLog
import AppKit


struct SMANetPacket:Encodable,Decodable
{
    let header:SMANetPacketHeader
    var values = [SMANetPacketValue]()
}

extension SMANetPacket:BinaryDecodable
{
    enum SMANetPacketDecodingError: Error
    {
        case decoding(String)
    }
    init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.trace("")

        self.header = try decoder.decode(SMANetPacketHeader.self)

        if decoder.isAtEnd
        {
            return
        }

        let valueSize = self.header.valueSize

        while !decoder.isAtEnd //  0...<self.header.valueCount
        {
            let valueData = try decoder.decode(Data.self,length: valueSize)
            let valueDecoder = BinaryDecoder(data: [UInt8](valueData))

            let value = try valueDecoder.decode(SMANetPacketValue.self)
            values.append(value)
        }
        assert(decoder.isAtEnd)
    }
}


struct SMANetPacketHeader:BinaryDecodable,Encodable,Decodable
{
    enum SMANetPacketHeaderDecodingError: Error
    {
        case decoding(String)
    }

    let quaterlength:UInt8          // 0
    let type:UInt8                  // 1

    let sourceSystemId:UInt16       // 2-3
    let sourceSerial:UInt32         // 4-7

    let unknown1:UInt8              // 8    always 0x00
    let unknown2:UInt8              // 9    0x01 0xa1 0xe1

    let destinationSystemId:UInt16  // 10, 11
    let destinationSerial:UInt32    // 12-15

    let unknown3:UInt16             // 16-17    0x100
    let response:UInt16             // 18-19    0x00 , 0x14, 0x15 

    let remainingpackets:UInt16     // 20
    private let _packetId:UInt16

    let unknown6:UInt16

    let command:UInt16

    // calculated
    var packetId: UInt16 { _packetId & 0x7FFF }
    var firstpacket: Bool { _packetId & 0x8000  != 0 }

    let valuecountDone:UInt32
    let valuecountAll:UInt32

    static var size:Int { 36 }
    private var followingdatasize:Int { ( Int(quaterlength) * 4 ) - Self.size }

    var valueCount:Int {
                            guard followingdatasize > 0 else { return 0 }
                            guard followingdatasize > 28 else { return 1 }
                            return Int(self.valuecountAll) - Int(self.valuecountDone) + 1
                        }
    var valueSize:Int {
                        guard valueCount > 0 else { return 0 }
                        return followingdatasize / valueCount
                    }

    var description:String { self.json }


    init(fromBinary decoder: BinaryDecoder) throws
    {
        let startposition = decoder.position

        self.quaterlength   = try decoder.decode(UInt8.self).littleEndian

        guard Int(self.quaterlength) * 4 == (decoder.countToEnd + 1) else { throw SMANetPacketHeaderDecodingError.decoding("quaterlength \(self.quaterlength) != countToEnd \(decoder.countToEnd)") }

        self.type           = try decoder.decode(UInt8.self).littleEndian

        self.sourceSystemId = try decoder.decode(UInt16.self).littleEndian
        self.sourceSerial   = try decoder.decode(UInt32.self).littleEndian

        self.unknown1       = try decoder.decode(UInt8.self).littleEndian
        self.unknown2       = try decoder.decode(UInt8.self).littleEndian

        self.destinationSystemId    = try decoder.decode(UInt16.self).littleEndian
        self.destinationSerial      = try decoder.decode(UInt32.self).littleEndian

        self.unknown3       = try decoder.decode(UInt16.self).littleEndian

        self.response       = try decoder.decode(UInt16.self).littleEndian

        self.remainingpackets   = try decoder.decode(UInt16.self).littleEndian

        self._packetId      = try decoder.decode(UInt16.self).littleEndian

        self.unknown6       = try decoder.decode(UInt16.self).littleEndian

        self.command        = try decoder.decode(UInt16.self).littleEndian

        if decoder.isAtEnd
        {
            self.valuecountDone  = 0
            self.valuecountAll  = 0
        }
        else
        {
            self.valuecountDone  = try decoder.decode(UInt32.self)
            self.valuecountAll   = try decoder.decode(UInt32.self)
        }

        assert(Self.size == decoder.position - startposition)
    }
}


