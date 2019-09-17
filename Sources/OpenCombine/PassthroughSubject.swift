//
//  PassthroughSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

import COpenCombineHelpers

/// A subject that passes along values and completion.
///
/// Use a `PassthroughSubject` in unit tests when you want a publisher than can publish
/// specific values on-demand during tests.
public final class PassthroughSubject<Output, Failure: Error>: Subject {

    private let lock = UnfairRecursiveLock.allocate()

    private var active = true

    private var completion: Subscribers.Completion<Failure>?

    private var downstreams = SubscriberList()

    private var upstreamSubscriptions = [Subscription]()

    private var hasAnyDownstreamDemand = false

    public init() {}

    deinit {
//        for subscription in downstreams {
//            subscription._downstream = nil
//        }
		lock.deallocate()
    }

    public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
    {
//        lock.do {
//            if let completion = completion {
//                subscriber.receive(subscription: Subscriptions.empty)
//                subscriber.receive(completion: completion)
//                return
//            } else {
//                let subscription = Conduit(self, subscriber)
//                subscriber.receive(subscription: subscription)
//            }
//        }
    }

    public func send(subscription: Subscription) {
        lock.lock()
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        if hasAnyDownstreamDemand {
            subscription.request(.unlimited)
        }
    }

    public func send(_ input: Output) {
        lock.lock()
        guard active, hasAnyDownstreamDemand else {
            lock.unlock()
            return
        }
        let downstreams = self.downstreams
        downstreams.retainAll()
        lock.unlock()
        for downstream in downstreams {
            unsafeDowncast(downstream.takeUnretainedValue(), to: Conduit.self)
                .offer(input)
            downstream.release()
        }
    }

    public func send(completion: Subscribers.Completion<Failure>) {
        lock.lock()
        guard active else {
            lock.unlock()
            return
        }
        active = false
        self.completion = completion
        let downstreams = self.downstreams
        lock.unlock()
        for downstream in downstreams {
            unsafeDowncast(downstream.takeUnretainedValue(), to: Conduit.self)
                .finish(completion: completion)
            downstream.release() // Release each conduit one last time
        }
    }

    private func acknowledgeDownstreamDemand() {
        lock.lock()
        if hasAnyDownstreamDemand {
            lock.unlock()
            return
        }
        hasAnyDownstreamDemand = true
        lock.unlock()
        for subscription in upstreamSubscriptions {
            subscription.request(.unlimited)
        }
    }

    private func disassociate(_ ticket: Ticket) {
//        downstreams.remove(for: ticket)
    }
}

extension PassthroughSubject {

    fileprivate final class Conduit: Subscription {

        private let erasedParent: Unmanaged<PassthroughSubject>

        private let erasedDownstream:
            Unmanaged<_ReferencedBasedAnySubscriber<Output, Failure>>

        private var identity: Ticket!

        private var released = false

        private var demand = Subscribers.Demand.none

        private let lock = unfairLock()

        private let downstreamLock = unfairRecursiveLock()

        fileprivate init<Downstream: Subscriber>(_ parent: PassthroughSubject,
                                                 _ downstream: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            erasedParent = .passRetained(parent)
            erasedDownstream = .passRetained(_ReferencedBasedAnySubscriber(downstream))
            identity = parent.downstreams.insert(.passRetained(self))
        }

        fileprivate func offer(_ value: Output) {
            lock.lock()
            guard demand > 0, !released else {
                lock.unlock()
                return
            }
            demand -= 1
            let retainedDownstream = erasedDownstream.retain()
            lock.unlock()
            downstreamLock.lock()
            let downstream = retainedDownstream.takeUnretainedValue()
            let newDemand = downstream.receive(value)
            retainedDownstream.release()
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            lock.lock()
            demand += newDemand
            lock.unlock()
        }

        fileprivate func finish(completion: Subscribers.Completion<Failure>) {
            release {
                downstreamLock.lock()
                erasedDownstream.takeUnretainedValue().receive(completion: completion)
                downstreamLock.unlock()
            }
        }

        private func release(_ body: () -> Void) {
            lock.lock()
            if released {
                lock.unlock()
                return
            }
            released = true
            lock.unlock()
            // `disassociate` will lock again
            erasedParent.takeUnretainedValue().disassociate(identity)
            body()
            erasedParent.release()
            erasedDownstream.release()
        }

        fileprivate func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            if released {
                lock.unlock()
                return
            }
            self.demand += demand
            let parent = erasedParent.retain().takeUnretainedValue()
            lock.unlock()
            parent.acknowledgeDownstreamDemand()
            erasedParent.release()
        }

        fileprivate func cancel() {
            release {}
        }

        deinit {
            if !released {
                erasedParent.release()
                erasedDownstream.release()
            }
        }
    }
}

extension PassthroughSubject.Conduit: CustomStringConvertible {
    fileprivate var description: String { return "PassthroughSubject" }
}

extension PassthroughSubject.Conduit: CustomReflectable {
    fileprivate var customMirror: Mirror {
        let children: [(label: String, value: Any)] = [
            ("parent", erasedParent.takeUnretainedValue()),
            ("downstream", erasedDownstream.takeUnretainedValue()),
            ("demand", demand),
            ("subject", erasedParent.takeUnretainedValue())
        ]
        return Mirror(self, children: children)
    }
}

extension PassthroughSubject.Conduit: CustomPlaygroundDisplayConvertible {
    fileprivate var playgroundDescription: Any { return description }
}
