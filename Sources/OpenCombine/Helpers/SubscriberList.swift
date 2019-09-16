//
//  SubscriberList.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.08.2019.
//

internal struct SubscriberList<Subscription: AnyObject> {

    internal typealias Ticket = Int

    // Apple's Combine uses Unmanaged, apparently, to avoid
    // reference counting overhead
    private var items: [Unmanaged<Subscription>]

    /// This array is used to locate a subscription in the `items` array.
    ///
    /// `tickets` array is always sorted, so we can use binary search to obtain an index
    /// of an item.
    private var tickets: [Ticket]

    private var nextTicket: Ticket

    internal init() {
        items = []
        tickets = []
        nextTicket = 0
    }

    /// `element` should be passed retained.
    mutating func insert(_ element: Unmanaged<Subscription>) -> Ticket {
        defer {
            nextTicket += 1
        }

        items.append(element)
        tickets.append(nextTicket)

        assert(items.count == tickets.count)

        return nextTicket
    }

    mutating func remove(for ticket: Ticket) {
        let index = tickets.binarySearch(ticket)
        guard index != .notFound else { return }

        tickets.remove(at: index)
        items[index].release()
        items.remove(at: index)

        assert(items.count == tickets.count)
    }

    /// This function must be called before `self` is destroyed, otherwise we have a leak.
    mutating func removeAll() {
        items.forEach { $0.release() }
        items.removeAll()
    }
}

extension SubscriberList: Sequence {

    func makeIterator() -> IndexingIterator<[Unmanaged<Subscription>]> {
        return items.makeIterator()
    }

    var underestimatedCount: Int { return items.underestimatedCount }

    func withContiguousStorageIfAvailable<Result>(
        _ body: (UnsafeBufferPointer<Unmanaged<Subscription>>) throws -> Result
    ) rethrows -> Result? {
        return try items.withContiguousStorageIfAvailable(body)
    }
}
