//
//  File.swift
//
//
//  Created by Patrick Stein on 27.06.22.
//

import Foundation
import AsyncHTTPClient
import JLog
import NIOSSL

struct GetValuesResult: Decodable
{
    enum Value: Decodable
    {
        case intValue(Int?)
        case stringValue(String)
        case tagValues([Int?])

        enum CodingKeys: String, CodingKey { case val }

        init(from decoder: Decoder) throws
        {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let intValue = try? container.decode(Int.self, forKey: CodingKeys.val)
            {
                self = Value.intValue(intValue)
                JLog.debug("int:\(intValue)")
                return
            }
            if let stringValue = try? container.decode(String.self, forKey: CodingKeys.val)
            {
                self = Value.stringValue(stringValue)
                JLog.debug("str:\(stringValue)")
                return
            }
            if let tagArray = try? container.decode([[String: Int?]].self, forKey: CodingKeys.val)
            {
                JLog.debug("tagArray:\(tagArray)")
                let tags = tagArray.map { $0["tag"] ?? nil }
                self = Value.tagValues(tags)
                JLog.debug("tags:\(tags)")
                return
            }
            _ = try container.decodeNil(forKey: CodingKeys.val)
            self = Value.intValue(nil)
        }
    }

    struct Result: Decodable
    {
        let values: [Value]

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
            values = try container.decode([Value].self, forKey: CodingKeys.seven)
        }
    }

    typealias InverterName = String
    typealias SMAObjectID = String

    let result: [InverterName: [SMAObjectID: Result]]
}

