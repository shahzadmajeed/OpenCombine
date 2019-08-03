//
//  SubscriberList.swift
//  
//
//  Created by Sergej Jaskiewicz on 02.08.2019.
//

internal struct SubscriberList {

    internal typealias Ticket = Int

    // Apple's Combine uses Unmanaged, apparently, to avoid
    // reference counting overhead
    private var _items: [Unmanaged<AnyObject>]

    /// This array is used to locate a subscription in the `items` array.
    ///
    /// `tickets` array is always sorted, so we can use binary search to obtain an index of an item.
    private var _tickets: [Ticket]

    private var _nextTicket: Ticket

    internal init() {
        _items = []
        _tickets = []
        _nextTicket = 0
    }

    mutating func insert(_ element: AnyObject) -> Ticket {
        defer {
            _nextTicket += 1
        }

        _items.append(.passRetained(element))
        _tickets.append(_nextTicket)

        assert(_items.count == _tickets.count)

        return _nextTicket
    }

    mutating func remove(for ticket: Ticket) {
        let index = _tickets.binarySearch(ticket)
        guard index != .notFound else { return }

        _tickets.remove(at: index)
        _items[index].release()
        _items.remove(at: index)

        assert(_items.count == _tickets.count)
    }

    /// This function must be called before `self` is destroyed, otherwise we have a leak.
    mutating func removeAll() {
        _items.forEach { $0.release() }
        _items.removeAll()
    }
}

extension SubscriberList: Sequence {

    func makeIterator() -> IndexingIterator<[Unmanaged<AnyObject>]> {
        return _items.makeIterator()
    }

    var underestimatedCount: Int { return _items.underestimatedCount }

    func withContiguousStorageIfAvailable<Result>(
        _ body: (UnsafeBufferPointer<Unmanaged<AnyObject>>) throws -> Result
    ) rethrows -> Result? {
        return try _items.withContiguousStorageIfAvailable(body)
    }
}
