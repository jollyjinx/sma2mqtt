//
//  SMADevice.swift
//

import AsyncHTTPClient
import Foundation
import JLog
import NIOCore
import NIOFoundationCompat
import NIOHTTP1
import RegexBuilder

public actor SMADevice
{
    let address: String
    let userright: UserRight
    let password: String
    let publisher: SMAPublisher?
    let refreshInterval: Int
    let interestingPaths: [String: Int]

    struct QueryObject: Hashable
    {
        let objectid: String
        let path: String
        let interval: Int
    }

    struct QueryElement: Hashable, Comparable
    {
        let objectid: String
        let nextReadDate: Date

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.nextReadDate < rhs.nextReadDate }
        static func <= (lhs: Self, rhs: Self) -> Bool { lhs.nextReadDate <= rhs.nextReadDate }
        static func >= (lhs: Self, rhs: Self) -> Bool { lhs.nextReadDate >= rhs.nextReadDate }
        static func > (lhs: Self, rhs: Self) -> Bool { lhs.nextReadDate > rhs.nextReadDate }
    }

    var objectsToQueryContinously = [String: QueryObject]()
    var objectsToQueryNext = [QueryElement]()
    var lastRequestSentDate = Date.distantPast
    var lastPublishedDate = Date()

    let udpMinimumRequestInterval = 1.0 / 10.0 // 1 / maximumRequestsPerSecond
    let udpRequestTimeout = 5.0
    var currentRequestedObjectID: String = "UNKNOWN"

    let requestAllObjects: Bool

    public var lastRequestReceived = Date.distantPast

    var scheme = "https"
    let httpClient: HTTPClient
    private var sessionid: String?
    let httpTimeout: NIOCore.TimeAmount = .seconds(5)

    let udpReceiver: UDPReceiver
    let udpEmitter: UDPEmitter?
    var udpSystemId: UInt16 = 0xFFFF
    var udpSerial: UInt32 = 0xFFFF_FFFF
    var udpLoggedIn = false
    var udpSession: Int?
    var udpPacketCounter = 0x0000

    private var hasDeviceName = false
    public var name: String { willSet { hasDeviceName = true } }
    var isHomeManager = false

    private var refreshTask: Task<Void, Error>?
    private var tagTranslator = SMATagTranslator.shared

    public init(address: String, userright: UserRight = .user, password: String = "00000", publisher: SMAPublisher? = nil, refreshInterval: Int = 30, interestingPaths: [String: Int] = [:], requestAllObjects: Bool = false, bindAddress: String = "0.0.0.0", udpEmitter: UDPEmitter? = nil) async throws
    {
        self.address = address
        self.userright = userright
        self.password = password
        self.publisher = publisher

        self.refreshInterval = refreshInterval

        self.interestingPaths = interestingPaths
        self.requestAllObjects = requestAllObjects
        self.udpEmitter = udpEmitter

        udpReceiver = try UDPReceiver(bindAddress: bindAddress, listenPort: 0)

        name = address
        hasDeviceName = false

        httpClient = HTTPClientProvider.sharedHttpClient
        try await findOutDeviceNameAndType()
        if !objectsToQueryContinously.isEmpty
        {
            refreshTask = Task
            {
                var errorcounter = 0
                while errorcounter < 100
                {
                    do
                    {
                        try await self.workOnNextPacket()
                        errorcounter = 0
                    }
                    catch
                    {
                        JLog.error("\(address): Failed to query interesting objects: \(error)")
                        errorcounter += 1
                    }
                }
                JLog.error("\(address): too many errors")
            }
        }
    }
}

public extension SMADevice
{
    var isValid: Bool { lastPublishedDate.timeIntervalSinceNow > -120 }

