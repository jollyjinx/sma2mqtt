//
//  ObisValue.swift
//

import BinaryCoder
import Foundation
import JLog

public enum ObisType: Encodable, Decodable, Sendable
{
    case string(String)
    case uint(UInt64)
    case int(Int64)
}

public struct ObisValue: Decodable, Sendable
{
    let id: String
    let value: ObisType

    public var includeTopicInJSON = false
    public var topic: String { ObisDefinition.obisDefinitions[id]?.topic ?? "id/\(id)" }

    public enum MQTTVisibilty: String, Encodable, Decodable, Sendable { case invisible, visible, retained }

    public var mqtt: MQTTVisibilty { ObisDefinition.obisDefinitions[id]?.mqtt ?? .invisible }
}

extension ObisValue: Encodable
{
    public func encode(to encoder: Encoder) throws
    {
        let obisDefinition = ObisDefinition.obisDefinitions[id]!

        enum CodingKeys: String, CodingKey { case id, unit, title, value, topic }
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(obisDefinition.id, forKey: .id)
        try container.encode(obisDefinition.unit, forKey: .unit)
        try container.encode(obisDefinition.title, forKey: .title)

        if includeTopicInJSON { try container.encode(obisDefinition.topic, forKey: .topic) }

        let factor = obisDefinition.factor
        let hasFactor = obisDefinition.factor != nil && obisDefinition.factor! != 0 && obisDefinition.factor! != 1

        switch value
        {
            case let .string(value): try container.encode(value, forKey: .value)
            case let .uint(value):
                if value == UInt64.max
                {
                    let string: String? = nil
                    try container.encode(string, forKey: .value)
                }
                else
                {
                    try container.encode(hasFactor ? Decimal(value) / factor! : Decimal(value), forKey: .value)
                }
            case let .int(value):
                if value == UInt64.min
                {
                    let string: String? = nil
                    try container.encode(string, forKey: .value)
                }
                else
                {
                    try container.encode(hasFactor ? Decimal(value) / factor! : Decimal(value), forKey: .value)
                }
        }
    }
}

extension ObisValue: BinaryDecodable
{
    public init(fromBinary decoder: BinaryDecoder) throws
    {
        JLog.trace("Decoding ObisValue")

        let a: UInt8 = try decoder.decode(UInt8.self)
        let b: UInt8 = try decoder.decode(UInt8.self)
        let c: UInt8 = try decoder.decode(UInt8.self)
        let d: UInt8 = try decoder.decode(UInt8.self)

        let id = "\(a != 0 ? a : 1):\(b).\(c).\(d)"

        JLog.trace("Decoding Obis a:\(a) Id:\(id)")

        let value: ObisType

        if let obisDefinition = ObisDefinition.obisDefinitions[id]
        {
            switch obisDefinition.type
            {
                case .version:
                    let intValue = try decoder.decode(Int32.self).bigEndian
                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format: "%08x", intValue))")
                    value = .string("major:\(intValue >> 24) minor:\(intValue >> 16 & 0xFF) build:\(intValue >> 8 & 0xFF) revision:\(String(format: "%c", intValue & 0xFF))")

                case .ipv4address:
                    let intValue = try decoder.decode(UInt32.self).bigEndian
                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format: "%08x", intValue))")
                    value = .string(intValue.ipv4String)

                case .uint32:
                    let intValue = try decoder.decode(UInt32.self).bigEndian
                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format: "%08x", intValue))")
                    value = .uint(intValue == UInt32.max ? UInt64.max : UInt64(intValue))

                case .int32:
                    let intValue = try decoder.decode(Int32.self).bigEndian
                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format: "%08x", intValue))")
                    value = .int(intValue == UInt32.min ? Int64.min : Int64(intValue))

                case .uint64:
                    let intValue = try decoder.decode(UInt64.self).bigEndian
                    JLog.trace("name: \(obisDefinition.topic) value:\(String(format: "%16x", intValue))")
                    value = .uint(intValue)
            }
        }
        else
        {
            JLog.error("Unknown Obis Id: \(id)")
            throw BinaryDecoder.Error.typeNotConformingToBinaryDecodable(ObisValue.self)
        }
        JLog.trace("Decoded corretly \(id) \(value)")

        self.id = id
        self.value = value
    }
}
