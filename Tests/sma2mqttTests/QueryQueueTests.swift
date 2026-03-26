//
//  QueryQueueTests.swift
//

@testable import sma2mqttLibrary
import Testing

struct QueryQueueTests
{
    @Test
    func testQueryObject()
    {
        var queryObject = QueryObject(id: "71C0_00496700", path: "/battery/battery/temperature", interval: 1, maxErrors: 4)

        #expect(queryObject.isValid)
        queryObject.increaseOK()
        queryObject.increaseOK()
        queryObject.increaseOK()
        queryObject.increaseOK()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseOK()
        queryObject.increaseOK()
        queryObject.increaseOK()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseOK()
        queryObject.increaseOK()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()

        print("queryObject:\(queryObject.json)")

        #expect(queryObject.isValid)
    }

    @Test
    func queryObject2()
    {
        var queryObject = QueryObject(id: "71C0_00496700", path: "/battery/battery/temperature", interval: 1, maxErrors: 4)

        #expect(queryObject.isValid)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        #expect(!queryObject.isValid)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        #expect(!queryObject.isValid)
        queryObject.increaseOK()
        #expect(queryObject.isValid)
        queryObject.increaseOK()
        queryObject.increaseOK()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        #expect(queryObject.isValid)
        queryObject.increaseOK()
        queryObject.increaseOK()
        #expect(queryObject.isValid)
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()
        queryObject.increaseError()

        print("queryObject:\(queryObject.json)")

        #expect(queryObject.isValid)
    }

    @Test
    func testQueryQueue()
    {
        var queryQueue = QueryQueue(address: "local", minimumRequestInterval: 1.0e-10, retryInterval: 1.0e-10, maxErrors: 3)

        let a = queryQueue.addObjectToQuery(id: "0000_00000001", path: "/my/1", interval: 1.0e-10)
        #expect(a)
        let b = queryQueue.addObjectToQuery(id: "0000_00000002", path: "/my/2", interval: 1.0e-10)
        #expect(b)
        let c = queryQueue.addObjectToQuery(id: "0000_00000003", path: "/my/3", interval: 1.0e-10)
        #expect(c)
        let d = queryQueue.addObjectToQuery(id: "0000_00000004", path: "/my/3", interval: 1.0e-10)
        #expect(!d)

        print("queryQueue:\(queryQueue.json)")

        queryQueue.retrieved(id: "0000_00000001", success: true)
        queryQueue.retrieved(id: "0000_00000001", success: true)
        queryQueue.retrieved(id: "0000_00000001", success: true)

        print("queryQueue:\(queryQueue.json)")

        #expect(queryQueue.count == 3)

        queryQueue.retrieved(id: "0000_00000001", success: false)
        queryQueue.retrieved(id: "0000_00000001", success: false)
        queryQueue.retrieved(id: "0000_00000001", success: false)
        queryQueue.retrieved(id: "0000_00000001", success: false)
        print("queryQueue:\(queryQueue.json)")
        #expect(queryQueue.count == 3)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        #expect(queryQueue.count == 3)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        #expect(queryQueue.count == 2)
        queryQueue.retrieved(id: "0000_00000002", success: false)
        #expect(queryQueue.count == 2)
    }
}
