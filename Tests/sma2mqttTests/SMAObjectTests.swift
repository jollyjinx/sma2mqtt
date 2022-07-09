//
//  SMAObjectTests.swift
//  
//
//  Created by Patrick Stein on 27.06.22.
//

import XCTest
import class Foundation.Bundle

@testable import JLog
@testable import BinaryCoder
@testable import sma2mqttLibrary

final class SMAObjectTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSMADataObject() throws {

        let dataObjects = SMADataObject.defaultDataObjects


        for (key,value) in dataObjects
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



    func testSMAInverter() async throws {

        let inverter = SMAInverter(address: "sunnyboy4.jinx.eu.")
        let description = await inverter.description
        print("\(description)")

        
    }

}