    func receivedUDPData(_ data: Data) async -> SMAPacket?
    {
        guard !data.isEmpty
        else
        {
            JLog.error("\(address):received empty packet")
            return nil
        }
        JLog.debug("\(address):received udp packet:\(data.hexDump)")

        if isHomeManager, lastRequestReceived.timeIntervalSinceNow > -1.0
        {
            JLog.debug("\(address): isHomeManager and received already at:\(lastRequestReceived) - ignoring")
            return nil
        }
        lastRequestReceived = Date()

        guard let smaPacket = try? SMAPacket(data: data) else { return nil }

        return await receivedSMAPacket(smaPacket)
    }

    func receivedSMAPacket(_ smaPacket: SMAPacket) async -> SMAPacket?
    {
        if let netPacket = smaPacket.netPacket
        {
            JLog.debug("\(address): received netPacket: objectid:\(currentRequestedObjectID) result:\(String(format: "0x%04x", netPacket.header.u16result)) command:\(String(format: "0x%04x", netPacket.header.u16command)) packetid:\(String(format: "0x%04x", netPacket.header.packetId))")

            if udpPacketCounter != (0x7FFF & netPacket.header.packetId)
            {
                JLog.notice("\(address): received netPacket: we did not await:\(String(format: "0x%04x", udpPacketCounter)) packet command:\(String(format: "0x%04x", netPacket.header.u16command)) packetid:\(String(format: "0x%04x", netPacket.header.packetId))")
                return nil
            }

            if netPacket.header.u16command == 0xFFFD
            {
                if currentRequestedObjectID == "LOGIN"
                {
                    guard netPacket.header.resultIsOk
                    else
                    {
                        JLog.error("\(address): login failed.")
                        udpLoggedIn = false
                        return nil
                    }
                    JLog.notice("\(address): login success.")
                    udpLoggedIn = true
                    udpSystemId = netPacket.header.sourceSystemId
                    udpSerial = netPacket.header.sourceSerial
                    return nil
                }
                JLog.debug("\(address): login required")
                udpLoggedIn = false
                return nil
            }

            if !udpLoggedIn
            {
                JLog.error("\(address): received correct packet even though we are logged out - ignoring.")
                return nil
            }

            if netPacket.header.invalidRequest
            {
                JLog.notice("\(address):removing invalid request objectId:\(currentRequestedObjectID) : \(tagTranslator.objectsAndPaths[currentRequestedObjectID]?.path ?? "unknown")")

                udpLoggedIn = false

                objectsToQueryNext = objectsToQueryNext.compactMap { $0.objectid == currentRequestedObjectID ? nil : $0 }
                objectsToQueryContinously.removeValue(forKey: currentRequestedObjectID)

                return nil
            }

            if !netPacket.header.resultIsOk
            {
                JLog.debug("\(address): result not ok. logging out. objectId:\(currentRequestedObjectID) : \(tagTranslator.objectsAndPaths[currentRequestedObjectID]?.path ?? "unknown")")

                udpLoggedIn = false
                return nil
            }

            let objectIDs = netPacket.values.map { String(format: "%04X_%02X%04X00", netPacket.header.u16command, $0.type, $0.address) }

            if let objectID = objectIDs.first(where: { tagTranslator.objectsAndPaths[$0] != nil }),
               let simpleObject = tagTranslator.objectsAndPaths[objectID]
            {
                JLog.debug("\(address): objectid:\(objectID) name:\(simpleObject.json)")
                justRetrievedObject(objectID: objectID)

                let path = name + "/\(simpleObject.path)"
                var resultValues = [GetValuesResult.Value]()

                for value in netPacket.values
                {
                    JLog.trace("\(address): objectid:\(objectID)")

                    switch value.value
                    {
                        case let .uint(value):
                            if let firstValue = value.first as? UInt32
                            {
                                let resultValue = GetValuesResult.Value.intValue(Int(firstValue))
                                resultValues.append(resultValue)
                            }
                        case let .int(value):
                            if let firstValue = value.first as? Int32
                            {
                                let resultValue = GetValuesResult.Value.intValue(Int(firstValue))
                                resultValues.append(resultValue)
                            }

                        case let .string(string):
                            let resultValue = GetValuesResult.Value.stringValue(string)
                            resultValues.append(resultValue)

                        case let .tags(tags):
                            let resultValue = GetValuesResult.Value.tagValues(tags.map { Int($0) })
                            resultValues.append(resultValue)

                        default:
                            try? await publisher?.publish(to: path + ".\(value.number)", payload: value.json, qos: .atMostOnce, retain: false)
                            lastPublishedDate = Date()
                    }
                }

                let singleValue = PublishedValue(objectID: objectID, values: resultValues, tagTranslator: tagTranslator)
                try? await publisher?.publish(to: path, payload: singleValue.json, qos: .atMostOnce, retain: false)
                lastPublishedDate = Date()
            }
            else if !objectIDs.isEmpty
            {
                JLog.error("\(address): objectIDs not known \(objectIDs)")
            }
        }

        JLog.trace("\(address): received \(smaPacket)")

        guard hasDeviceName else { return nil }

        for obisvalue in smaPacket.obis
        {
            if obisvalue.mqtt != .invisible
            {
                try? await publisher?.publish(to: name + "/" + obisvalue.topic, payload: obisvalue.json, qos: .atMostOnce, retain: obisvalue.mqtt == .retained)
                lastPublishedDate = Date()
            }
        }

        return smaPacket
    }

