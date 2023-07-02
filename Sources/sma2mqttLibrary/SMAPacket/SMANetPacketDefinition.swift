//
//  SMANetPacketDefinition.swift
//

import Foundation
import JLog

struct SMANetPacketDefinition: Codable
{
    let address: String

    let topic: String
    let unit: String
    let factor: Decimal?

    let title: String
}

extension SMANetPacketDefinition
{
    static let definitions: [UInt16: SMANetPacketDefinition] = {
        if let url = Bundle.module.url(forResource: "SMANetPacketDefinitions", withExtension: "json")
        {
            if let jsonData = try? Data(contentsOf: url), let netpacketDefinitions = try? JSONDecoder().decode([SMANetPacketDefinition].self, from: jsonData)
            {
                return Dictionary(uniqueKeysWithValues: netpacketDefinitions.map { (UInt16(Int($0.address.dropFirst(2), radix: 16)!), $0) })
            }
            JLog.error("Could not decode resource file \(url)")
            return [UInt16: SMANetPacketDefinition]()
        }
        JLog.error("Could not find SMANetPacketDefinitions.json resource file")
        return [UInt16: SMANetPacketDefinition]()
    }()
}
