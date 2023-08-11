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
}

extension QueryObject: Codable {}
// extension QueryObject:Identifiable { var id:ObjectId { objectid } }

struct QueryQueue
{
    let address: String
    let minimumRequestInterval: TimeInterval
    let retryInterval: TimeInterval

    var errorcounter = [ObjectId: Int]()
    var objectsToQuery = [ObjectId: QueryObject]()
    var objectsToQueryNext = DatedQueue<ObjectId>()

    enum QueryQueueError: Error
    {
        case invalidAccess
    }
}

extension QueryQueue: Codable {}

extension QueryQueue
{
    public var count: Int { objectsToQueryNext.count }
    public var isEmpty: Bool { objectsToQueryNext.isEmpty }
    public var allOjectIds: [ObjectId] { Array(objectsToQuery.keys) }
    public var validObjectIds: [ObjectId] { objectsToQueryNext.sortedArray.map(\.element.id) }

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

        objectsToQuery[id] = QueryObject(id: id, path: path, interval: interval)
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
        switch success
        {
            case true: guard let object = objectsToQuery[id]
                else
                {
                    JLog.error("\(address): retrieved unkown id:\(id)")
                    return
                }
                objectsToQueryNext.insert(element: id, at: Date(timeIntervalSinceNow: object.interval))
                errorcounter[id] = Int.min

            case false: let counter = errorcounter[id, default: 0] + 1
                errorcounter[id] = counter

                JLog.error("\(address): error retrieving id:\(id) \(counter)")

                if counter > 10
                {
                    JLog.error("\(address): too many errors retrieving id:\(id) - removing")
                    objectsToQueryNext.remove(id)
                }
        }
    }
}
