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
        let inverter = SMAInverter(address: inverterAddress, userright: .user, password: inverterPassword)
        let description = await inverter.description
        print("\(description)")
        await inverter.setupConnection()
        await inverter.values()

        // try await Task.sleep(nanoseconds: UInt64( Int64.max-10) )
    }
}
