//
//  File.swift
//
//
//  Created by Patrick Stein on 27.06.22.
//

import AsyncHTTPClient
import Foundation
import JLog
import NIOCore
import NIOHTTP1
import NIOSSL
import RegexBuilder

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

enum HTTPClientProvider
{
    static var sharedHttpClient: HTTPClient = { var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
        tlsConfiguration.certificateVerification = .none

        return HTTPClient(eventLoopGroupProvider: .createNew, configuration: .init(tlsConfiguration: tlsConfiguration,
                                                                                   timeout: .init(connect: .seconds(5), read: .seconds(10)),
                                                                                   decompression: .enabled(limit: .none)))
    }()
}

public actor SMADevice
{
    let address: String
    let userright: UserRight
    let password: String

    public var lastSeen = Date.distantPast

    var loggedIn = false
    var scheme = "https"
    let httpClient: HTTPClient

    public var name: String
    public var type: DeviceType = .unknown
    private var smaDataObjects: [String: SMADataObject]!
    private var translations: [Int: String]!
    private var sessionid: String?

    public enum UserRight: String
    {
        case user = "usr"
        case installer = "istl"
        case servicce = "svc"
        case developer = "dvlp"
    }

    public enum DeviceType
    {
        case unknown
        case sunnyhomemanager
        case inverter
        case batteryinverter
        case hybridinverter
    }

    public init(address: String, userright: UserRight = .user, password: String = "00000") async throws
    {
        self.address = address
        self.userright = userright
        self.password = password
        name = address
        httpClient = HTTPClientProvider.sharedHttpClient
        try await findOutDeviceNameAndType()
    }

//    deinit
//    {
//        try? httpClient.syncShutdown()
//    }
}

public extension SMADevice
{
    func receivedData(_ data: Data) -> SMAPacket?
    {
        lastSeen = Date()

        guard !data.isEmpty
        else
        {
            JLog.error("received empty packet")
            return nil
        }

        guard let smaPacket = try? SMAPacket(data: data)
        else
        {
            JLog.error("did not decode")
            return nil
        }
        return smaPacket
    }
}

extension SMADevice
{
    enum DeviceError: Error
    {
        case invalidURLError
        case invalidDataError(String)
        case invalidHTTPResponseError
        case loginFailed
    }

