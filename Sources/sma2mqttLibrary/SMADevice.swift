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

public typealias ObjectId = String

public actor SMADevice
{
    let id = UUID().uuidString
    let initDate = Date()

    let address: String
    let userright: UserRight
    let password: String
    let publisher: SMAPublisher?
    let interestingPaths: [String: TimeInterval]

    let deviceTimeout = 180.0
    var lastRequestSentDate = Date()
    var lastPublishedDate = Date()
    var lastReceivedValidPacket = Date()

    let udpMinimumRequestInterval = 1.0 / 10.0 // 1 / maximumRequestsPerSecond
    let udpRequestTimeout = 5.0
    var currentRequestedObjectID: ObjectId = "UNKNOWN"

    let requestAllObjects: Bool
    var queryQueue: QueryQueue

    var scheme = "https"
    let httpClient: HTTPClient
    private var sessionid: String?
    let httpTimeout: NIOCore.TimeAmount = .seconds(5)

    let udpReceiver: SMAUDPPort
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
    private var _isValid = true
    private var tagTranslator = SMATagTranslator.shared

    public init(address: String, userright: UserRight = .user, password: String = "00000", publisher: SMAPublisher? = nil, interestingPaths: [String: TimeInterval] = [:], requestAllObjects: Bool = false, bindAddress: String = "0.0.0.0", udpEmitter: UDPEmitter? = nil) async throws
    {
        self.address = address
        self.userright = userright
        self.password = password
        self.publisher = publisher

        self.interestingPaths = interestingPaths
        self.requestAllObjects = requestAllObjects
        self.udpEmitter = udpEmitter

        queryQueue = QueryQueue(address: address, minimumRequestInterval: 0.1, retryInterval: 10.0)

        udpReceiver = try SMAUDPPort(bindAddress: bindAddress, listenPort: 0)

        name = address
        hasDeviceName = false

        httpClient = HTTPClientProvider.sharedHttpClient
        try await findOutDeviceNameAndType()

        if !queryQueue.isEmpty
        {
            refreshTask = Task
            {
                var errorcounter = 0
                while errorcounter < 100, self.isValid
                {
                    do
                    {
                        let id = try await queryQueue.waitForNextObjectId()
                        try queryQueue.shouldRetry(id: id)

                        try await udpQueryObject(objectID: id)
                        errorcounter = 0
                    }
                    catch
                    {
                        JLog.error("\(address): Failed to query interesting objects: \(error)")
                        errorcounter += 1
                    }
                }
                JLog.error("\(address): too many errors")
                _isValid = false
            }
        }
    }
}

public extension SMADevice
{
    var asyncDescription: String { get async { "SMADevice:\(address): id:\(id) init:\(initDate) lastReceivedValidPacket:\(lastReceivedValidPacket) lastRequestSentDate:\(lastRequestSentDate) udpPacketCounter:\(String(format: "0x%04x", udpPacketCounter)) isValid:\(isValid) queryQueue: \(queryQueue.json)" } }

    var isValid: Bool
    {
        guard _isValid else { return false }

        JLog.debug("\(address):isValid:\(_isValid)")
        if isHomeManager
        {
            _isValid = lastReceivedValidPacket.isWithin(timeInterval: deviceTimeout)
        }
        else
        {
            _isValid = lastReceivedValidPacket.isWithin(timeInterval: deviceTimeout) && lastRequestSentDate.isWithin(timeInterval: deviceTimeout)
        }
        JLog.debug("\(address):isValid:\(_isValid)")
        return _isValid
    }

    func receivedMulticast(_ data: Data) async
    {
        guard !data.isEmpty
        else
        {
            JLog.error("\(address):received empty packet")
            return
        }
        JLog.debug("\(address):received udp packet:\(data.hexDump)")

        guard isHomeManager, hasDeviceName
        else
        {
            JLog.debug("\(address):no HomeManager or DeviceName - ignoring multicast packet")
            return
        }

        guard lastReceivedValidPacket.isOlderThan(timeInterval: 1.0)
        else
        {
            JLog.debug("\(address): isHomeManager and received already at:\(lastReceivedValidPacket) - ignoring")
            return
        }

        guard let smaPacket = try? SMAPacket(data: data), !smaPacket.obis.isEmpty
        else
        {
            JLog.debug("\(address): isHomeManager and received not an ObisPacket - ignoring")
            return
        }

        await receivedObisPacket(obisValues: smaPacket.obis)
    }

    func receivedSMAPacket(_ smaPacket: SMAPacket) async
    {
        JLog.trace("\(address): received \(smaPacket)")

        if let netPacket = smaPacket.netPacket
        {
            await receivedNetPacket(netPacket: netPacket)
            return
        }
    }

