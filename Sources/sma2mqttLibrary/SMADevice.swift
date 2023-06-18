//
//  File.swift
//
//
//  Created by Patrick Stein on 27.06.22.
//

import AsyncHTTPClient
import Foundation
import JLog
import NIO
import NIOCore
import NIOFoundationCompat
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
    let publisher: SMAPublisher?
    let interestingPaths: [String]
    var objectsToQueryContinously = Set<String>()

    public var lastSeen = Date.distantPast

    var loggedIn = false
    var scheme = "https"
    let httpClient: HTTPClient

    private var hasDeviceName = false
    public var name: String

    public var type: DeviceType = .unknown
    private var sessionid: String?
    private var refreshTask: Task<Void, Error>?
    private var tagTranslator = SMATagTranslator.shared

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

    public init(address: String, userright: UserRight = .user, password: String = "00000", publisher: SMAPublisher? = nil, interestingPaths: [String] = []) async throws
    {
        self.address = address
        self.userright = userright
        self.password = password
        self.publisher = publisher
        self.interestingPaths = interestingPaths
        name = address
        httpClient = HTTPClientProvider.sharedHttpClient
        try await findOutDeviceNameAndType()
        if !objectsToQueryContinously.isEmpty
        {
            refreshTask = Task.detached
            {
                var errorcounter = 0
                while errorcounter < 100
                {
                    do
                    {
                        try await Task.sleep(nanoseconds: UInt64(3 * NSEC_PER_SEC))
                        try await self.queryInterestingObjects()
                        errorcounter = 0
                    }
                    catch
                    {
                        JLog.error("\(address): Failed to query interesting objects: \(error)")
                        errorcounter += 1
                    }
                }
                JLog.error("\(address): too many erros")
            }
        }
    }

//    deinit
//    {
//        try? httpClient.syncShutdown()
//    }
}

public struct PublishedValue: Encodable
{
//    let id: String
//    let prio: Int
//    let write: Int
    let unit: Int?
    let scale: Decimal?
//    let event: String?
    let values: [GetValuesResult.Value]

    let tagTranslator: SMATagTranslator

    var stringValue: String?
    {
        if values.count == 1,
           case let .stringValue(stringValue) = values.first
        {
            return stringValue
        }
        return nil
    }

    public func encode(to encoder: Encoder) throws
    {
        enum CodingKeys: String, CodingKey { case unit, value, scale, id, prio, write, event }
        var container = encoder.container(keyedBy: CodingKeys.self)

//        try container.encode(id, forKey: .id)
//        try container.encode(prio, forKey: .prio)
//        try container.encode(write, forKey: .write)
//        try container.encode(scale, forKey: .scale)
//        try container.encode(event, forKey: .event)

        let compacted = values.compactMap { $0 }
        switch compacted.first
        {
            case .stringValue:
                let stringValues: [String?] = values.map
                {
                    if case let .stringValue(value) = $0
                    {
                        return value
                    }
                    return nil
                }
                if stringValues.count > 1
                {
                    try container.encode(stringValues, forKey: .value)
                }
                else
                {
                    try container.encode(stringValues.first, forKey: .value)
                }

            case .intValue:
                let decimalValues: [Decimal?] = values.map
                {
                    if case let .intValue(value) = $0,
                       let value
                    {
                        if let scale, scale != Decimal(1)
                        {
                            return Decimal(value) * scale
                        }
                        return Decimal(value)
                    }
                    return nil
                }
                if decimalValues.count > 1
                {
                    try container.encode(decimalValues, forKey: .value)
                }
                else
                {
                    try container.encode(decimalValues.first, forKey: .value)
                }
                if let unit
                {
                    let unitString = tagTranslator.translate(tag: unit)
                    try container.encode(unitString, forKey: .unit)
                }

            case let .tagValues(values): let translated = values.map { $0 == nil ? nil : tagTranslator.translate(tag: $0!) }
                try container.encode(translated, forKey: .value)

            case nil: let value: Int? = nil; try container.encode(value, forKey: .value)
        }
    }
}

//    extension PublishedValue:Encodable {}

