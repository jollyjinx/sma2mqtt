//
//  QueryQueueTests.swift
//

import class Foundation.Bundle
import XCTest

@testable import JLog
@testable import sma2mqttLibrary

final class QueryQueueTests: XCTestCase
{
    override func setUpWithError() throws
    {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws
    {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testQueryObject() throws
    {
        var queryObject = QueryObject(id: "71C0_00496700", path: "/battery/battery/temperature", interval: 1, maxErrors: 4)

        XCTAssert(queryObject.isValid == true)
        queryObject.increaseOK()
        queryObject.increaseOK()
        queryObject.increaseOK()
        queryObject.increaseOK()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseOK()
        queryObject.increaseOK()
        queryObject.increaseOK()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseOK()
        queryObject.increaseOK()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()

        print("queryObject:\(queryObject.json)")

        XCTAssert(queryObject.isValid == true)
    }

    func testQueryObject2() throws
    {
        var queryObject = QueryObject(id: "71C0_00496700", path: "/battery/battery/temperature", interval: 1, maxErrors: 4)

        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == false)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == false)
        queryObject.increaseOK()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseOK()
        queryObject.increaseOK()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseOK()
        queryObject.increaseOK()
        XCTAssert(queryObject.isValid == true)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()

        print("queryObject:\(queryObject.json)")

        XCTAssert(queryObject.isValid == true)
    }

    func testQueryQueue() throws
    {
        var queryQueue = QueryQueue(address: "local", minimumRequestInterval: 1.0e-10, retryInterval: 1.0e-10, maxErrors: 3)

        let a = queryQueue.addObjectToQuery(id: "0000_00000001", path: "/my/1", interval: 1.0e-10)
        XCTAssert(a)
        let b = queryQueue.addObjectToQuery(id: "0000_00000002", path: "/my/2", interval: 1.0e-10)
        XCTAssert(b)
        let c = queryQueue.addObjectToQuery(id: "0000_00000003", path: "/my/3", interval: 1.0e-10)
        XCTAssert(c)
        let d = queryQueue.addObjectToQuery(id: "0000_00000004", path: "/my/3", interval: 1.0e-10)
        XCTAssert(!d)

        print("queryQueue:\(queryQueue.json)")

        queryQueue.retrieved(id: "0000_00000001", success: true)
        queryQueue.retrieved(id: "0000_00000001", success: true)
        queryQueue.retrieved(id: "0000_00000001", success: true)

        print("queryQueue:\(queryQueue.json)")

        XCTAssert(queryQueue.count == 3)

        queryQueue.retrieved(id: "0000_00000001", success: false)
        queryQueue.retrieved(id: "0000_00000001", success: false)
        queryQueue.retrieved(id: "0000_00000001", success: false)
        queryQueue.retrieved(id: "0000_00000001", success: false)
        print("queryQueue:\(queryQueue.json)")
        XCTAssert(queryQueue.count == 3)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        XCTAssert(queryQueue.count == 3)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        XCTAssert(queryQueue.count == 2)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        XCTAssert(queryQueue.count == 2)
    }

    func testPerformanceExample() throws
    {
        // This is an example of a performance test case.
        self.measure
        {
            // Put the code you want to measure the time of here.
        }
    }
}
