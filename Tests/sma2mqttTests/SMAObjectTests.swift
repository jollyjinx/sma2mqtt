//
//  SMAObjectTests.swift
//

import BinaryCoder
import Foundation
import JLog
@testable import sma2mqttLibrary
import Testing

struct SMAObjectTests
{
    @Test
    func sMADataObject()
    {
        let dataObjects = SMADataObject.defaultDataObjects

        for (_, value) in dataObjects
        {
            print("===")
            print(value.description)
        }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.shouldRunIntegrationTests, "Requires --run-integration-tests or SMA_INTEGRATION_TESTS=1."))
    func sMAInverter() async throws
    {
        let inverterPassword = ProcessInfo.processInfo.value(forArgument: "--inverter-password") ?? "0000"
        let inverterAddress = ProcessInfo.processInfo.value(forArgument: "--inverter-address") ?? "sunnyboy"

        _ = try await SMADevice(address: "10.112.16.10", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: "10.112.16.13", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: "10.112.16.14", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: "10.112.16.15", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: inverterAddress, userright: .user, password: inverterPassword, publisher: nil)
    }

    @Test
    func sMAdefinition()
    {
        let smaObjectDefinitions = SMADataObject.defaultDataObjects
        let keys = smaObjectDefinitions.keys.compactMap { $0 as String }

        #expect(keys.first != nil, "Incorrectly loaded smaObjectDefinitions")
    }

    @Test
    func stableSunnyBoy4StringPaths()
    {
        let objectsAndPaths = SMATagTranslator.shared.objectsAndPaths

        #expect(objectsAndPaths["6400_00456B00"]?.path == "dc-side/dc-measurements/energy-dc-input-a")
        #expect(objectsAndPaths["6400_00456C00"]?.path == "dc-side/dc-measurements/energy-dc-input-b")
    }

    @Test
    func observedMultiValueTopicsStayArrays() throws
    {
        let encoder = JSONEncoder()
        let shapeKey = "test/sunnyboy3/dc-side/dc-measurements/power"

        let multiValue = PublishedValue(objectID: "6100_40251E00",
                                        values: [.intValue(36), .intValue(0)],
                                        tagTranslator: SMATagTranslator.shared,
                                        shapeKey: shapeKey)
        let multiObject = try JSONSerialization.jsonObject(with: encoder.encode(multiValue)) as? [String: Any]
        let initialValues = multiObject?["value"] as? [Any]

        #expect(initialValues?.count == 2)

        let singleValue = PublishedValue(objectID: "6100_40251E00",
                                         values: [.intValue(36)],
                                         tagTranslator: SMATagTranslator.shared,
                                         shapeKey: shapeKey)
        let singleObject = try JSONSerialization.jsonObject(with: encoder.encode(singleValue)) as? [String: Any]
        let repeatedValues = singleObject?["value"] as? [Any]

        #expect(repeatedValues?.count == 1)
    }

    @Test
    func observedMultiValueTopicsStayArraysAcrossNormalizedTopicKeys() throws
    {
        let encoder = JSONEncoder()
        let udpShapeKey = "Sunny Boy 3/dc-side/dc-measurements/power"
        let httpShapeKey = "sunny-boy-3/dc-side/dc-measurements/power"

        let multiValue = PublishedValue(objectID: "6100_40251E00",
                                        values: [.intValue(36), .intValue(0)],
                                        tagTranslator: SMATagTranslator.shared,
                                        shapeKey: udpShapeKey)
        let multiObject = try JSONSerialization.jsonObject(with: encoder.encode(multiValue)) as? [String: Any]
        let initialValues = multiObject?["value"] as? [Any]

        #expect(initialValues?.count == 2)

        let singleValue = PublishedValue(objectID: "6100_40251E00",
                                         values: [.intValue(36)],
                                         tagTranslator: SMATagTranslator.shared,
                                         shapeKey: httpShapeKey)
        let singleObject = try JSONSerialization.jsonObject(with: encoder.encode(singleValue)) as? [String: Any]
        let repeatedValues = singleObject?["value"] as? [Any]

        #expect(repeatedValues?.count == 1)
    }

    @Test
    func testPassword()
    {
        let encoded = SMAPacketGenerator.encodePassword(password: "password", userRight: .user)
        #expect(encoded.hexStringToData() == "f8e9 fbfb fff7 faec 8888 8888".hexStringToData())
    }

    @Test
    func discoveryPacket()
    {
        let encoded = SMAPacketGenerator.generateDiscoveryPacket()
        #expect(encoded.hexStringToData() == "534d 4100 0004 02a0 ffff ffff 0000 0020 0000".hexStringToData())
    }
}
