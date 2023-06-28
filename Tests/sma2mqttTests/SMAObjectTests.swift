//
//  SMAObjectTests.swift
//
//
//  Created by Patrick Stein on 27.06.22.
//

import XCTest

import class Foundation.Bundle

@testable import BinaryCoder
@testable import JLog
@testable import sma2mqttLibrary

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

    func testSMADataObject() throws
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
        let _ = try await SMADevice(address: inverterAddress, userright: .user, password: inverterPassword, publisher: nil)
    }

    func testSMAdefinition() async throws
    {
        let smaObjectDefinitions = SMADataObject.defaultDataObjects
        let keys = smaObjectDefinitions.keys.compactMap { $0 as String }

        XCTAssertNotNil(keys.first, "Incorrectly loaded smaObjectDefinitions")
    }

    func testPassword() async throws
    {
        let encoded = SMAPacketGenerator.encodePassword(password: "password", userRight: .user)
        XCTAssertEqual(encoded.hexStringToData(),"f8e9 fbfb fff7 faec 8888 8888".hexStringToData())
   }


    func testDiscoveryPacket() async throws
    {
        let encoded = SMAPacketGenerator.generateDiscoveryPacket()
        XCTAssertEqual(encoded.hexStringToData(),"534d 4100 0004 02a0 ffff ffff 0000 0020 0000".hexStringToData())
    }


}