    internal func getNextRequest() throws -> QueryElement
    {
        guard let queryElement = objectsToQueryNext.min() else { throw DeviceError.packetGenerationError("no packets to wait for") }

        let newElement = QueryElement(objectid: queryElement.objectid, nextReadDate: Date(timeIntervalSinceNow: 5.0))
        objectsToQueryNext = objectsToQueryNext.map { $0.objectid == queryElement.objectid ? newElement : $0 }

        return queryElement
    }

    func justRetrievedObject(objectID: String)
    {
        if let object = objectsToQueryContinously[objectID]
        {
            if object.interval != 0
            {
                let newElement = QueryElement(objectid: object.objectid, nextReadDate: Date(timeIntervalSinceNow: Double(object.interval)))
                objectsToQueryNext = objectsToQueryNext.map { $0.objectid == objectID ? newElement : $0 }
            }
            else
            {
                objectsToQueryNext.removeAll(where: { $0.objectid == objectID })
            }
        }
    }

    func workOnNextPacket() async throws
    {
        let objectToQuery = try getNextRequest()

        let nextReadDate = max(objectToQuery.nextReadDate, lastRequestSentDate + udpMinimumRequestInterval)

        let timeToWait = nextReadDate.timeIntervalSinceNow

        if timeToWait > 0
        {
            try await Task.sleep(for: .seconds(timeToWait))
        }
        lastRequestSentDate = Date()

        try await udpQueryObject(objectID: objectToQuery.objectid)
    }

    func getNextPacketCounter() -> Int
    {
        udpPacketCounter = (udpPacketCounter + 1) % 0x8000
        return udpPacketCounter
    }