    func findOutDeviceNameAndType() async throws
    {
        JLog.debug("findOut:\(address)")
        // find out scheme
        if let response = try? await data(forPath: "/"), !response.bodyData.isEmpty
        {
            scheme = "https"
        }
        else
        {
            scheme = "http"
        }

        // SunnyHomeManager has 'Sunny Home Manager \d.\d' in http://address/legal_notices.txt
        if let response = try? await string(forPath: "legal_notices.txt")
        {
            JLog.debug("\(address):got legal notice")
            if let (_, version) = try? #/Sunny Home Manager (\d+\.\d+)/#.firstMatch(in: response.bodyString)?.output
            {
                JLog.debug("\(address):got legal notice with match")

                JLog.debug("\(address):SMA device found: Sunny Home Manager, version:\(version)")
                name = "sunnymanager"
                type = .sunnyhomemanager
                return
            }
            JLog.debug("\(address):legal no match")
        }
        JLog.debug("\(address):not homemanager")

        do
        {
            let response = try await string(forPath: "/data/ObjectMetadata_Istl.json")
            let smaDataObjects = try SMADataObject.dataObjects(from: response.bodyString)

            self.smaDataObjects = smaDataObjects
        }
        catch
        {
            JLog.error("\(address): no sma data object found \(error)- using default")

            smaDataObjects = SMADataObject.defaultDataObjects
        }

        do
        {
            let response = try await data(forPath: "/data/l10n/en-US.json")
            let translations = try JSONDecoder().decode([String: String?].self, from: response.bodyData)

            self.translations = Dictionary(uniqueKeysWithValues: translations.compactMap
            {
                guard let intvalue = Int($0) else { return nil }
                guard let stringvalue = $1 else { return nil }
                return (intvalue, stringvalue)
            })
        }
        catch
        {
            JLog.error("\(address): no translations found \(error)- using default")

            translations = SMADataObject.defaultTranslations
        }

        JLog.debug("\(address):SMA device found - logging in now")

        // login now
        if true
        {
            let headers = [("Content-Type", "application/json")]
            let loginBody = try JSONSerialization.data(withJSONObject: ["right": userright.rawValue, "pass": password], options: [])
            let response = try await data(forPath: "/dyn/login.json", headers: .init(headers), httpMethod: .POST, requestBody: loginBody)

            let decoder = JSONDecoder()
            let loginResult = try decoder.decode([String: [String: String]].self, from: response.bodyData)

            guard let sid = loginResult["result"]?["sid"]
            else
            {
                JLog.debug("\(address):Login failed: \(response)")

                throw DeviceError.loginFailed
            }
            sessionid = sid
        }

        // get first time data
        if true
        {
            let headers = [("Content-Type", "application/json")]
            let loginBody = try JSONSerialization.data(withJSONObject: ["destDev": [String]()], options: [])
//            let response = try await data(forPath: "/dyn/getAllOnlValues.json",headers: .init(headers),httpMethod: .POST,requestBody: loginBody)
            let response = try await data(forPath: "/dyn/getDashValues.json", headers: .init(headers), httpMethod: .POST, requestBody: loginBody)

            let decoder = JSONDecoder()
            let getValuesResult = try decoder.decode(GetValuesResult.self, from: response.bodyData)

            JLog.trace("values:\(getValuesResult)")

            for inverter in getValuesResult.result
            {
                JLog.debug("inverter:\(inverter.key)")

                for value in inverter.value
                {
                    JLog.debug("objectid:\(value.key)")

                    let scale = smaDataObjects[value.key]?.Scale ?? Decimal(1.0)

                    if let smaobject = smaDataObjects[value.key]
                    {
                        JLog.debug("path:\(translate(translations: translations, tag: smaobject.TagHier))/\(translate([smaobject.TagId])) unit:\(translate([smaobject.Unit])) scale: \(smaobject.Scale ?? Decimal.nan)")
                    }
                    let values = value.value.values
                    for (number, singlevalue) in values.enumerated()
                    {
                        switch singlevalue
                        {
                            case let .intValue(value): JLog.debug("\(number).intValue:\(value == nil ? Decimal.nan : Decimal(value!) * scale)")
                            case let .stringValue(value): JLog.debug("\(number).stringValue:\(value)")
                            case let .tagValues(values): JLog.debug("\(number).tags:\(translate(translations: translations, tags: values))")
                        }
                    }
                }
            }
        }
        JLog.debug("\(address):Successfull login")
    }

    func string(forPath path: String, headers: HTTPHeaders = .init(), httpMethod: HTTPMethod = .GET, requestBody: Data? = nil) async throws -> (headers: HTTPHeaders, bodyString: String)
    {
        let (headers, data) = try await data(forPath: path, headers: headers, httpMethod: httpMethod, requestBody: requestBody)
        guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        else
        {
            throw DeviceError.invalidDataError("Could not decode webpage content to String \(#file)\(#line)")
        }
        return (headers: headers, bodyString: string)
    }

    func data(forPath path: String, headers: HTTPHeaders = .init(), httpMethod: HTTPMethod = .GET, requestBody: Data? = nil) async throws -> (headers: HTTPHeaders, bodyData: Data)
    {
        guard var url = URL(string: "\(scheme)://\(address)\(path.hasPrefix("/") ? path : "/" + path)")
        else { throw DeviceError.invalidURLError }

        if let sessionid
        {
            url.append(queryItems: [URLQueryItem(name: "sid", value: sessionid)])
        }

        JLog.debug("requesting: \(url) for \(address)")
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = httpMethod

        request.headers.add(contentsOf: headers)

        if let requestBody
        {
            request.body = .bytes(requestBody)
        }

        let response = try await httpClient.execute(request, timeout: .seconds(5))

        JLog.debug("url:\(url) got response: \(response)")
        lastSeen = Date()

        if response.status == .ok
        {
            var bodyData = Data()

            do
            {
                for try await buffer in response.body
                {
                    bodyData.append(Data(buffer: buffer))
                }
                print("url:\(url) receivedData:\(bodyData.count)")
            }
            catch
            {
                print("url:\(url) Error: \(error) receivedData:\(bodyData.count)")
            }
            return (headers: response.headers, bodyData: bodyData)
        }
        throw DeviceError.invalidURLError
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

extension SMADevice
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
