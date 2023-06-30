//
//  SMADevice.swift
//

import AsyncHTTPClient
import Foundation
import JLog
import NIOFoundationCompat
import NIOHTTP1
import RegexBuilder

public actor SMADevice
{
    let address: String
    let userright: UserRight
    let password: String
    let publisher: SMAPublisher?
    let interestingPaths: [String]

    var objectsToQueryContinously = Set<String>()
    let requestAllObjects: Bool

    public var lastSeen = Date.distantPast

    var scheme = "https"
    let httpClient: HTTPClient
    private var sessionid: String?

    let udpEmitter: UDPEmitter?
    var udpSystemId: UInt16 = 0xFFFF
    var udpSerial: UInt32 = 0xFFFF_FFFF
    var udpLoggedIn = false
    var udpSession: Int?
    var udpPacketCounter = 1

    private var hasDeviceName = false
    public var name: String { willSet { hasDeviceName = true } }

    private var refreshTask: Task<Void, Error>?
    private var tagTranslator = SMATagTranslator.shared

    public init(address: String, userright: UserRight = .user, password: String = "00000", publisher: SMAPublisher? = nil, refreshInterval: Int = 1, interestingPaths: [String] = [], requestAllObjects: Bool = false, udpEmitter: UDPEmitter? = nil) async throws
    {
        self.address = address
        self.userright = userright
        self.password = password
        self.publisher = publisher
        self.interestingPaths = interestingPaths
        self.requestAllObjects = requestAllObjects
        self.udpEmitter = udpEmitter
        name = address
        hasDeviceName = false

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
                        try await Task.sleep(nanoseconds: UInt64(refreshInterval) * UInt64(NSEC_PER_SEC))
//                        try await self.httpQueryInterestingObjects()
                        try await self.udpQueryInterestingObjects()
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
}

public extension SMADevice
{
    func receivedUDPData(_ data: Data) async -> SMAPacket?
    {
        lastSeen = Date()
        guard !data.isEmpty
        else
        {
            JLog.error("\(address):received empty packet")
            return nil
        }

        JLog.trace("received udp packet:\(data.hexDump)")

        let smaPacket: SMAPacket

        do
        {
            smaPacket = try SMAPacket(data: data)

            if let netPacket = smaPacket.netPacket
            {
                udpLoggedIn = netPacket.isLoggedIn
                udpSystemId = netPacket.header.sourceSystemId
                udpSerial = netPacket.header.sourceSerial

                let multipleValues = netPacket.values.count > 1

                for value in netPacket.values
                {
                    if netPacket.header.u16command == 0xFFFD
                    {
                        continue
                    }
                    let objectID = String(format: "%04X_%02X%04X00", netPacket.header.u16command, value.type, value.address)

                    JLog.trace("\(address): objectid:\(objectID)")

                    if let simpleObject = tagTranslator.objectsAndPaths[objectID]
                    {
                        JLog.trace("\(address): objectid:\(objectID) name:\(simpleObject.json)")

                        let path = name + "/\(simpleObject.path)\(multipleValues ? ".\(value.number)" : "")"

                        switch value.value
                        {
                            case let .uint(value):
                                if let firstValue = value.first as? UInt32
                                {
                                    let resultValue = GetValuesResult.Value.intValue(Int(firstValue))
                                    let singleValue = PublishedValue(objectID: objectID, values: [resultValue], tagTranslator: tagTranslator)
                                    try? await publisher?.publish(to: path, payload: singleValue.json, qos: .atMostOnce, retain: false)
                                }
                            case let .int(value):
                                if let firstValue = value.first as? Int32
                                {
                                    let resultValue = GetValuesResult.Value.intValue(Int(firstValue))
                                    let singleValue = PublishedValue(objectID: objectID, values: [resultValue], tagTranslator: tagTranslator)
                                    try? await publisher?.publish(to: path, payload: singleValue.json, qos: .atMostOnce, retain: false)
                                }

                            case let .string(string):
                                let resultValue = GetValuesResult.Value.stringValue(string)
                                let singleValue = PublishedValue(objectID: objectID, values: [resultValue], tagTranslator: tagTranslator)
                                try? await publisher?.publish(to: path, payload: singleValue.json, qos: .atMostOnce, retain: false)

                            case let .tags(tags):
                                let resultValue = GetValuesResult.Value.tagValues(tags.map { Int($0) })
                                let singleValue = PublishedValue(objectID: objectID, values: [resultValue], tagTranslator: tagTranslator)
                                try? await publisher?.publish(to: path, payload: singleValue.json, qos: .atMostOnce, retain: false)

                            default:
                                try? await publisher?.publish(to: path, payload: value.json, qos: .atMostOnce, retain: false)
                        }
                    }
                    else
                    {
                        JLog.error("\(address): objectid not known \(objectID)")
                    }
                }
            }
        }
        catch
        {
            JLog.error("\(address):did not decode :\(error) \(data.hexDump)")
            return nil
        }

        JLog.trace("\(address): received \(smaPacket)")

        guard hasDeviceName else { return nil }

        for obisvalue in smaPacket.obis
        {
            if obisvalue.mqtt != .invisible
            {
                try? await publisher?.publish(to: name + "/" + obisvalue.topic, payload: obisvalue.json, qos: .atLeastOnce, retain: obisvalue.mqtt == .retained)
            }
        }

        return smaPacket
    }

    func getNextPacketCounter() -> Int
    {
        udpPacketCounter = (udpPacketCounter + 1)
        return udpPacketCounter
    }

    func udpQueryInterestingObjects() async throws
    {
        let packetcounter = getNextPacketCounter()

        let packetToSend: String

        if !udpLoggedIn
        {
            packetToSend = try SMAPacketGenerator.generateLoginPacket(packetcounter: packetcounter, password: password, userRight: .user)
        }
        else
        {
            let objectIDs = Array(objectsToQueryContinously)
            let queryobject = objectIDs[packetcounter % objectIDs.count]

            packetToSend = try SMAPacketGenerator.generatePacketForObjectID(packetcounter: packetcounter, objectID: queryobject, dstSystemId: udpSystemId, dstSerial: udpSerial)
        }

        JLog.trace("\(address): sending udp packet:\(packetToSend)")
        await udpEmitter?.sendPacket(data: [UInt8](packetToSend.hexStringToData()), address: address, port: 9522)
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
        case packetGenerationError(String)
    }

    func findOutDeviceNameAndType() async throws
    {
        JLog.debug("\(address):find out device type")

        if let _ = try? await data(forPath: "/")
        {
            scheme = "https"
        }
        else
        {
            scheme = "http"
        }

        if let response = try? await string(forPath: "legal_notices.txt")
        {
            JLog.debug("\(address):got legal notice")
            if let (_, version) = try? #/Sunny Home Manager (\d+\.\d+)/#.firstMatch(in: response.bodyString)?.output
            {
                JLog.debug("\(address):got legal notice with match")

                JLog.debug("\(address):SMA device found: Sunny Home Manager, version:\(version)")
                name = "sunnymanager"
                return
            }
            JLog.debug("\(address):legal no match")
        }
        JLog.debug("\(address):not homemanager")

        do
        {
            let definitionData = try await data(forPath: "/data/ObjectMetadata_Istl.json").bodyData
            let translationData = try await data(forPath: "/data/l10n/en-US.json").bodyData

//            try definitionData.write(to: URL(filePath:"/Users/jolly/Desktop/\(address).definition.json"))
//            try translationData.write(to:URL(filePath:"/Users/jolly/Desktop/\(address).translationData.json"))

            tagTranslator = SMATagTranslator(definitionData: definitionData, translationData: translationData)
        }
        catch
        {
            JLog.error("\(address): no sma definitions / translations found \(error)- using default")
        }

        JLog.debug("\(address):SMA device found - logging in now")

        // login now
        sessionid = try await httpLogin()
        JLog.debug("\(address):Successfull login")

        // get first time data
        if let deviceName = try await getDeviceName(), !deviceName.isEmpty
        {
            name = deviceName
        }

        if true
        {
            try await getInformationDictionary(atPath: "/dyn/getDashValues.json")
            try await getInformationDictionary(atPath: "/dyn/getAllOnlValues.json")

            if requestAllObjects
            {
                var validatedObjectids = objectsToQueryContinously

                for key in tagTranslator.devicenameObjectIDs
                {
                    do
                    {
                        try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: [key])

                        if objectsToQueryContinously.contains(key)
                        {
                            validatedObjectids.insert(key)
                        }
                    }
                    catch
                    {
                        JLog.error("\(address):request failed for key:\(key)")
                    }
                    try await Task.sleep(nanoseconds: UInt64(0.05 * Double(NSEC_PER_SEC)))
                }
                JLog.trace("\(address):validated ids:\(validatedObjectids)")
                objectsToQueryContinously = validatedObjectids
            }
        }
    }

    func httpQueryInterestingObjects() async throws
    {
        if sessionid == nil
        {
            JLog.debug("\(address):Will Login")
            sessionid = try await httpLogin()
        }
        JLog.debug("\(address):Successfull login")
        try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: Array(objectsToQueryContinously))
    }

    func httpLogin() async throws -> String
    {
        JLog.debug("\(address):Login")

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
            JLog.error("\(address):no type-label/device-name in smaDefinitions found - can't figure out name of device")
            return nil
        }

        let deviceNameDictionary = try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: devicenameKeys)
        JLog.trace("\(address):deviceNameDictionary:\(deviceNameDictionary)")

        if let deviceName = deviceNameDictionary.first(where: { !($0.value.stringValue?.isEmpty ?? true) })?.value.stringValue
        {
            JLog.trace("\(address) devicename: \(deviceName)")
            return deviceName
        }
        JLog.notice("\(address):could not get deviceName.")

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

    func pathIsInteresting(_ path: String) -> Bool
    {
        interestingPaths.first(where: { path.hasSuffix($0) }) != nil
    }

    func _getInformationDictionary(atPath path: String, requestIds: [String] = [String]()) async throws -> [String: PublishedValue]
    {
        let headers = [("Content-Type", "application/json")]

        let postDictionary = requestIds.isEmpty ? ["destDev": [String]()] : ["destDev": [String](), "keys": requestIds]

        JLog.trace("\(address):get keys:\(requestIds)")
        let loginBody = try JSONSerialization.data(withJSONObject: postDictionary, options: [])
        let response = try await data(forPath: path, headers: .init(headers), httpMethod: .POST, requestBody: loginBody)

        JLog.trace("\(address):retrieved body:\(String(data: response.bodyData, encoding: .utf8) ?? response.bodyData.hexDump)")
        let decoder = JSONDecoder()
        let getValuesResult = try decoder.decode(GetValuesResult.self, from: response.bodyData)

        JLog.trace("\(address):values:\(getValuesResult)")

        var retrievedInformation = [String: PublishedValue]()

        for inverter in getValuesResult.result
        {
            JLog.trace("\(address):inverter:\(inverter.key)")

            for objectId in inverter.value
            {
                JLog.trace("\(address):working on objectId:\(objectId.key)")

                let singleValue = PublishedValue(objectID: objectId.key, values: objectId.value.values, tagTranslator: tagTranslator)
                let mqttPath = name.lowercased().replacing(#/[\\\/\s]+/#) { _ in "-" } + "/" + (tagTranslator.objectsAndPaths[objectId.key]?.path ?? "unkown-id-\(objectId.key)")

                retrievedInformation[mqttPath] = singleValue

                let isInteresting: Bool

                if objectsToQueryContinously.contains(objectId.key)
                {
                    isInteresting = true
                }
                else if pathIsInteresting(mqttPath)
                {
                    isInteresting = true
                    objectsToQueryContinously.insert(objectId.key)
                    JLog.debug("\(address):objectsToQueryContinously:\(objectsToQueryContinously)")
                }
                else
                {
                    isInteresting = false
                }

                do
                {
                    if hasDeviceName, isInteresting
                    {
                        try await publisher?.publish(to: mqttPath, payload: singleValue.json, qos: .atMostOnce, retain: true)
                    }
                }
                catch
                {
                    JLog.error("\(address):could not convert to json error:\(error) singleValue:\(singleValue)")
                }
            }
        }
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

        JLog.debug("\(address):requesting: \(url) for \(address)")
        var request = HTTPClientRequest(url: url.absoluteString)
        request.method = httpMethod

        request.headers.add(contentsOf: headers)

        if let requestBody
        {
            request.body = .bytes(requestBody)
        }

        let response = try await httpClient.execute(request, timeout: .seconds(5))

        JLog.trace("\(address):url:\(url) got response: \(response)")
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
                JLog.trace("\(address):url:\(url) receivedData:\(bodyData.count)")
            }
            catch
            {
                JLog.trace("\(address):url:\(url) Error: \(error) receivedData:\(bodyData.count)")
            }
            return (headers: response.headers, bodyData: bodyData)
        }
        throw DeviceError.connectionError
    }
}