    func receivedObisPacket(obisValues: [ObisValue]) async
    {
        lastReceivedValidPacket = Date()

        for obisvalue in obisValues
        {
            if obisvalue.mqtt != .invisible
            {
                try? await publisher?.publish(to: name + "/" + obisvalue.topic, payload: obisvalue.json, qos: .atMostOnce, retain: obisvalue.mqtt == .retained)
                lastPublishedDate = Date()
            }
        }
    }

    func receivedNetPacket(netPacket: SMANetPacket) async
    {
        JLog.debug("\(address): received netPacket: requestedID:\(currentRequestedObjectID) result:\(String(format: "0x%04x", netPacket.header.u16result)) command:\(String(format: "0x%04x", netPacket.header.u16command)) packetid:\(String(format: "0x%04x", netPacket.header.packetId))")

        if udpPacketCounter != (0x7FFF & netPacket.header.packetId)
        {
            JLog.notice("\(address): received netPacket: we did not await:\(String(format: "0x%04x", udpPacketCounter)) packet command:\(String(format: "0x%04x", netPacket.header.u16command)) packetid:\(String(format: "0x%04x", netPacket.header.packetId))")
            return
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
                    return
                }
                JLog.notice("\(address): login success.")
                udpLoggedIn = true
                udpSystemId = netPacket.header.sourceSystemId
                udpSerial = netPacket.header.sourceSerial
                return
            }
            JLog.debug("\(address): login required")
            udpLoggedIn = false
            return
        }

        if !udpLoggedIn
        {
            JLog.error("\(address): received correct packet even though we are logged out - ignoring.")
            return
        }

        if netPacket.header.invalidRequest
        {
            JLog.notice("\(address): received netPacket: requestedID:\(currentRequestedObjectID) result:\(String(format: "0x%04x", netPacket.header.u16result)) command:\(String(format: "0x%04x", netPacket.header.u16command)) packetid:\(String(format: "0x%04x", netPacket.header.packetId))")
            queryQueue.retrieved(id: currentRequestedObjectID, success: false)

            udpLoggedIn = false
            return
        }

        if !netPacket.header.resultIsOk
        {
            JLog.notice("\(address): result not ok. logging out. objectId:\(currentRequestedObjectID) : \(tagTranslator.objectsAndPaths[currentRequestedObjectID]?.path ?? "unknown")")

            udpLoggedIn = false
            return
        }

        lastReceivedValidPacket = Date()

        let objectIDs = netPacket.values.map { String(format: "%04X_%02X%04X00", netPacket.header.u16command, $0.type, $0.address) }

        if let objectID = objectIDs.first(where: { tagTranslator.objectsAndPaths[$0] != nil }),
           let simpleObject = tagTranslator.objectsAndPaths[objectID]
        {
            JLog.debug("\(address): objectid:\(objectID) name:\(simpleObject.json)")
            queryQueue.retrieved(id: currentRequestedObjectID, success: true)

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

        lastRequestSentDate = Date()
        let packets = try await udpReceiver.sendRequestAndAwaitResponse(data: [UInt8](packetToSend.hexStringToData()), packetcounter: packetcounter, address: address, port: 9522, receiveTimeout: udpRequestTimeout)

        for packet in packets
        {
            JLog.debug("\(address): working on \(packet)")

            if let netPacket = packet.netPacket
            {
                await receivedNetPacket(netPacket: netPacket)
            }
            else
            {
                JLog.debug("\(address): received packet has no netPacket\(packet)")
            }
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
        try await getInformationDictionary(atPath: "/dyn/getValues.json", requestIds: queryQueue.allOjectIds)
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

    nonisolated func pathIsInteresting(_ path: String) -> TimeInterval?
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

    func objectIdIsInteresting(_ objectid: String) -> (path: String, interval: TimeInterval)?
    {
        let path = "/" + (tagTranslator.objectsAndPaths[objectid]?.path ?? "unkown-id-\(objectid)")
        let interval = pathIsInteresting(path)

        JLog.trace("\(address):\(objectid) \(path) interval:\(interval ?? -1)")

        if let interval
        {
            return (path: path, interval: interval)
        }
        return nil
    }

    @discardableResult
    func addObjectToQueryContinouslyIfNeeded(objectid: String) -> Bool
    {
        JLog.trace("\(address):working on objectId:\(objectid)")

        guard let (path, interval) = objectIdIsInteresting(objectid) else { return false }

        return queryQueue.addObjectToQuery(id: objectid, path: path, interval: interval)
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

        lastRequestSentDate = Date()
        let response = try await httpClient.execute(request, timeout: httpTimeout)
        lastReceivedValidPacket = Date()

        JLog.trace("\(address):url:\(url) got response: \(response)")

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