public extension SMADevice
{
    func receivedData(_ data: Data) async -> SMAPacket?
    {
        lastSeen = Date()

        guard hasDeviceName else { return nil }

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

        for obisvalue in smaPacket.obis
        {
            if obisvalue.mqtt != .invisible
            {
                try? await publisher?.publish(to: name + "/" + obisvalue.topic, payload: obisvalue.json, qos: .atLeastOnce, retain: obisvalue.mqtt == .retained)
            }
        }

        return smaPacket
    }
}

extension SMADevice
{
    enum DeviceError: Error
    {
        case connectionError
        case invalidURLError
        case invalidDataError(String)
        case invalidHTTPResponseError
        case loginFailed
    }

    func findOutDeviceNameAndType() async throws
    {
        JLog.debug("\(address):find out device type")
        // find out scheme
        if let _ = try? await data(forPath: "/")
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
                hasDeviceName = true
                return
            }
            JLog.debug("\(address):legal no match")
        }
        JLog.debug("\(address):not homemanager")
//        try await data(forPath: "/")

        do
        {
            let definitionData = try await data(forPath: "/data/ObjectMetadata_Istl.json").bodyData
            let translationData = try await data(forPath: "/data/l10n/en-US.json").bodyData

            tagTranslator = SMATagTranslator(definitionData: definitionData, translationData: translationData)
        }
        catch
        {
            JLog.error("\(address): no sma definitions / translations found \(error)- using default")
        }

        JLog.debug("\(address):SMA device found - logging in now")

        // login now
        sessionid = try await login()
        JLog.debug("\(address):Successfull login")

        // get first time data
        if let deviceName = try await getDeviceName(), !deviceName.isEmpty
        {
            name = deviceName
        }
        hasDeviceName = true

        if true
        {
            // {"destDev":[],"keys":["6400_00260100","6400_00262200","6100_40263F00","7142_40495B00","6102_40433600","6100_40495B00","6800_088F2000","6102_40433800","6102_40633400","6100_402F2000","6100_402F1E00","7162_40495B00","6102_40633E00"]}

            try await getInformationDictionary(atPath: "/dyn/getDashValues.json")
            try await getInformationDictionary(atPath: "/dyn/getAllOnlValues.json")

            var validatedObjectids = Set<String>()

//            try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: ["6800_10821E00"])
//            let allKeys = smaObjectDefinitions.keys.compactMap { $0 as String }

            for key in objectsToQueryContinously
            {
                do
                {
                    try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: [key])
                    validatedObjectids.insert(key)
                }
                catch
                {
                    JLog.error("\(address) request failed for key:\(key)")
                }
                try await Task.sleep(nanoseconds: UInt64(0.05 * Double(NSEC_PER_SEC)))
            }
            JLog.trace("\(address): validated ids:\(validatedObjectids)")
            objectsToQueryContinously = validatedObjectids
        }

        //    try await logout()

        JLog.debug("\(address):Successfull logout")
    }

    func queryInterestingObjects() async throws
    {
        if sessionid == nil
        {
            JLog.debug("\(address):Will Login")
            sessionid = try await login()
        }
        JLog.debug("\(address):Successfull login")
        try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: Array(objectsToQueryContinously))
    }

    func login() async throws -> String
    {
        let headers = [("Content-Type", "application/json"), ("Connection", "keep-alive")]
        let loginBody = try JSONSerialization.data(withJSONObject: ["right": userright.rawValue, "pass": password], options: [])
        let response = try await data(forPath: "/dyn/login.json", headers: .init(headers), httpMethod: .POST, requestBody: loginBody)

        let decoder = JSONDecoder()
        let loginResult = try decoder.decode([String: [String: String]].self, from: response.bodyData)

        guard let sid = loginResult["result"]?["sid"] as? String
        else
        {
            JLog.debug("\(address):Login failed: \(response)")

            throw DeviceError.loginFailed
        }
        return sid
    }

    func getDeviceName() async throws -> String?
    {
        let devicenameKeys = tagTranslator.devicenameObjectIDs

        guard !devicenameKeys.isEmpty
        else
        {
            JLog.error("\(address) no type-label/device-name in smaDefinitions found - can't figure out name of device")
            return nil
        }

        let deviceNameDictionary = try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: devicenameKeys)
        JLog.trace("deviceNameDictionary:\(deviceNameDictionary)")

        if let deviceName = deviceNameDictionary.first(where: { !($0.value.stringValue?.isEmpty ?? true) })?.value.stringValue
        {
            JLog.trace("devicename: \(deviceName)")
            return deviceName
        }
        JLog.notice("could not get deviceName.")

        return nil
    }

    func logout() async throws
    {
        let headers = [("Content-Type", "application/json")]
        try await data(forPath: "/dyn/logout.json", headers: .init(headers), httpMethod: .POST, requestBody: nil)
        sessionid = nil
    }

    @discardableResult
    func getInformationDictionary(atPath path: String, requestIds: [String] = [String]()) async throws -> [String: PublishedValue]
    {
        do
        {
            return try await _getInformationDictionary(atPath: path, requestIds: requestIds)
        }
        catch
        {
            JLog.error("\(address): Failed request - setting session to nil")
            sessionid = nil

            throw error
        }
    }

    func _getInformationDictionary(atPath path: String, requestIds: [String] = [String]()) async throws -> [String: PublishedValue]
    {
        let headers = [("Content-Type", "application/json")]

        let postDictionary = requestIds.isEmpty ? ["destDev": [String]()] : ["destDev": [String](), "keys": requestIds]

        JLog.trace("keys:\(requestIds)")
        let loginBody = try JSONSerialization.data(withJSONObject: postDictionary, options: [])
        let response = try await data(forPath: path, headers: .init(headers), httpMethod: .POST, requestBody: loginBody)

        JLog.trace("body:\(String(data: response.bodyData, encoding: .utf8) ?? response.bodyData.hexDump)")
        let decoder = JSONDecoder()
        let getValuesResult = try decoder.decode(GetValuesResult.self, from: response.bodyData)

        JLog.trace("values:\(getValuesResult)")

        var retrievedInformation = [String: PublishedValue]()

        for inverter in getValuesResult.result
        {
            JLog.trace("inverter:\(inverter.key)")

            for objectId in inverter.value
            {
                JLog.trace("objectId:\(objectId.key)")

                if let objectDefinition = tagTranslator.smaObjectDefinitions[objectId.key]
                {
//                    let singleValue = PublishedValue(id: objectId.key, prio: objectDefinition.Prio, write: objectDefinition.WriteLevel, unit:unit, scale: objectDefinition.Scale, values: objectId.value.values)
                    let singleValue = PublishedValue(unit: objectDefinition.Unit, scale: objectDefinition.Scale, values: objectId.value.values, tagTranslator: tagTranslator)

                    var pathComponents: [String] = [name]
                    pathComponents.append(contentsOf: tagTranslator.translate(tags: objectDefinition.TagHier))
                    pathComponents.append(tagTranslator.translate(tag: objectDefinition.TagId))
                    let mqttPath = pathComponents.joined(separator: "/").lowercased().replacing(#/ /#) { _ in "-" }

                    if !objectsToQueryContinously.contains(objectId.key)
                    {
//                        !singleValue.values.compactMap{ $0 }.isEmpty

                        if let _ = interestingPaths.first(where: { mqttPath.hasSuffix($0) })
                        {
                            objectsToQueryContinously.insert(objectId.key)
                        }
                        JLog.debug("\(address): objectsToQueryContinously:\(objectsToQueryContinously)")
                    }

                    retrievedInformation[mqttPath] = singleValue

                    do
                    {
                        if hasDeviceName, objectsToQueryContinously.contains(objectId.key)
                        {
                            try await publisher?.publish(to: mqttPath, payload: singleValue.json, qos: .atMostOnce, retain: true)
                        }
                    }
                    catch
                    {
                        JLog.error("\(address): could not convert to json error:\(error) singleValue:\(singleValue)")
                    }
                }
                else
                {
                    JLog.error("cant find objectDefinition for \(objectId.key)")
                }
            }
        }
//        let data = try! JSONSerialization.data(withJSONObject: retrievedInformation, options: [])
//
//        JLog.debug("retrieved:\(String(data: data, encoding: .utf8) ?? "")")

        return retrievedInformation
    }

    @discardableResult
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

    @discardableResult
    func data(forPath path: String, headers: HTTPHeaders = .init(), httpMethod: HTTPMethod = .GET, requestBody: Data? = nil) async throws -> (headers: HTTPHeaders, bodyData: Data)
    {
        guard var url = URL(string: "\(scheme)://\(address)\(path.hasPrefix("/") ? path : "/" + path)")
        else
        {
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
        throw DeviceError.connectionError
    }
}
