//
//  SMANetPacketValue.swift
//
//
//  Created by Patrick Stein on 01.06.2022.
//
import Foundation
import BinaryCoder
import JLog


struct SMANetPacketValue:Encodable,Decodable
{
    let number:UInt8
    let code:UInt16
    let type:UInt8
    private let _time:UInt32

    var time:Date { Date(timeIntervalSince1970: Double(_time) ) }

    enum ValueType:UInt8
    {
        case uint       = 0x00
        case int        = 0x40
        case string     = 0x10
        case version    = 0x08
        case password   = 0x51


        case unknown    = 0x01
    }

    enum PacketValue:Encodable,Decodable
    {
        case uint([UInt32])
        case int([Int32])
        case string(String)
        case version([UInt16])
        case password(Data)
        case unknown(Data)
    }
    var value:PacketValue

    static var size:Int { 8 }
    var description:String { self.json }
}


extension SMANetPacketValue:BinaryDecodable
{
    init(fromBinary decoder: BinaryDecoder) throws
    {
        let startposition = decoder.position

        self.number = try decoder.decode(UInt8.self).littleEndian
        self.code   = try decoder.decode(UInt16.self).littleEndian
        self.type   = try decoder.decode(UInt8.self).littleEndian
        self._time  = try decoder.decode(UInt32.self).littleEndian

        assert(Self.size == decoder.position - startposition)

        let valuetype = ValueType(rawValue: type) ?? .unknown

        switch valuetype
        {
            case .uint:     var values = [UInt32]()
                            while !decoder.isAtEnd
                            {
                                let value = try decoder.decode(UInt32.self)

                                values.append(value)
                            }
                            value = .uint(values)

            case .int:      var values = [Int32]()
                            while !decoder.isAtEnd
                            {
                                let value = try decoder.decode(Int32.self)

                                values.append(value)
                            }
                            value = .int(values)

            case .string:   //assert(decoder.countToEnd >= 32 )
                            let data = try decoder.decode(Data.self,length: decoder.countToEnd)
                            let string = String(data: data, encoding: .ascii)!
                            value = .string(string)

            case .version:  var values = [UInt16]()

                            while !decoder.isAtEnd
                            {
                                let a = try decoder.decode(UInt16.self).littleEndian
                                let b = try decoder.decode(UInt16.self).littleEndian

                                if a == 0xFFFE && b == 0x00FF
                                {
                                    break
                                }
                                values.append( a )
                            }
                            value = .version(values)

            case .password: if decoder.isAtEnd
                            {
                                value = .password(Data())
                            }
                            else
                            {
                                assert(decoder.countToEnd == 12 )
                                let data = try decoder.decode(Data.self,length: 12)
//                                let string = String(data: data, encoding: .utf8)!
                                value = .password(data)
                            }

            case .unknown:  let data = try decoder.decode(Data.self, length:decoder.countToEnd)
                            value = .unknown(data)
                            JLog.error("unkown: \( String(format:"no:0x%02x code:0x%04x type:0x%02x",number,code,type) )  time:\(time) data:\(data.hexDump) ")

        }
        JLog.trace("Got Value: \(value)")
    }

}

