//
//  SMANetPacket.swift
//

import BinaryCoder
import Foundation
import JLog

public struct SMANetPacket: Codable, Sendable
{
    let header: SMANetPacketHeader
    let valuesheader: [Int]
    let values: [SMANetPacketValue]
    let directvalue: String?
}

extension SMANetPacket: BinaryDecodable
{
    public init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.trace("")

        header = try decoder.decode(SMANetPacketHeader.self)
        var valuesheader = [Int]()
        var values = [SMANetPacketValue]()
        var directvalue: String? = nil

        if decoder.isAtEnd
        {
            self.valuesheader = valuesheader
            self.values = values
            self.directvalue = nil
            return
        }

        let valuesize: Int

        switch header.u8valuestype
        {
            case 0x01, 0x04:
                guard decoder.countToEnd >= 4 else { throw PacketError.decoding("Valueheader too short header:\(header) toEnd:\(decoder.countToEnd)") }
                let startvalue = try Int(decoder.decode(UInt32.self).littleEndian)
                valuesheader.append(startvalue)
                valuesize = header.u8valuestype == 0x01 ? 16 : decoder.countToEnd

            case 0x02:
                guard decoder.countToEnd >= 8 else { throw PacketError.decoding("Valueheader too short header:\(header) toEnd:\(decoder.countToEnd)") }
                let startvalue = try Int(decoder.decode(UInt32.self).littleEndian)
                let endvalue = try Int(decoder.decode(UInt32.self).littleEndian)

                valuesheader.append(contentsOf: [startvalue, endvalue])
                let valuecount = endvalue - startvalue + 1
                valuesize = valuecount > 0 ? decoder.countToEnd / valuecount : 0
                guard decoder.countToEnd == valuecount * valuesize
                else
                {
                    throw PacketError.decoding("valuecount wrong: header:\(header) valuecount:\(valuecount) toEnd:\(decoder.countToEnd)")
                }

            case 0x0C:
                valuesize = 0
                if decoder.countToEnd > 0
                {
                    var ok = true
                    let data = try decoder.decode(Data.self, length: decoder.countToEnd)
                        .filter
                        {
                            ok = ok && ($0 != 0)
                            return ok
                        }
                    directvalue = String(data: data, encoding: .isoLatin1)!
                }

            case 0x00:
                valuesize = decoder.countToEnd

            default:
                throw PacketError.decoding("unknown valuestype:\(header.u8valuestype) header:\(header) toEnd:\(decoder.countToEnd)")
        }

        if valuesize > 0
        {
            while !decoder.isAtEnd //  0...<self.header.valueCount
            {
                let valueData = try decoder.decode(Data.self, length: valuesize)
                let valueDecoder = BinaryDecoder(data: [UInt8](valueData))

                let value = try valueDecoder.decode(SMANetPacketValue.self)
                values.append(value)
            }
        }
        assert(decoder.isAtEnd)
        self.valuesheader = valuesheader
        self.values = values
        self.directvalue = directvalue
    }
}
