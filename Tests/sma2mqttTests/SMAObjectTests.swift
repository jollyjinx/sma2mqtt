//
//  SMAObjectTests.swift
//

@testable import BinaryCoder
import class Foundation.Bundle
@testable import JLog
@testable import sma2mqttLibrary
import XCTest

final class SMAObjectTests: XCTestCase
{
    var inverterAddress = "sunnyboy"
    var inverterPassword = "0000"

    override func setUpWithError() throws
    {
        inverterPassword = ProcessInfo.processInfo.value(forArgument: "--inverter-password") ?? "0000"
        inverterAddress = ProcessInfo.processInfo.value(forArgument: "--inverter-address") ?? "sunnyboy"
    }

    override func tearDownWithError() throws
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSMADataObject()
    {
        let dataObjects = SMADataObject.defaultDataObjects

        for (_, value) in dataObjects
        {
            print("===")
            print(value.description)
            //            print(value.tagName)
            //            print(value.tagHierachy)
            //            print(value.unitName)
            //            print(value.eventName)
            //            print(value.description)
        }
    }

    func testSMAInverter() async throws
    {
        guard ProcessInfo.processInfo.shouldRunIntegrationTests
        else
        {
            throw XCTSkip("Requires --run-integration-tests or SMA_INTEGRATION_TESTS=1.")
        }

        _ = try await SMADevice(address: "10.112.16.10", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: "10.112.16.13", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: "10.112.16.14", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: "10.112.16.15", userright: .user, password: inverterPassword, publisher: nil)
        _ = try await SMADevice(address: inverterAddress, userright: .user, password: inverterPassword, publisher: nil)
    }

    func testSMAdefinition()
    {
        let smaObjectDefinitions = SMADataObject.defaultDataObjects
        let keys = smaObjectDefinitions.keys.compactMap { $0 as String }

        XCTAssertNotNil(keys.first, "Incorrectly loaded smaObjectDefinitions")
    }

    func testPassword()
    {
        let encoded = SMAPacketGenerator.encodePassword(password: "password", userRight: .user)
        XCTAssertEqual(encoded.hexStringToData(), "f8e9 fbfb fff7 faec 8888 8888".hexStringToData())
    }

    func testDiscoveryPacket()
    {
        let encoded = SMAPacketGenerator.generateDiscoveryPacket()
        XCTAssertEqual(encoded.hexStringToData(), "534d 4100 0004 02a0 ffff ffff 0000 0020 0000".hexStringToData())
    }
}
