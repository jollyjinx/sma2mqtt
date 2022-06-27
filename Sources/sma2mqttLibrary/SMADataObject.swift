//
//  File.swift
//  
//
//  Created by Patrick Stein on 26.06.22.
//

import Foundation
import Regex
import JLog

struct SMADataObject
{
    let object:Int
    let lri:Int

    let Prio:Int
    let TagId:Int

    let TagIdEventMsg:Int?

    let Unit:Int?
    let DataFrmt:Int
    let Scale:Double?
    let Typ:Int

    let WriteLevel:Int
    let GridGuard:Bool
    let TagHier:[Int]

    let Min:Bool
    let Max:Bool
    let Sum:Bool
    let Avg:Bool
    let Cnt:Bool
    let MinD:Bool
    let MaxD:Bool
    let SumD:Bool

}

extension SMADataObject // Descriptions
{
    var id:String           { "\( String(object,radix: 16) )_\( String(lri,radix: 16) )" }
    var tagName:String      { Self.translation[TagId] ?? "tag-\( Int(TagId) )" }
    var eventName:String    { TagIdEventMsg != nil ? Self.translation[TagIdEventMsg!] ?? "event-\( Int(TagIdEventMsg!) )" :  "" }
    var tagHierachy:String  { TagHier.map{ Self.translation[$0] ?? "tag-\( Int($0) )" }.joined(separator:".") }
    var unitName:String     { Unit != nil ? Self.translation[Unit!] ?? "unit-\( Int(Unit!) )"  : "" }

    var description:String  { "\(id): \(tagName) \(eventName) \(tagHierachy) \(unitName) \(self.json)" }
}

extension SMADataObject:Decodable,Encodable
{
    private enum CodingKeys : String, CodingKey {
        case object,lri,Prio,TagId,TagIdEventMsg,Unit,DataFrmt,Scale,Typ,WriteLevel,GridGuard,TagHier,Min,Max,Sum,Avg,Cnt,MinD,MaxD,SumD
    }

    init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let objectString = try values.decode(String.self, forKey: .object)
        guard let object = Int(objectString , radix: 16) else { throw DecodingError.dataCorruptedError(forKey: .object, in: values, debugDescription: "could not decode hex string") }
        self.object = object

        let lriString = try values.decode(String.self, forKey: .lri)
        guard let lri = Int(lriString , radix: 16) else { throw DecodingError.dataCorruptedError(forKey: .lri, in: values, debugDescription: "could not decode hex string") }
        self.lri = lri

        Prio        = try values.decode(Int.self, forKey: .Prio)
        TagId       = try values.decode(Int.self, forKey: .TagId)
        TagIdEventMsg = try values.decodeIfPresent(Int.self, forKey: .TagIdEventMsg)
        Unit        = try values.decodeIfPresent(Int.self, forKey: .Unit)
        DataFrmt    = try values.decode(Int.self, forKey: .DataFrmt)
        Scale       = try values.decodeIfPresent(Double.self, forKey: .Scale)

        Typ         = try values.decode(Int.self, forKey: .Typ)
        WriteLevel  = try values.decode(Int.self, forKey: .WriteLevel)
        GridGuard   = try values.decodeIfPresent(Bool.self, forKey: .GridGuard) ?? false
        TagHier     = try values.decode([Int].self, forKey: .TagHier)

        Min    = try values.decodeIfPresent(Bool.self, forKey: .Min)        ?? false
        Max    = try values.decodeIfPresent(Bool.self, forKey: .Max)        ?? false
        Sum    = try values.decodeIfPresent(Bool.self, forKey: .Sum)        ?? false
        Avg    = try values.decodeIfPresent(Bool.self, forKey: .Avg)        ?? false
        Cnt    = try values.decodeIfPresent(Bool.self, forKey: .Cnt)        ?? false
        MinD   = try values.decodeIfPresent(Bool.self, forKey: .MinD)       ?? false
        MaxD   = try values.decodeIfPresent(Bool.self, forKey: .MaxD)       ?? false
        SumD   = try values.decodeIfPresent(Bool.self, forKey: .SumD)       ?? false

    }

}


extension SMADataObject
{
    static let translation:[Int:String] =
    {
        guard let url = Bundle.module.url(forResource: "sma.data.Translation_Names", withExtension: "json")
        else
        {
            JLog.error("Could not find Translation_Names resource file")
            return [Int:String]()
        }

        do
        {
            let jsonData = try Data(contentsOf: url)
            let translations = try JSONDecoder().decode([String:String?].self, from: jsonData)

            return Dictionary(uniqueKeysWithValues: translations.compactMap { guard let intvalue = Int($0) else { return nil }
                                                                                guard let stringvalue = $1 else { return nil }
                                                                              return (intvalue , stringvalue)
                                                                             } )
        }
        catch
        {
            JLog.error("Could not create Translation_Names Objects \(error)")
        }
        return [Int:String]()
    }()
}

extension SMADataObject
{
    static let dataObjects:[String:SMADataObject] =
    {
        guard let url = Bundle.module.url(forResource: "sma.data.objectMetaData", withExtension: "json")
        else
        {
            JLog.error("Could not find objectMetaData resource file")
            return [String:SMADataObject]()
        }

        do
        {
            let jsonString = try String(contentsOf: url)
            let regexString = "(\"([\\da-f]{4})_([\\da-f]{8})\": \\{)"
            let regex = regexString.r
            let replaced = regex?.replaceAll(in: jsonString, with: "$0 \"object\" : \"$2\", \"lri\" : \"$3\",")

            if let jsonData = replaced?.data(using: .utf8)
            {
                let jsonObjects = try JSONDecoder().decode([String:SMADataObject].self, from: jsonData)

                return jsonObjects
            }
        }
        catch
        {
            JLog.error("Could not create Data Objects \(error)")
        }
        return [String:SMADataObject]()
    }()
}




