//
//  File.swift
//  
//
//  Created by Patrick Stein on 27.06.22.
//

import Foundation
import JLog

actor SMAInverter
{
    let address:String
    let password:String
    var loggedIn:Bool = false

    var _smaDataObjects:[String:SMADataObject]! = nil
    var smaDataObjects:[String:SMADataObject]
    {
        if let _smaDataObjects { return _smaDataObjects }

        let dataObjectURL   = URL(string: "http://\(self.address)/data/ObjectMetadata_Istl.json")!

        do
        {
            let jsonString = try String(contentsOf: dataObjectURL)
            let regexString = "(\"([\\da-f]{4})_([\\da-f]{8})\": \\{)"
            let regex = regexString.r
            let replaced = regex?.replaceAll(in: jsonString, with: "$0 \"object\" : \"$2\", \"lri\" : \"$3\",")

            if let jsonData = replaced?.data(using: .utf8)
            {
                let jsonObjects = try JSONDecoder().decode([String:SMADataObject].self, from: jsonData)

                _smaDataObjects = jsonObjects
            }
        }
        catch
        {
            _smaDataObjects = SMADataObject.defaultDataObjects
        }
        return _smaDataObjects
    }

    var _translations:[Int:String]! = nil
    var translations:[Int:String]
    {
        if let _translations { return _translations }

        let translationURL  = URL(string: "http://\(self.address)/data/l10n/en-US.json")!

        do
        {
            let jsonData = try Data(contentsOf: translationURL)
            let translations = try JSONDecoder().decode([String:String?].self, from: jsonData)

            _translations = Dictionary(uniqueKeysWithValues: translations.compactMap { guard let intvalue = Int($0) else { return nil }
                                                                                        guard let stringvalue = $1 else { return nil }
                                                                                      return (intvalue , stringvalue)
                                                                                     } )
        }
        catch
        {
            _translations = SMADataObject.defaultTranslations
        }
        return _translations
    }



    init(address: String, password: String = "00000") {
        self.address = address
        self.password = password
    }

    var description:String
    {
        var returnStrings = [String]()

        for (id,smaObject) in smaDataObjects
        {
                let tagName     =   translations[smaObject.TagId] ?? "tag-\( Int(smaObject.TagId) )"
                let eventName   =   smaObject.TagIdEventMsg != nil ? translations[smaObject.TagIdEventMsg!] ?? "event-\( Int(smaObject.TagIdEventMsg!) )" :  ""
                let tagHierachy =   smaObject.TagHier.map{ translations[$0] ?? "tag-\( Int($0) )" }.joined(separator:".")
                let unitName    =   smaObject.Unit != nil ? translations[smaObject.Unit!] ?? "unit-\( Int(smaObject.Unit!) )"  : ""

                returnStrings.append("\(id): \(tagName) \(eventName) \(tagHierachy) \(unitName) \(smaObject.description)")
        }
        return returnStrings.joined(separator: "\n")
    }
}

extension SMAInverter
{
    func value(forObject:String)
    {
//        if not logged in, log in
//          send command
    }

    func login()
    {

    }


    func sendCommand()
    {

    }

    func retrieveResults()
    {
    
    }
}
