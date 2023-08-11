//
//  DatedQueue.swift
//

import Foundation

struct DatedQueue<Element: Identifiable> where Element: Codable
{
    internal struct InternalElement: Codable
    {
        let date: Date
        let element: Element
    }

    enum DatedQueueError: Error
    {
        case invalidAccess
        case noPacketsInQueue
    }

    internal var sortedArray = [InternalElement]()
}

extension DatedQueue: Codable {}

extension DatedQueue
{
    var count: Int { sortedArray.count }
    var isEmpty: Bool { sortedArray.isEmpty }

    func next() -> (element: Element, date: Date)?
    {
        guard let first = sortedArray.first else { return nil }
        return (element: first.element, date: first.date)
    }

    mutating func remove(_ element: Element)
    {
        sortedArray.removeAll { $0.element.id == element.id }
    }

    mutating func removeNext() throws -> (element: Element, date: Date)
    {
        guard !sortedArray.isEmpty else { throw DatedQueueError.invalidAccess }
        let first = sortedArray.removeFirst()
        return (element: first.element, date: first.date)
    }

    func waitNext() throws -> (element: Element, date: Date)
    {
        guard let first = next() else { throw DatedQueueError.noPacketsInQueue }

        if first.date.timeIntervalSinceNow > 0
        {
            Thread.sleep(until: first.date)
        }
        return first
    }

    mutating func insert(element: Element, at date: Date)
    {
        let newElement = InternalElement(date: date, element: element)

        // TODO: Binary Search By using Dictionary to remeber date for ID
        remove(element)

        // TODO: Binary Search
        if let firstIndex = sortedArray.firstIndex(where: { $0.date > date })
        {
            sortedArray.insert(newElement, at: firstIndex)
        }
        else
        {
            sortedArray.append(newElement)
        }
    }
}
