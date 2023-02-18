//
//  File.swift
//  
//
//  Created by Patrick Stein on 26.06.22.
//

import Foundation
import RegexBuilder
import JLog

public struct SMADataObject
{
    let object:Int
    let lri:Int

    let Prio:Int
    let TagId:Int

    let TagIdEventMsg:Int?

    let Unit:Int?
    let DataFrmt:Int
    let Scale:Decimal?
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
    var description:String  { "\(id): \(self.json)" }
}


extension SMADataObject:Decodable,Encodable
{
    private enum CodingKeys : String, CodingKey {
        case object,lri,Prio,TagId,TagIdEventMsg,Unit,DataFrmt,Scale,Typ,WriteLevel,GridGuard,TagHier,Min,Max,Sum,Avg,Cnt,MinD,MaxD,SumD
    }

    public init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        let objectString = try values.decode(String.self, forKey: .object)
        guard let object = Int(objectString , radix: 16) else { throw DecodingError.dataCorruptedError(forKey: .object, in: values, debugDescription: "could not decode hex string:\(objectString) ") }
        self.object = object

        let lriString = try values.decode(String.self, forKey: .lri)
        guard let lri = Int(lriString , radix: 16) else { throw DecodingError.dataCorruptedError(forKey: .lri, in: values, debugDescription: "could not decode hex string:\(lriString)") }
        self.lri = lri

        Prio        = try values.decode(Int.self, forKey: .Prio)
        TagId       = try values.decode(Int.self, forKey: .TagId)
        TagIdEventMsg = try values.decodeIfPresent(Int.self, forKey: .TagIdEventMsg)
        Unit        = try values.decodeIfPresent(Int.self, forKey: .Unit)
        DataFrmt    = try values.decode(Int.self, forKey: .DataFrmt)
        Scale       = try values.decodeIfPresent(Decimal.self, forKey: .Scale)

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
    static let defaultTranslations:[Int:String] =
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
    public static let defaultDataObjects:[String:SMADataObject] =
    {
        let url = Bundle.module.url(forResource: "sma.data.objectMetaData", withExtension: "json")!
        let jsonString = try! String(contentsOf: url)
        return try! dataObjects(from: jsonString)
    }()

    static func dataObjects(from jsonString:String) throws -> [String:SMADataObject]
    {
        do
        {
            let regex = #/("([0-9a-fA-F]{4})_([0-9a-fA-F]{8})": {)/#
            let replaced = jsonString.replacing(regex) { match in
            """
            \(match.1)
                "object": "\( Int(match.2, radix:16)! )",
                "lri": "\( Int(match.3, radix:16)! )",
            """
            }
            //print(replaced)
            if let jsonData = replaced.data(using: .utf8)
            {
                let jsonObjects = try JSONDecoder().decode([String:SMADataObject].self, from: jsonData)

                return jsonObjects
            }
        }
        catch
        {
            JLog.error("Could not create Data Objects from json:\(error)")
            throw error
        }
        return [String:SMADataObject]() // never reached
    }
}
