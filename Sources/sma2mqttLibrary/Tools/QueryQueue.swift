//
//  QueryQueue.swift
//

import Foundation
import JLog

extension ObjectId: Identifiable { public var id: ObjectId { self } }

struct QueryObject
{
    let id: ObjectId
    let path: String
    let interval: TimeInterval
    private var state: ConnectionState

    init(id: ObjectId, path: String, interval: TimeInterval, maxErrors: Int)
    {
        self.id = id
        self.path = path
        self.interval = interval
        state = ConnectionState(maxErrors: maxErrors)
    }
}

extension QueryObject: Codable {}
extension QueryObject
{
    var isValid: Bool { state.isValid }

    mutating func increaseError()
    {
        state.increaseError()
    }

    mutating func increaseOK()
    {
        state.increaseOK()
    }
}

// extension QueryObject:Identifiable { var id:ObjectId { objectid } }

struct ConnectionState
{
    let maxErrors: Int

    enum Interval: Codable
    {
        case error(interval: DateInterval, count: Int)
        case ok(interval: DateInterval, count: Int)
    }

    private var intervalStart = Date()
    private var counter = 0 // errors < 0 , ok > 0
    private(set) var history = [Interval]()

    init(maxErrors: Int)
    {
        self.maxErrors = maxErrors
    }
}

extension ConnectionState: Codable {}

extension ConnectionState
{
    var isValid: Bool
    {
        guard history.isEmpty else { return true }

        return counter > -maxErrors
    }

    mutating func increaseError()
    {
        switch counter
        {
            case let x where x > 0:
                history.append(Interval.ok(interval: DateInterval(start: intervalStart, end: Date()), count: counter))
                fallthrough
            case 0: counter = -1
                intervalStart = Date()

            default: counter -= 1
        }
    }

    mutating func increaseOK()
    {
        switch counter
        {
            case let x where x < 0:
                history.append(Interval.error(interval: DateInterval(start: intervalStart, end: Date()), count: counter))
                fallthrough
            case 0:
                counter = 1
                intervalStart = Date()

            default: counter += 1
        }
    }
}

struct QueryQueue: Sendable
{
    let address: String
    let minimumRequestInterval: TimeInterval
    let retryInterval: TimeInterval
    let maxErrors: Int

    private var objectsToQuery = [ObjectId: QueryObject]()
    private var objectsToQueryNext = DatedQueue<ObjectId>()

    enum QueryQueueError: Error
    {
        case invalidAccess
    }

    init(address: String, minimumRequestInterval: TimeInterval, retryInterval: TimeInterval, maxErrors: Int = 10)
    {
        self.address = address
        self.minimumRequestInterval = minimumRequestInterval
        self.retryInterval = retryInterval
        self.maxErrors = maxErrors
    }
}

extension QueryQueue: Codable {}

extension QueryQueue
{
    public var count: Int { objectsToQueryNext.count }
    public var isEmpty: Bool { objectsToQueryNext.isEmpty }
    public var allOjectIds: [ObjectId] { Array(objectsToQuery.keys) }
    public var validObjectIds: [ObjectId] { objectsToQuery.values.compactMap { $0.isValid ? $0.id : nil } }

    func contains(path: String) -> QueryObject?
    {
        objectsToQuery.values.first(where: { $0.path == path })
    }

    mutating func addObjectToQuery(id: ObjectId, path: String, interval: TimeInterval) -> Bool
    {
        if let inuse = contains(path: path)
        {
            if inuse.id != id
            {
                JLog.notice("\(address): Won't query objectid:\(id) - object with same path:\(inuse.id) path:\(inuse.path)")
            }
            return false
        }

        objectsToQuery[id] = QueryObject(id: id, path: path, interval: interval, maxErrors: maxErrors)
        objectsToQueryNext.insert(element: id, at: Date(timeIntervalSinceNow: interval / 100.0))

        return true
    }

    func waitForNextObjectId() async throws -> ObjectId
    {
        let (id, _) = try await objectsToQueryNext.waitNext()
        return id
    }

    mutating func shouldRetry(id: ObjectId) throws
    {
        guard objectsToQuery[id] != nil else { throw QueryQueueError.invalidAccess }
        objectsToQueryNext.insert(element: id, at: Date(timeIntervalSinceNow: retryInterval))
    }

    mutating func retrieved(id: ObjectId, success: Bool)
    {
        guard var object = objectsToQuery[id]
        else
        {
            JLog.error("\(address): retrieved unkown id:\(id)")
            return
        }

        switch success
        {
            case true:
                objectsToQueryNext.insert(element: id, at: Date(timeIntervalSinceNow: object.interval))
                object.increaseOK()
                objectsToQuery[id] = object

            case false:
                object.increaseError()
                objectsToQuery[id] = object

                if !object.isValid
                {
                    JLog.error("\(address): too many errors retrieving id:\(id) - removing")
                    objectsToQueryNext.remove(id)
                }
        }
    }
}
