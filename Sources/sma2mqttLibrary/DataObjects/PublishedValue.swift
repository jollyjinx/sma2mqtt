//
//  PublishedValue.swift
//

import Foundation
import JLog

private final class PublishedValueShapeCache: @unchecked Sendable
{
    private let lock = NSLock()
    private var arrayShapeKeys = Set<String>()

    func rememberArrayShape(for key: String)
    {
        lock.lock()
        defer { lock.unlock() }
        arrayShapeKeys.insert(key)
    }

    func usesArrayShape(for key: String) -> Bool
    {
        lock.lock()
        defer { lock.unlock() }
        return arrayShapeKeys.contains(key)
    }
}

public struct PublishedValue: Encodable, Sendable
{
    private static let shapeCache = PublishedValueShapeCache()

    let objectID: String
    let values: [GetValuesResult.Value]
    let tagTranslator: SMATagTranslator
    let shapeKey: String

    var stringValue: String?
    {
        if values.count == 1,
           case let .stringValue(stringValue) = values.first
        {
            return stringValue
        }
        return nil
    }

    private var currentlyUsesArrayShape: Bool
    {
        if values.count > 1
        {
            return true
        }

        if case let .tagValues(tagValues)? = values.first
        {
            return tagValues.count > 1
        }

        return false
    }

    private var shouldEncodeAsArray: Bool
    {
        if currentlyUsesArrayShape
        {
            Self.shapeCache.rememberArrayShape(for: shapeKey)
            return true
        }

        return Self.shapeCache.usesArrayShape(for: shapeKey)
    }

    public func encode(to encoder: Encoder) throws
    {
        enum CodingKeys: String, CodingKey { case unit, value, scale, id, prio, write, event, date }
        var container = encoder.container(keyedBy: CodingKeys.self)

        let objectDefinition = tagTranslator.smaObjectDefinitions[objectID]
        let compacted = values.compactMap { $0 }
        let shouldEncodeAsArray = shouldEncodeAsArray

        if JLog.loglevel <= .debug
        {
            try container.encode(objectID, forKey: .id)
            try container.encode(Date(), forKey: .date)
        }

        switch compacted.first
        {
            case .stringValue:
                let stringValues: [String?] = values.map
                {
                    if case let .stringValue(value) = $0
                    {
                        return value
                    }
                    return nil
                }
                if shouldEncodeAsArray
                {
                    try container.encode(stringValues, forKey: .value)
                }
                else
                {
                    try container.encode(stringValues.first, forKey: .value)
                }

            case .intValue:
                var newscale = Decimal(1)

                if let unit = objectDefinition?.Unit
                {
                    var unitString = tagTranslator.translate(tag: unit)

                    switch unitString
                    {
                        case "Wh":
                            unitString = "kWh"
                            newscale = 0.001

                        default: break
                    }
                    try container.encode(unitString, forKey: .unit)
                }
                let decimalValues: [Decimal?] = values.map
                {
                    if case let .intValue(value) = $0,
                       let value
                    {
                        if let scale = objectDefinition?.Scale, scale != Decimal(1)
                        {
                            return Decimal(value) * scale * newscale
                        }
                        return Decimal(value) * newscale
                    }
                    return nil
                }
                if shouldEncodeAsArray
                {
                    try container.encode(decimalValues, forKey: .value)
                }
                else
                {
                    try container.encode(decimalValues.first, forKey: .value)
                }

            case let .tagValues(values):
                let translated = values.map { $0 == nil ? nil : tagTranslator.translate(tag: $0!) }

                if shouldEncodeAsArray
                {
                    try container.encode(translated, forKey: .value)
                }
                else
                {
                    try container.encode(translated.first, forKey: .value)
                }

            case nil:
                if shouldEncodeAsArray
                {
                    let value: [Int?] = [nil]
                    try container.encode(value, forKey: .value)
                }
                else
                {
                    let value: Int? = nil
                    try container.encode(value, forKey: .value)
                }
        }
    }
}
