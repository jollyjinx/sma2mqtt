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
        case uint       = 0
        case int        = 0x40
        case string     = 0x10
        case version    = 0x08
        case password   = 0x51
    }

    enum PacketValue:Encodable,Decodable
    {
        case uint([UInt32])
        case int([Int32])
        case string(String)
        case version([UInt16])
        case password(Data)
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


        repeat
        {
            let valuetype = ValueType(rawValue: type)!

            JLog.debug("pos:\(decoder.position - startposition) toEnd:\(decoder.countToEnd) Got Type: \(valuetype)")

            switch valuetype
            {
                case .uint:     fallthrough
                case .int:      assert(decoder.countToEnd >= 16 )

                                let a = try decoder.decode(Int32.self)
                                let b = try decoder.decode(Int32.self)

                                if b == 0
                                {
                                    value = .int([a])
                                    break
                                }

                                assert(decoder.countToEnd >= 16 )
                                let c = try decoder.decode(Int32.self)
                                let d = try decoder.decode(Int32.self)


                                try decoder.decode(Data.self,length: 32)

                                value = .int([])

                case .string:   assert(decoder.countToEnd >= 32 )
                                let data = try decoder.decode(Data.self,length: 32)
                                let string = String(data: data, encoding: .utf8)!
                                value = .string(string)

                case .version:  var values = [UInt16]()

                                let endposition = decoder.position + 32

                                repeat
                                {
                                    let a = try decoder.decode(UInt16.self).littleEndian
                                    let b = try decoder.decode(UInt16.self).littleEndian

                                    if a == 0xFFFE && b == 0x00FF
                                    {
                                        break
                                    }
                                    values.append( a )
                                }
                                while decoder.position < endposition
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
            }
            JLog.debug("Got Value: \(value)")
        }
        while !decoder.isAtEnd


    }

}

