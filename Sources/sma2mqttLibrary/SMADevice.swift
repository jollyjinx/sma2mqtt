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
import NIOFoundationCompat

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
                JLog.trace("int:\(intValue)")
                return
            }
            if let stringValue = try? container.decode(String.self, forKey: CodingKeys.val)
            {
                self = Value.stringValue(stringValue)
                JLog.trace("str:\(stringValue)")
                return
            }
            if let tagArray = try? container.decode([[String: Int?]].self, forKey: CodingKeys.val)
            {
                JLog.trace("tagArray:\(tagArray)")
                let tags = tagArray.map { $0["tag"] ?? nil }
                self = Value.tagValues(tags)
                JLog.trace("tags:\(tags)")
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
    private var smaObjectDefinitions: [String: SMADataObject]!
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
            let smaObjectDefinitions = try SMADataObject.dataObjects(from: response.bodyString)

            self.smaObjectDefinitions = smaObjectDefinitions
        }
        catch
        {
            JLog.error("\(address): no sma data object found \(error)- using default")

            smaObjectDefinitions = SMADataObject.defaultDataObjects
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
            _ = try await getInformationDictionary(for: "/dyn/getDashValues.json")
            _ = try await getInformationDictionary(for: "/dyn/getAllOnlValues.json")
        }

        JLog.debug("\(address):Successfull login")
//            if let logoutURL = URL(string: "\(scheme)://\(address)/dyn/logout.json.json?sid=\(sid)") { _ = try? await session.data(from: logoutURL) }
    }

    func getInformationDictionary(for path: String) async throws -> [String: [String: Codable]]
    {
        let headers = [("Content-Type", "application/json")]
        let loginBody = try JSONSerialization.data(withJSONObject: ["destDev": [String]()], options: [])
        let response = try await data(forPath: path, headers: .init(headers), httpMethod: .POST, requestBody: loginBody)
//            // {"destDev":[],"keys":["6400_00260100","6400_00262200","6100_40263F00","7142_40495B00","6102_40433600","6100_40495B00","6800_088F2000","6102_40433800","6102_40633400","6100_402F2000","6100_402F1E00","7162_40495B00","6102_40633E00"]}

        JLog.trace("body:\(String(data: response.bodyData, encoding: .utf8) ?? response.bodyData.hexDump)")
        let decoder = JSONDecoder()
        let getValuesResult = try decoder.decode(GetValuesResult.self, from: response.bodyData)

        JLog.trace("values:\(getValuesResult)")

        var retrievedInformation = [String: [String: Codable]]()

        for inverter in getValuesResult.result
        {
            JLog.trace("inverter:\(inverter.key)")

            for objectId in inverter.value
            {
                JLog.trace("objectId:\(objectId.key)")

                if let objectDefinition = smaObjectDefinitions[objectId.key]
                {
                    var dictionary = [String: Codable]()

                    dictionary["object"] = objectId.key
                    dictionary["prio"] = objectDefinition.Prio
                    dictionary["write"] = objectDefinition.WriteLevel

//                        dictionary["scale"] = objectDefinition.Scale ?? Decimal(1.0)
                    let units = translate(tag: objectDefinition.Unit)

                    if !units.isEmpty
                    {
                        dictionary["unit"] = units.count == 1 ? units.first : units
                    }

                    var pathComponents: [String] = [inverter.key]
                    pathComponents.append(contentsOf: translate(tags: objectDefinition.TagHier))
                    pathComponents.append(contentsOf: translate(tag: objectDefinition.TagId))
                    let path = pathComponents.joined(separator: "/").lowercased().replacing(#/ /#) { _ in "-" }

                    if let eventID = objectDefinition.TagIdEventMsg
                    {
                        dictionary["event"] = translate(tag: eventID)
                    }

                    var decimalValues = [Decimal?]()
                    var stringValues = [String]()
                    var tagValues = [String]()

                    for (_, singlevalue) in objectId.value.values.enumerated()
                    {
                        switch singlevalue
                        {
                            case let .intValue(value): decimalValues.append(value == nil ? nil : Decimal(value!) * (objectDefinition.Scale ?? Decimal(1.0)))
                            case let .stringValue(value): stringValues.append(value)
                            case let .tagValues(values): tagValues.append(contentsOf: translate(tags: values))
                        }
                    }

                    if !decimalValues.isEmpty
                    {
                        dictionary["value"] = decimalValues.count == 1 ? decimalValues.first : decimalValues
                    }
                    else if !stringValues.isEmpty
                    {
                        dictionary["value"] = stringValues.count == 1 ? stringValues.first : stringValues
                    }
                    else if !tagValues.isEmpty
                    {
                        dictionary["value"] = tagValues.count == 1 ? tagValues.first : tagValues
                    }
                    else
                    {
                        JLog.error("\(address):neiter number nor string Values in \(objectId.value)")
                    }
                    JLog.trace("\(dictionary)")

                    retrievedInformation[path] = dictionary
                }
                else
                {
                    JLog.error("cant find objectDefinition for \(objectId.key)")
                }
            }
        }
        let data = try! JSONSerialization.data(withJSONObject: retrievedInformation, options: [])

        JLog.debug("retrieved:\(String(data: data, encoding: .utf8) ?? "")")

        return retrievedInformation
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
        else {
        throw DeviceError.invalidURLError
        }

        if let sessionid
        {
            url = url.byAppendingQueryItems([URLQueryItem(name: "sid", value: sessionid)]) ?? url
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

        JLog.trace("url:\(url) got response: \(response)")
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
                JLog.trace("url:\(url) receivedData:\(bodyData.count)")
            }
            catch
            {
                JLog.trace("url:\(url) Error: \(error) receivedData:\(bodyData.count)")
            }
            return (headers: response.headers, bodyData: bodyData)
        }
        throw DeviceError.invalidURLError
    }

    func translate(tag: Int?) -> [String] { translate(tags: [tag]) }
    func translate(tags: [Int?]) -> [String]
    {
        if let tags = tags as? [Int]
        {
            return tags.map { translations[$0] ?? "tag(\(String($0, radix: 16)))" }
        }
        return [String]()
    }

    public func values() async
    {}

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
