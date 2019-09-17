//
//  SubscriberList.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.08.2019.
//

internal typealias Ticket = Int

internal struct SubscriberList {

    // Apple's Combine uses Unmanaged, apparently, to avoid
    // reference counting overhead
    private var items: [Unmanaged<AnyObject>]

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
    internal mutating func insert(_ element: Unmanaged<AnyObject>) -> Ticket {
        defer {
            nextTicket += 1
        }

        items.append(element)
        tickets.append(nextTicket)

        assert(items.count == tickets.count)

        return nextTicket
    }

    internal mutating func remove(for ticket: Ticket) {
        let index = tickets.binarySearch(ticket)
        guard index != .notFound else { return }

        tickets.remove(at: index)
        items[index].release()
        items.remove(at: index)

        assert(items.count == tickets.count)
    }

    internal var isEmpty: Bool {
        return items.isEmpty
    }

    internal func retainAll() {
        items.forEach { _ = $0.retain() }
    }
}

extension SubscriberList: Sequence {

    func makeIterator() -> IndexingIterator<[Unmanaged<AnyObject>]> {
        return items.makeIterator()
    }

    var underestimatedCount: Int { return items.underestimatedCount }

    func withContiguousStorageIfAvailable<Result>(
        _ body: (UnsafeBufferPointer<Unmanaged<AnyObject>>) throws -> Result
    ) rethrows -> Result? {
        return try items.withContiguousStorageIfAvailable(body)
    }
}
