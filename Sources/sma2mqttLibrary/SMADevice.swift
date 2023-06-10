//
//  File.swift
//
//
//  Created by Patrick Stein on 27.06.22.
//

import AsyncHTTPClient
import Foundation
import JLog
import NIOSSL
import NIOCore
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


class HTTPClientProvider
{
static var sharedHttpClient:HTTPClient = {      var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
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

    public var lastSeen = Date()

    var loggedIn = false
    var scheme = "https"
    let httpClient: HTTPClient

    public var name: String
    public var type: DeviceType = .unknown
    private var _smaDataObjects: [String: SMADataObject]!
    private var _translations: [Int: String]!

    public enum HTTPScheme
    {
        case unknown
        case http
        case https
    }

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

    public init(address: String, userright: UserRight = .user, password: String = "00000")
    {
        self.address = address
        self.userright = userright
        self.password = password
        name = address
        httpClient = HTTPClientProvider.sharedHttpClient
        Task
        {
            await findOutDeviceNameAndType()
        }
    }

    deinit
    {
        try? httpClient.syncShutdown()
    }
}

extension SMADevice
{
    func findOutDeviceNameAndType() async
    {
        JLog.debug("findOut:\(address)")
        // find out scheme
        if let data = try? await data(forPath: "/"), !data.isEmpty
        {
            scheme = "https"
        }
        else
        {
            scheme = "http"
        }

        // SunnyHomeManager has 'Sunny Home Manager \d.\d' in http://address/legal_notices.txt
        if let string = try? await string(forPath: "legal_notices.txt")
        {
            JLog.debug("\(address):got legal notice")
            if let (_,version) = try? #/Sunny Home Manager (\d+\.\d+)/#.firstMatch(in: string)?.output
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
            let jsonData = try await data(forPath: "/data/ObjectMetadata_Istl.json")

            if let jsonString = String(data: jsonData, encoding: .utf8)
            {
                let smaDataObjects = try SMADataObject.dataObjects(from: jsonString)
                _smaDataObjects = smaDataObjects
            }
            else
            {
                JLog.debug("\(address):unknown device - no objectmetadata found")
                return
            }
        }
        catch
        {
            JLog.error("error:\(error)")
            return
        }


        if let jsonData = try? await data(forPath: "/data/l10n/en-US.json"),
           let translations = try? JSONDecoder().decode([String: String?].self, from: jsonData)
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
            JLog.debug("\(address):unknown device - no translations found")
            return
        }

        // now it's a device

        JLog.debug("\(address):SMA device found:")
    }

    public func setupConnection() async { await _setupConnection() }

    private func _setupConnection() async
    {
        _ = await smaDataObjects
        _ = await translations
    }

    public func receivedData(_ data: Data) -> SMAPacket?
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

    enum InverterError: Error
    {
        case invalidURLError
        case invalidHTTPResponseError
    }

    func string(forPath path: String, headers: [String: String] = [:]) async throws -> String
    {
        let data = try await data(forPath: path, headers: headers)
        guard let string = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii)
        else
        {
            throw InverterError.invalidHTTPResponseError
        }
        return string
    }

    func data(forPath path: String, headers _: [String: String] = [:]) async throws -> Data
    {
        guard let url = URL(string: "\(scheme)://\(address)\(path.hasPrefix("/") ? path : "/" + path)")
        else { throw InverterError.invalidURLError }

        JLog.debug("requesting: \(url) for \(address)")
        let request = HTTPClientRequest(url: url.absoluteString)
        let response = try await httpClient.execute(request, timeout:.seconds(5))

        JLog.debug("url:\(url) got response: \(response)")

        if response.status == .ok
        {
            var receivedData = Data()

            do
            {
                for try await buffer in response.body
                {
                    receivedData.append(Data(buffer:buffer))
                }
                print("url:\(url) receivedData:\(receivedData.count)")
            }
            catch
            {
                print("url:\(url) Error: \(error) receivedData:\(receivedData.count)")
            }
            return receivedData
        }
        throw InverterError.invalidURLError
    }

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
