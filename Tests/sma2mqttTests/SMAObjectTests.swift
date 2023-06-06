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
    override func setUpWithError() throws
    {
        // Put setup code here. This method is called before the invocation of each test method in the class.
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
        let arguments = ProcessInfo.processInfo.arguments

        var lastTestArgument: String? = nil

        let password =
            arguments.compactMap
                {
                    guard lastTestArgument == "--password"
                    else
                    {
                        lastTestArgument = $0
                        return nil
                    }
                    return $0
                }.first ?? "0000"

        let inverter = SMAInverter(address: "sunnyboy3.jinx.eu.", userright: .user, password: password)
        let description = await inverter.description
        print("\(description)")
        await inverter.setupConnection()
        await inverter.values()
        // try await Task.sleep(nanoseconds: UInt64( Int64.max-10) )
    }
}
