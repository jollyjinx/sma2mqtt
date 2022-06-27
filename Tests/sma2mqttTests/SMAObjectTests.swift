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

    func testExample() throws {

        let dataObjects = SMADataObject.dataObjects


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

        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

}