public actor SMAInverter
{
    let address: String
    let userright: UserRight
    let password: String

    var loggedIn: Bool = false
    var scheme: String = "https"
    let httpClient: HTTPClient

    public enum UserRight: String
    {
        case user = "usr"
        case installer = "istl"
    }

    public init(address: String, userright: UserRight = .user, password: String = "00000")
    {
        self.address = address
        self.userright = userright
        self.password = password

        var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.certificateVerification = .none
        httpClient = HTTPClient(eventLoopGroupProvider: .createNew,configuration: .init(tlsConfiguration: tlsConfiguration))
    }

    public func setupConnection() async { await _setupConnection() }

    private func _setupConnection() async
    {
        scheme = await schemeTest()
        _ = await smaDataObjects
        _ = await translations
    }

    private nonisolated func schemeTest() async -> String
    {
        //        if address == "10.112.16.13"
        //        {
        //            scheme = "http"
        //        }
        //        return "https"

        SCHEME_TEST: for scheme in ["https", "http"]
        {
            if let url = URL(string: "\(scheme)://\(address)/")
            {
                let request = HTTPClientRequest(url: url.absoluteString)

                if let response = try? await httpClient.execute(request,timeout: .seconds(10)),
                response.status == .ok
                {
                    JLog.debug("url:\(url) got response: \(response)")
                    return scheme
                }
            }
        }
        JLog.error("no valid scheme found for \(address) - using http")
        return "http"
    }

    enum InverterError: Error
    {
        case invalidURLError
        case invalidHTTPResponseError
    }

    func data(forPath path: String) async throws -> Data
    {
        guard let url = URL(string: "\(scheme ?? "https")://\(address)\(path.hasPrefix("/") ? path : "/" + path)")
        else { throw InverterError.invalidURLError }

//        let request = HTTPClientRequest(url: "https://apple.com/")
//        let response = try await httpClient.execute(request, timeout: .seconds(30))
//        print("HTTP head", response)
//        if response.status == .ok
//        {
//            let body = try await response.body.collect(upTo: 1024 * 1024) // 1 MB
//            // handle body
//        } else {
//            // handle remote error
//        }


        do
        {
            let request = HTTPClientRequest(url: url.absoluteString)
            let response = try await httpClient.execute(request,timeout: .seconds(10))
                JLog.debug("url:\(url) got response: \(response)")

            if response.status == .ok
            {
                let body = try await response.body.collect(upTo: 5 * 1024 * 1024) // 5 MB
                let bytes = body.readableBytesView

                return Data(bytes)
            }

//            let (data, response) = try await session.data(for: request)
//
//            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 { return data }
            throw InverterError.invalidHTTPResponseError
        }
        catch
        {
            guard scheme == nil else { throw InverterError.invalidHTTPResponseError }
            scheme = "http"
        }
        return try await data(forPath: path)
    }

    var _smaDataObjects: [String: SMADataObject]!
    var smaDataObjects: [String: SMADataObject]
    {
        get async
        {
            if let _smaDataObjects { return _smaDataObjects }

            if let data = try? await data(forPath: "/data/ObjectMetadata_Istl.json"), let jsonString = String(data: data, encoding: .utf8),
               let smaDataObjects = try? SMADataObject.dataObjects(from: jsonString)
            {
                _smaDataObjects = smaDataObjects
            }
            else
            {
                JLog.error("no sma data object for \(address) - using default")
                _smaDataObjects = SMADataObject.defaultDataObjects
            }

            return _smaDataObjects
        }
    }

    var _translations: [Int: String]!
    var translations: [Int: String]
    {
        get async
        {
            if let _translations { return _translations }

            if let jsonData = try? await data(forPath: "/data/l10n/en-US.json"), let translations = try? JSONDecoder().decode([String: String?].self, from: jsonData)
            {
                _translations = Dictionary(uniqueKeysWithValues: translations.compactMap
                    {
                        guard let intvalue = Int($0) else { return nil }
                        guard let stringvalue = $1 else { return nil }
                        return (intvalue, stringvalue)
                    }
                )
            }
            else
            {
                _translations = SMADataObject.defaultTranslations
            }
            return _translations
        }
    }

    func translate(translations: [Int: String], tags: [Int?]) -> String
    {
        if let tags = tags as? [Int]
        {
            let string = tags.map { translations[$0] ?? "unknowntag" }.joined(separator: "/").lowercased().replacing(#/ /#) { _ in "_" }
            return string
        }
        else
        {
            return "notags"
        }
    }

    public func values() async
    {
        await setupConnection()

        // guard let scheme = self.scheme else { return }

//        let loginUrl = URL(string: "\(scheme)://\(address)/dyn/login.json")!
//
//        let params = ["right": userright.rawValue, "pass": password] as [String: String]
//
//        var request = URLRequest(url: loginUrl)
//        request.httpMethod = "POST"
//        request.httpBody = try? JSONSerialization.data(withJSONObject: params, options: [])
//        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        let decoder = JSONDecoder()
//
//        if let (data, _) = try? await session.data(for: request, delegate: sessionTaskDelegate), let json = try? decoder.decode([String: [String: String]].self, from: data),
//           let sid = json["result"]?["sid"]
//        {
//            JLog.debug("\(json.description)")
//
//            let loginUrl2 = URL(string: "\(scheme)://\(address)/dyn/getAllOnlValues.json?sid=\(sid)")!
//            JLog.debug("\(loginUrl2)")
//            let params2 = ["destDev": [String]()] as [String: [String]]
//
//            var request2 = URLRequest(url: loginUrl2)
//            request2.httpMethod = "POST"
//            request2.httpBody = try! JSONSerialization.data(withJSONObject: params2, options: [])
//            //                request2.httpBody = """
//            // {"destDev":[],"keys":["6400_00260100","6400_00262200","6100_40263F00","7142_40495B00","6102_40433600","6100_40495B00","6800_088F2000","6102_40433800","6102_40633400","6100_402F2000","6100_402F1E00","7162_40495B00","6102_40633E00"]}
//            // """.data(using: .utf8)
//            request2.addValue("application/json", forHTTPHeaderField: "Content-Type")
//
//            if let (data, _) = try? await session.data(for: request2)
//            {
//                let string = String(data: data, encoding: .utf8)
//                JLog.debug("Got:\(string)")
//                JLog.debug("data:\(data.toHexString())")
//
//                let decoder = JSONDecoder()
//                if let getValuesResult = try? decoder.decode(GetValuesResult.self, from: data)
//                {
//                    JLog.debug("values:\(getValuesResult)")
//
//                    for inverter in getValuesResult.result
//                    {
//                        JLog.debug("inverter:\(inverter.key)")
//
//                        for value in inverter.value
//                        {
//                            JLog.debug("objectid:\(value.key)")
//                            let smaDataObjects = await smaDataObjects
//                            let translations = await translations
//
//                            let scale = smaDataObjects[value.key]?.Scale ?? Decimal(1.0)
//
//                            //                            if let smaobject = smaDataObjects[value.key]
//                            //                            {
//                            //                                JLog.debug("path:\( translate(translations:translations,tag:smaobject.TagHier) )/\( translate([smaobject.TagId]) ) unit:\( translate([smaobject.Unit]) ) scale: \( smaobject.Scale ?? Decimal.nan )")
//                            //                            }
//                            let values = value.value.values
//                            for (number, singlevalue) in values.enumerated()
//                            {
//                                switch singlevalue
//                                {
//                                    case let .intValue(value): JLog.debug("\(number).intValue:\(value == nil ? Decimal.nan : Decimal(value!) * scale)")
//                                    case let .stringValue(value): JLog.debug("\(number).stringValue:\(value)")
//                                    case let .tagValues(values): JLog.debug("\(number).tags:\(translate(translations: translations, tags: values))")
//                                }
//                            }
//                        }
//                    }
//                }
//            }
//
//            if let logoutURL = URL(string: "\(scheme)://\(address)/dyn/logout.json.json?sid=\(sid)") { _ = try? await session.data(from: logoutURL) }
//        }
    }

    var description: String
    {
        "NO description yet" //        var returnStrings = [String]()
        //
        //        for (id,smaObject) in smaDataObjects
        //        {
        //                let tagName     =   translations[smaObject.TagId] ?? "tag-\( Int(smaObject.TagId) )"
        //                let eventName   =   smaObject.TagIdEventMsg != nil ? translations[smaObject.TagIdEventMsg!] ?? "event-\( Int(smaObject.TagIdEventMsg!) )" :  ""
        //                let tagHierachy =   smaObject.TagHier.map{ translations[$0] ?? "tag-\( Int($0) )" }.joined(separator:".")
        //                let unitName    =   smaObject.Unit != nil ? translations[smaObject.Unit!] ?? "unit-\( Int(smaObject.Unit!) )"  : ""
        //
        //                returnStrings.append("\(id): \(tagName) \(eventName) \(tagHierachy) \(unitName) \(smaObject.description)")
        //        }
        //        return returnStrings.joined(separator: "\n\n")
    }
}

extension SMAInverter
{
    func value(forObject _: String)
    {
        //        if not logged in, log in
        //          send command
    }

    func login() {}

    func sendCommand() {}

    func retrieveResults() {}
}
