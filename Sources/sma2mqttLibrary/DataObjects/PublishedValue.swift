//
//  PublishedValue.swift
//

import Foundation
import JLog

public struct PublishedValue: Encodable
{
    let objectID: String
    let values: [GetValuesResult.Value]
    let tagTranslator: SMATagTranslator

    var stringValue: String?
    {
        if values.count == 1,
           case let .stringValue(stringValue) = values.first
        {
            return stringValue
        }
        return nil
    }

    public func encode(to encoder: Encoder) throws
    {
        enum CodingKeys: String, CodingKey { case unit, value, scale, id, prio, write, event }
        var container = encoder.container(keyedBy: CodingKeys.self)

        let objectDefinition = tagTranslator.smaObjectDefinitions[objectID]
        let compacted = values.compactMap { $0 }

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
                if stringValues.count > 1
                {
                    try container.encode(stringValues, forKey: .value)
                }
                else
                {
                    try container.encode(stringValues.first, forKey: .value)
                }

            case .intValue:
                let decimalValues: [Decimal?] = values.map
                {
                    if case let .intValue(value) = $0,
                       let value
                    {
                        if let scale = objectDefinition?.Scale, scale != Decimal(1)
                        {
                            return Decimal(value) * scale
                        }
                        return Decimal(value)
                    }
                    return nil
                }
                if decimalValues.count > 1
                {
                    try container.encode(decimalValues, forKey: .value)
                }
                else
                {
                    try container.encode(decimalValues.first, forKey: .value)
                }
                if let unit = objectDefinition?.Unit
                {
                    let unitString = tagTranslator.translate(tag: unit)
                    try container.encode(unitString, forKey: .unit)
                }

            case let .tagValues(values):
                let translated = values.map { $0 == nil ? nil : tagTranslator.translate(tag: $0!) }

                if translated.count > 1
                {
                    try container.encode(translated, forKey: .value)
                }
                else
                {
                    try container.encode(translated.first, forKey: .value)
                }

            case nil: let value: Int? = nil; try container.encode(value, forKey: .value)
        }
    }
}
