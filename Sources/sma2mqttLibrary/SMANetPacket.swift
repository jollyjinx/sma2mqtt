//
//  SMANetPacketHeader.swift
//
//
//  Created by Patrick Stein on 01.06.2022.
//
import Foundation
import BinaryCoder
import JLog


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
        JLog.debug("")

        self.header = try decoder.decode(SMANetPacketHeader.self)

        if decoder.isAtEnd
        {
            return
        }

        while decoder.countToEnd >= SMANetPacketValue.size
        {
            let positionok = decoder.position

            do
            {
                let value = try decoder.decode(SMANetPacketValue.self)
                JLog.debug("command:\( String(format:"%4x",header.command) )  length:\(decoder.countToEnd) time:\(value.time) \(value.description)")
            }
            catch
            {
                decoder.position = positionok
                JLog.error("could not decode:\( Data(decoder.dataToEnd).dump )")
            }
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

    let quaterlength:UInt8
    let type:UInt8

    let sourceSystemId:UInt16
    let sourceSerial:UInt32

    let unknown1:UInt8
    let unknown2:UInt8

    let destinationSystemId:UInt16
    let destinationSerial:UInt32

    let unknown3:UInt16

    let response:UInt16

    let unknown4:UInt8
    let unknown5:UInt8

    private let _packetId:UInt16

    let unknown6:UInt16

    let command:UInt16

    // calculated
    var packetId: UInt16 { _packetId & 0x7FFF }
    var packetFlag: Bool { _packetId & 0x8000  != 0 }

    let valuecountAll:UInt32
    let valuecountDone:UInt32

    static var size:Int { 36 }
    private var followingdatasize:Int { ( Int(quaterlength) * 4 ) - Self.size }

    var valueCount:Int {
                            guard followingdatasize > 0 else { return 0 }

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

        guard Int(self.quaterlength) * 4 == (decoder.countToEnd + 1) else { throw SMANetPacketHeaderDecodingError.decoding("internal data error") }

        self.type           = try decoder.decode(UInt8.self).littleEndian

        self.sourceSystemId = try decoder.decode(UInt16.self).littleEndian
        self.sourceSerial   = try decoder.decode(UInt32.self).littleEndian

        self.unknown1       = try decoder.decode(UInt8.self).littleEndian
        self.unknown2       = try decoder.decode(UInt8.self).littleEndian

        self.destinationSystemId    = try decoder.decode(UInt16.self).littleEndian
        self.destinationSerial      = try decoder.decode(UInt32.self).littleEndian

        self.unknown3       = try decoder.decode(UInt16.self).littleEndian

        self.response       = try decoder.decode(UInt16.self).littleEndian

        self.unknown4       = try decoder.decode(UInt8.self).littleEndian
        self.unknown5       = try decoder.decode(UInt8.self).littleEndian

        self._packetId      = try decoder.decode(UInt16.self).littleEndian

        self.unknown6       = try decoder.decode(UInt16.self).littleEndian

        self.command        = try decoder.decode(UInt16.self).littleEndian

        if decoder.isAtEnd
        {
            self.valuecountAll   = 0
            self.valuecountDone  = 0
        }
        else
        {
            self.valuecountAll   = try decoder.decode(UInt32.self)
            self.valuecountDone  = try decoder.decode(UInt32.self)
        }

        assert(Self.size == decoder.position - startposition)
    }
}


