//
//  SMANetPacketValue.swift
//

import BinaryCoder
import Foundation
import JLog

public struct SMANetPacketValue
{
    let number: UInt8
    let address: UInt16
    let type: UInt8
    let time: UInt32

    var date: Date { Date(timeIntervalSince1970: Double(time)) }

    enum ValueType: UInt8
    {
        case uint = 0x00
        case int = 0x40
        case string = 0x10
        case tags = 0x08
        case password = 0x51

        case unknown = 0x01
    }

    enum PacketValue: Codable
    {
        case uint([UInt32])
        case int([Int32])
        case string(String)
        case tags([UInt32])
        case password(Data)
        case unknown(Data)
    }

    var value: PacketValue

    static var size: Int { 8 }
    var description: String { json }
}

extension SMANetPacketValue: Codable
{
    public func encode(to encoder: Encoder) throws
    {
        let packetDefinition = SMANetPacketDefinition.definitions[address] ?? SMANetPacketDefinition.definitions[0]!

        enum CodingKeys: String, CodingKey
        {
            case address, topic, unit, title,

                 anumber, value, time, date, tags
        }
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(String(format: "0x%04x", address), forKey: .address)
        try container.encode(number, forKey: .anumber)
        try container.encode(time, forKey: .time)
        try container.encode(date.description, forKey: .date)
        try container.encode(packetDefinition.unit, forKey: .unit)
        try container.encode(packetDefinition.topic, forKey: .topic)
        try container.encode(packetDefinition.title, forKey: .title)

        let factor = packetDefinition.factor
        let hasFactor = packetDefinition.factor != nil && packetDefinition.factor! != 0 && packetDefinition.factor! != 1

        switch value
        {
            case let .uint(values):
                let toEncode = values.map { $0 == .max ? nil : (hasFactor ? Decimal($0) / factor! : Decimal($0)) }
                try container.encode(toEncode, forKey: CodingKeys.value)

            case let .int(values):
                let toEncode = values.map { $0 == .min ? nil : (hasFactor ? Decimal($0) / factor! : Decimal($0)) }
                try container.encode(toEncode, forKey: CodingKeys.value)

            case let .string(value): try container.encode(value, forKey: CodingKeys.value)
            case let .tags(values): try container.encode(values, forKey: CodingKeys.tags)
            case let .password(value): try container.encode(value, forKey: CodingKeys.value)
            case let .unknown(value): try container.encode(value, forKey: CodingKeys.value)
        }
    }
}

extension SMANetPacketValue: BinaryDecodable
{
    public init(fromBinary decoder: BinaryDecoder) throws
    {
        let startposition = decoder.position

        number = try decoder.decode(UInt8.self).littleEndian
        address = try decoder.decode(UInt16.self).littleEndian
        type = try decoder.decode(UInt8.self).littleEndian
        time = try decoder.decode(UInt32.self).littleEndian

        assert(Self.size == decoder.position - startposition)

        let valuetype = ValueType(rawValue: type) ?? .unknown

        switch valuetype
        {
            case .uint:
                var values = [UInt32]()
                while !decoder.isAtEnd
                {
                    let value = try decoder.decode(UInt32.self)

                    values.append(value)
                }
                value = .uint(values)

            case .int:
                var values = [Int32]()
                while !decoder.isAtEnd
                {
                    let value = try decoder.decode(Int32.self)

                    values.append(value)
                }
                value = .int(values)

            case .tags:
                var tags = [UInt32]()

                while !decoder.isAtEnd
                {
                    let a = try decoder.decode(UInt32.self).littleEndian

                    let lastPacket = 0x00FFFFE
                    if a == lastPacket { break }

                    let flag = a >> 24

                    if flag == 1
                    {
                        let tag = 0x00FF_FFFF & a
                        tags.append(tag)
                    }
                }
                value = .tags(tags)

            case .password:
                if decoder.isAtEnd
                {
                    value = .password(Data())
                }
                else
                {
                    assert(decoder.countToEnd == 12)
                    let data = try decoder.decode(Data.self, length: 12)
                    //                                let string = String(data: data, encoding: .utf8)!
                    value = .password(data)
                }

            case .string, .unknown:
                let data = try decoder.decode(Data.self, length: decoder.countToEnd)

                var ok = true
                let stringdata = data.filter
                {
                    ok = ok && ($0 != 0)
                    return ok
                }
                if let string = String(data: stringdata, encoding: .isoLatin1), !string.isEmpty
                {
                    value = .string(string)
                }
                else
                {
                    value = .unknown(data)
                    JLog.info("unkown: \(String(format: "no:0x%02x code:0x%04x type:0x%02x", number, address, type))  time:\(date) data:\(data.hexDump) ")
                }
        }
        JLog.trace("Got Value: \(json)")
    }
}