    func udpQueryObject(objectID: String) async throws
    {
        let packetcounter = getNextPacketCounter()

        let packetToSend: String

        if !udpLoggedIn
        {
            packetToSend = try SMAPacketGenerator.generateLoginPacket(packetcounter: packetcounter, password: password, userRight: .user)
            JLog.debug("\(address): sending login packetcounter:\(String(format: "0x%04x", packetcounter))")
            currentRequestedObjectID = "LOGIN"
        }
        else
        {
            packetToSend = try SMAPacketGenerator.generatePacketForObjectID(packetcounter: packetcounter, objectID: objectID, dstSystemId: udpSystemId, dstSerial: udpSerial)
            JLog.debug("\(address): sending udp packetcounter:\(String(format: "0x%04x", packetcounter)) objectid:\(objectID) loggedIn:\(udpLoggedIn)")
            currentRequestedObjectID = objectID
        }

        JLog.trace("\(address): sending udp packetcounter:\(String(format: "0x%04x", packetcounter)) packet:\(packetToSend)")

        let packets = try await udpReceiver.sendReceivePacket(data: [UInt8](packetToSend.hexStringToData()), packetcounter: packetcounter, address: address, port: 9522, receiveTimeout: udpRequestTimeout)

        if !packets.isEmpty
        {
            lastRequestReceived = Date()
        }

        for packet in packets
        {
            _ = await receivedSMAPacket(packet)
        }
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
                isHomeManager = true
                return
            }
            JLog.debug("\(address):legal no match")
        }
        JLog.debug("\(address):not homemanager")

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
        sessionid = try await httpLogin()
        JLog.debug("\(address):Successfull login")

        // get first time data
        if let deviceName = try await getDeviceName(), !deviceName.isEmpty
        {
            name = deviceName
        }

        try await getInformationDictionary(atPath: "/dyn/getDashValues.json")
        try await getInformationDictionary(atPath: "/dyn/getAllOnlValues.json")

        for objectid in tagTranslator.smaObjectDefinitions.keys
        {
            addObjectToQueryContinouslyIfNeeded(objectid: objectid)
        }

        try? await logout()
    }

    func httpQueryInterestingObjects() async throws
    {
        if sessionid == nil
        {
            JLog.debug("\(address):Will Login")
            sessionid = try await httpLogin()
        }
        JLog.debug("\(address):Successfull login")
        try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: Array(objectsToQueryContinously.keys))
    }

    func httpLogin() async throws -> String
    {
        do
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
                JLog.debug("\(address):Login failed: session missing \(response)")

                throw DeviceError.loginFailed
            }
            return sid
        }
        catch
        {
            JLog.debug("\(address):Login failed: \(error)")
            throw DeviceError.loginFailed
        }
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

    nonisolated func pathIsInteresting(_ path: String) -> Int?
    {
        for interestingPath in interestingPaths
        {
            if path.hasSuffix(interestingPath.key) || interestingPath.key == "*"
            {
                return interestingPath.value
            }
        }
        return nil
    }

    func objectIdIsInteresting(_ objectid: String) -> (path: String, interval: Int?)
    {
        let path = "/" + (tagTranslator.objectsAndPaths[objectid]?.path ?? "unkown-id-\(objectid)")

        let interval = pathIsInteresting(path)

        JLog.trace("\(address):\(objectid) \(path) interval:\(interval ?? -1)")

        return (path: path, interval: interval)
    }

    @discardableResult
    func addObjectToQueryContinouslyIfNeeded(objectid: String) -> Bool
    {
        JLog.trace("\(address):working on objectId:\(objectid)")

        let (path, interval) = objectIdIsInteresting(objectid)

        if let interval
        {
            if let inuse = objectsToQueryContinously.values.first(where: { $0.path == path })
            {
                JLog.notice("\(address): Won't query objectid:\(objectid) - object with same path:\(inuse.objectid) path:\(inuse.path)")
                return false
            }
            JLog.debug("\(address): adding to objectsToQueryContinously objectid:\(objectid) path:\(path) interval:\(interval)")

            let queryObject = objectsToQueryContinously[objectid] ?? QueryObject(objectid: objectid, path: path, interval: interval)

            if interval <= queryObject.interval
            {
                objectsToQueryContinously[objectid] = queryObject
                objectsToQueryNext.append(QueryElement(objectid: objectid, nextReadDate: Date(timeIntervalSinceNow: Double(min(interval, 5)))))
            }
            return true
        }
        return false
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

                do
                {
                    if hasDeviceName,
                       addObjectToQueryContinouslyIfNeeded(objectid: objectId.key)
                    {
                        try await publisher?.publish(to: mqttPath, payload: singleValue.json, qos: .atMostOnce, retain: false)
                        lastPublishedDate = Date()
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

        let response = try await httpClient.execute(request, timeout: httpTimeout)

        JLog.trace("\(address):url:\(url) got response: \(response)")
        lastRequestReceived = Date()

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
