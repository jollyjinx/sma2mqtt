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
    let valuesheader:[Int]
    let values:[SMANetPacketValue]
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

        self.header         = try decoder.decode(SMANetPacketHeader.self)
        var valuesheader    = [Int]()
        var values          = [SMANetPacketValue]()

        if decoder.isAtEnd
        {
            self.valuesheader = valuesheader
            self.values = values
            return
        }

        let valuesize:Int

        switch header.valuestype
        {
            case 0x01:  fallthrough
            case 0x04:  guard decoder.countToEnd >= 4 else { throw SMANetPacketDecodingError.decoding("Valueheader too short header:\(header) toEnd:\(decoder.countToEnd)") }
                        let startvalue = try Int(decoder.decode(UInt32.self).littleEndian)
                        valuesheader.append(startvalue)
                        valuesize = header.valuestype == 0x01 ? 16 : decoder.countToEnd

            case 0x02:  guard decoder.countToEnd >= 8 else { throw SMANetPacketDecodingError.decoding("Valueheader too short header:\(header) toEnd:\(decoder.countToEnd)") }
                        let startvalue = try Int(decoder.decode(UInt32.self).littleEndian)
                        let endvalue   = try Int(decoder.decode(UInt32.self).littleEndian)

                        valuesheader.append(contentsOf:[startvalue,endvalue])
                        let valuecount = endvalue - startvalue + 1
                        valuesize = valuecount > 0 ? decoder.countToEnd / valuecount : 0
                        guard decoder.countToEnd == valuecount * valuesize else { throw SMANetPacketDecodingError.decoding("valuecount wrong: header:\(header) valuecount:\(valuecount) toEnd:\(decoder.countToEnd)") }

            case 0x00:  valuesize = decoder.countToEnd // keepalive packet
            default:    throw SMANetPacketDecodingError.decoding("unknown valuestype:\(header.valuestype) header:\(header) toEnd:\(decoder.countToEnd)") 
        }

        if valuesize > 0
        {
            while !decoder.isAtEnd //  0...<self.header.valueCount
            {
                let valueData = try decoder.decode(Data.self,length: valuesize)
                let valueDecoder = BinaryDecoder(data: [UInt8](valueData))

                let value = try valueDecoder.decode(SMANetPacketValue.self)
                values.append(value)
            }
        }
        assert(decoder.isAtEnd)
        self.valuesheader = valuesheader
        self.values = values
    }
}


struct SMANetPacketHeader:Encodable,Decodable
{
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

    let remainingpackets:UInt16     // 20-21

    private let _packetId:UInt16    // 22-23

    let unknown6:UInt8              // 24
    let valuestype:UInt8            // 25
    let command:UInt16              // 26-27
}

extension SMANetPacketHeader     // calculated
{
    var packetId: UInt16    { _packetId & 0x7FFF }
    var direction: Bool     { _packetId & 0x8000  != 0 }
    static  var size:Int    { 28 }
    private var followingdatasize:Int { ( Int(quaterlength) * 4 ) - Self.size }
}


extension SMANetPacketHeader:BinaryDecodable
{
    enum SMANetPacketHeaderDecodingError: Error
    {
        case decoding(String)
    }
//    var description:String { self.json }


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

        self.unknown6       = try decoder.decode(UInt8.self).littleEndian
        self.valuestype     = try decoder.decode(UInt8.self).littleEndian

        self.command        = try decoder.decode(UInt16.self).littleEndian

        assert(Self.size == decoder.position - startposition)
    }
}


