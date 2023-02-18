//
//  File.swift
//  
//
//  Created by Patrick Stein on 27.06.22.
//

import Foundation
import JLog


class IgnoreCertificateDelegate:NSObject,URLSessionDelegate
{
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
       //Trust the certificate even if not valid
       let urlCredential = URLCredential(trust: challenge.protectionSpace.serverTrust!)

       completionHandler(.useCredential, urlCredential)
    }
}


struct GetValuesResult:Decodable
{
    enum Value:Decodable
    {
        case intValue(Int?)
        case stringValue(String)
        case tagValues([Int?])

        enum CodingKeys:String,CodingKey
        {
            case val = "val"
        }

        init(from decoder: Decoder) throws
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let intValue = try? container.decode(Int.self, forKey: CodingKeys.val)
            {
                self = Value.intValue(intValue)
                print("int:\(intValue)")
                return
            }
            if let stringValue = try? container.decode(String.self, forKey: CodingKeys.val)
            {
                self = Value.stringValue(stringValue)
                print("str:\(stringValue)")
                return
            }
            if let tagArray = try? container.decode([[String:Int?]].self, forKey: CodingKeys.val)
            {
                print("tagArray:\(tagArray)")
                let tags = tagArray.map { $0["tag"] ?? nil }
                self = Value.tagValues(tags)
                print("tags:\(tags)")
                return
            }
            try container.decodeNil(forKey: CodingKeys.val)
            self = Value.intValue(nil)
        }
    }


    struct Result:Decodable
    {
        let values:[Value]

        enum CodingKeys: String, CodingKey
        {
            case one = "1"
            case seven = "7"
        }

        init(from decoder: Decoder) throws
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let values = try container.decodeIfPresent([Value].self, forKey: CodingKeys.one)
            {
                self.values = values
                return
            }
            self.values = try container.decode([Value].self, forKey: CodingKeys.seven)
        }
    }
    typealias InverterName = String
    typealias SMAObjectID = String

    let result: [InverterName:[SMAObjectID:Result]]
}


actor SMAInverter
{
    let address:String
    let userright:UserRight
    let password:String
    var loggedIn:Bool = false

    enum UserRight:String
    {
        case user       = "usr"
        case installer  = "istl"
    }

    init(address: String, userright:UserRight = .user ,password: String = "00000") {
        self.address = address
        self.userright = userright
        self.password = password
    }

    var _smaDataObjects:[String:SMADataObject]! = nil
    var smaDataObjects:[String:SMADataObject]
    {
        if let _smaDataObjects { return _smaDataObjects }

        if  let dataObjectURL = URL(string: "http://\(self.address)/data/ObjectMetadata_Istl.json"),
            let jsonString = try? String(contentsOf: dataObjectURL),
            let smaDataObjects = try? SMADataObject.dataObjects(from: jsonString)
        {
            _smaDataObjects = smaDataObjects
        }
        else
        {
            _smaDataObjects = SMADataObject.defaultDataObjects
        }

        return _smaDataObjects
    }

    var _translations:[Int:String]! = nil
    var translations:[Int:String]
    {
        if let _translations { return _translations }

        if  let translationURL  = URL(string: "http://\(self.address)/data/l10n/en-US.json"),
            let jsonData = try? Data(contentsOf: translationURL),
            let translations = try? JSONDecoder().decode([String:String?].self, from: jsonData)
        {
            _translations = Dictionary(uniqueKeysWithValues: translations.compactMap {  guard let intvalue = Int($0) else { return nil }
                                                                                        guard let stringvalue = $1 else { return nil }
                                                                                        return (intvalue , stringvalue)
                                                                                     } )
        }
        else
        {
            _translations = SMADataObject.defaultTranslations
        }
        return _translations
    }


    func translate(_ tags:[Int?]) -> String
    {
        if let tags = tags as? [Int]
        {
            let string =  tags.map{ self.translations[$0] ?? "unknowntag" }.joined(separator:"/").lowercased().replacing(#/ /#){ w in "_" }
            return string
        }
        else
        {
            return "notags"
        }
    }


     func values() async
     {
        let scheme = "https"

        let delegate = IgnoreCertificateDelegate()
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: nil)

        let loginUrl   = URL(string: "\(scheme)://\(self.address)/dyn/login.json")!

        let params = ["right":userright.rawValue, "pass":password] as Dictionary<String, String>

        var request = URLRequest(url: loginUrl)
            request.httpMethod = "POST"
            request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let decoder = JSONDecoder()

        if let (data,_) = try? await session.data(for: request),
            let json = try? decoder.decode(Dictionary<String,[String:String]>.self, from: data),
            let sid = json["result"]?["sid"]
        {
            print(json)

            let loginUrl2   = URL(string: "\(scheme)://\(self.address)/dyn/getAllOnlValues.json?sid=\(sid)")!
            print(loginUrl2)
            let params2 = ["destDev": [String]() ] as Dictionary<String, [String]>

            var request2 = URLRequest(url: loginUrl2)
                request2.httpMethod = "POST"
                request2.httpBody = try! JSONSerialization.data(withJSONObject: params2, options: [])
//                request2.httpBody = """
//{"destDev":[],"keys":["6400_00260100","6400_00262200","6100_40263F00","7142_40495B00","6102_40433600","6100_40495B00","6800_088F2000","6102_40433800","6102_40633400","6100_402F2000","6100_402F1E00","7162_40495B00","6102_40633E00"]}
//""".data(using: .utf8)
                request2.addValue("application/json", forHTTPHeaderField: "Content-Type")

            if let (data,_) = try? await session.data(for: request2)
            {
                let string = String(data: data, encoding: .utf8)
                print("Got:\(string)")
                print("data:\( data.toHexString() )")

                let decoder = JSONDecoder()
                if let getValuesResult = try? decoder.decode(GetValuesResult.self, from: data)
                {
                    print("values:\( getValuesResult )")

                    for inverter in getValuesResult.result
                    {
                        print("inverter:\(inverter.key)")

                        for value in inverter.value
                        {
                            print("objectid:\(value.key)")

                            let scale = smaDataObjects[value.key]?.Scale ?? Decimal(1.0)

                            if let smaobject = smaDataObjects[value.key]
                            {
                                print("path:\( translate(smaobject.TagHier) )/\( translate([smaobject.TagId]) ) unit:\( translate([smaobject.Unit]) ) scale: \( smaobject.Scale ?? Decimal.nan )")
                            }
                            let values = value.value.values
                            for (number,singlevalue) in values.enumerated()
                            {
                                switch singlevalue
                                {
                                    case .intValue(let value)       :   print("\(number).intValue:\(value == nil ? Decimal.nan : Decimal(value!) * scale)")
                                    case .stringValue(let value)    :   print("\(number).stringValue:\(value)")
                                    case .tagValues(let values)     :   print("\(number).tags:\(translate(values))")
                                }

                            }
                        }
                    }
                }
            }




            let loginUrl3   = URL(string: "\(scheme)://\(self.address)/dyn/logout.json.json?sid=\(sid)")!
            let _ = try? String(contentsOf: loginUrl3)
        }
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
