//
//  QueryQueue.swift
//

import Foundation
import JLog

extension ObjectId: @retroactive Identifiable
{ public var id: ObjectId
    {
        self
    }
}

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
    var isValid: Bool
    {
        state.isValid
    }

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

struct QueryQueue
{
    let address: String
    let minimumRequestInterval: TimeInterval
    let retryInterval: TimeInterval
    let maxErrors: Int

    private var objectsToQuery = [ObjectId: QueryObject]()
    private var activeObjectIDsByPath = [String: ObjectId]()
    private var fallbackObjectIDsByPath = [String: [ObjectId]]()
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
    var count: Int
    {
        objectsToQueryNext.count
    }

    var isEmpty: Bool
    {
        objectsToQueryNext.isEmpty
    }

    var allOjectIds: [ObjectId]
    {
        objectsToQuery.keys.sorted()
    }

    var validObjectIds: [ObjectId]
    {
        activeObjectIDsByPath.values.compactMap
        {
            guard let object = objectsToQuery[$0], object.isValid else { return nil }
            return object.id
        }
        .sorted()
    }

    func contains(path: String) -> QueryObject?
    {
        guard let id = activeObjectIDsByPath[path] else { return nil }
        return objectsToQuery[id]
    }

    mutating func addObjectToQuery(id: ObjectId, path: String, interval: TimeInterval) -> Bool
    {
        if objectsToQuery[id] != nil
        {
            return false
        }

        let queryObject = QueryObject(id: id, path: path, interval: interval, maxErrors: maxErrors)

        if let inuse = contains(path: path)
        {
            if inuse.id != id
            {
                objectsToQuery[id] = queryObject
                fallbackObjectIDsByPath[path, default: []].append(id)
                JLog.debug("\(address): Registered fallback objectid:\(id) behind active objectid:\(inuse.id) path:\(inuse.path)")
            }
            return false
        }

        objectsToQuery[id] = queryObject
        activeObjectIDsByPath[path] = id
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
        guard let object = objectsToQuery[id],
              activeObjectIDsByPath[object.path] == id
        else
        {
            throw QueryQueueError.invalidAccess
        }

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
                if let nextID = promoteFallbackIfAvailable(path: object.path, failedID: id)
                {
                    JLog.notice("\(address): invalid request for objectid:\(id) - switching path:\(object.path) to fallback objectid:\(nextID)")
                    return
                }

                object.increaseError()
                objectsToQuery[id] = object

                if !object.isValid
                {
                    JLog.error("\(address): too many errors retrieving id:\(id) - removing")
                    removeActiveObject(id: id, path: object.path)
                }
        }
    }

    private mutating func promoteFallbackIfAvailable(path: String, failedID: ObjectId) -> ObjectId?
    {
        guard var fallbackIDs = fallbackObjectIDsByPath[path],
              let nextID = fallbackIDs.first
        else
        {
            return nil
        }

        objectsToQueryNext.remove(failedID)
        objectsToQuery.removeValue(forKey: failedID)

        fallbackIDs.removeFirst()
        if fallbackIDs.isEmpty
        {
            fallbackObjectIDsByPath.removeValue(forKey: path)
        }
        else
        {
            fallbackObjectIDsByPath[path] = fallbackIDs
        }

        activeObjectIDsByPath[path] = nextID
        objectsToQueryNext.insert(element: nextID, at: Date())
        return nextID
    }

    private mutating func removeActiveObject(id: ObjectId, path: String)
    {
        objectsToQueryNext.remove(id)
        objectsToQuery.removeValue(forKey: id)

        if activeObjectIDsByPath[path] == id
        {
            activeObjectIDsByPath.removeValue(forKey: path)
        }
    }
}
