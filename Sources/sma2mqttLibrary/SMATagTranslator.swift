//
//  File.swift
//
//
//  Created by Patrick Stein on 17.06.23.
//

import Foundation
import JLog

struct SMATagTranslator
{
    typealias ObjectIDString = String

    let smaObjectDefinitions: [ObjectIDString: SMADataObject]
    let translations: [Int: String]
    let objectsAndPaths: [ObjectIDString: String]

    static var shared: SMATagTranslator = .init(definitionData: nil, translationData: nil)

    init(definitionData: Data?, translationData: Data?)
    {
        if let definitionData,
           let dataObjectsString = String(data: definitionData, encoding: .utf8),
           let smaObjectDefinitions = try? SMADataObject.dataObjects(from: dataObjectsString)
        {
            self.smaObjectDefinitions = smaObjectDefinitions
        }
        else
        {
            smaObjectDefinitions = SMADataObject.defaultDataObjects
        }

        let translations: [Int: String]

        if let translationData,
           let rawTranslations = try? JSONDecoder().decode([String: String].self, from: translationData)
        {
            translations = Dictionary(uniqueKeysWithValues: rawTranslations.compactMap { if let key = Int($0.key) { return (key, $0.value) } else { return nil } })
        }
        else
        {
            translations = SMADataObject.defaultTranslations
        }
        self.translations = translations

        objectsAndPaths = Dictionary(uniqueKeysWithValues: smaObjectDefinitions.map
        {
            key, value in
            var tags = value.TagHier
            tags.append(value.TagId)
            return (key, tags.map { translations[$0] ?? "tag-\(String($0))" }
                .map { $0.lowercased().replacing(#/[\\\/\s]+/#) { _ in "-" } }
                .joined(separator: "/")
                .replacing(#/ /#) { _ in "-" })
        })

        JLog.trace("Objects and Paths:\(objectsAndPaths)")
    }

    func translate(tag: Int) -> String { translations[tag] ?? "tag-\(String(tag))" }

    func translate(tags: [Int?]) -> [String]
    {
        if let tags = tags as? [Int]
        {
            return tags.map { translate(tag: $0) }
        }
        return [String]()
    }

    var devicenameObjectIDs: [String] { objectsAndPaths.filter { $0.value.hasSuffix("type-label/device-name") }.map(\.key) }
}

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
