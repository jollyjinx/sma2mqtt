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
    let objectsAndPaths: [ObjectIDString: SimpleObject]

    struct SimpleObject: Codable
    {
        let path: String
        let format: Int
    }

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

            let path = tags.map { translations[$0] ?? "tag-\(String($0))" }
                .map { $0.lowercased().replacing(#/[\\\/\s]+/#) { _ in "-" } }
                .joined(separator: "/")
                .replacing(#/ /#) { _ in "-" }

            let simpleObject = SimpleObject(path: path, format: value.DataFrmt)

            return (key, simpleObject)
        })

        JLog.trace("Objects and Paths:\(objectsAndPaths.json)")
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

    var devicenameObjectIDs: [String] { objectsAndPaths.filter { $0.value.path.hasSuffix("type-label/device-name") }.map(\.key) }
}
