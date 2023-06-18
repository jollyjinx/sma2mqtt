//
//  ObisDefinition.swift
//
//
//  Created by Patrick Stein on 29.08.21.
//

import Foundation
import JLog

struct ObisDefinition: Encodable, Decodable
{
    enum ObisDefinitionType: String, Encodable, Decodable
    {
        case version = "softwareversion"
        case ipv4address

        case uint32
        case int32
        case uint64
    }

    let id: String

    let type: ObisDefinitionType
    let factor: Decimal?
    let unit: String
    let topic: String
    let mqtt: ObisValue.MQTTVisibilty
    let title: String
}

extension ObisDefinition
{
    static let obisDefinitions: [String: ObisDefinition] = {
        if let url = Bundle.module.url(forResource: "obisdefinition", withExtension: "json")
        {
            if let jsonData = try? Data(contentsOf: url), let obisDefinitions = try? JSONDecoder().decode([ObisDefinition].self, from: jsonData)
            {
                return Dictionary(uniqueKeysWithValues: obisDefinitions.map { ($0.id, $0) })
            }
            JLog.error("Could not decode obisdefintion resource file")
            return [String: ObisDefinition]()
        }
        JLog.error("Could not find obisdefintion resource file")
        return [String: ObisDefinition]()
    }()
}
