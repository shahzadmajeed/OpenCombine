//
//  ReferencedBasedAnySubscriber.swift
//  
//
//  Created by Sergej Jaskiewicz on 17/09/2019.
//

internal final class _ReferencedBasedAnySubscriber<Input, Failure: Error>: Subscriber {

    private let box: Unmanaged<AnySubscriberBase<Input, Failure>>

    private let descriptionThunk: () -> String

    private let customMirrorThunk: () -> Mirror

    private let playgroundDescriptionThunk: () -> Any

    internal let combineIdentifier: CombineIdentifier

    @inline(__always)
    internal init<Subscriber: OpenCombine.Subscriber>(_ subscriber: Subscriber)
        where Subscriber.Input == Input, Subscriber.Failure == Failure
    {
        let anySubscriber = AnySubscriber(subscriber)
        box = .passRetained(anySubscriber.box)
        descriptionThunk = anySubscriber.descriptionThunk
        customMirrorThunk = anySubscriber.customMirrorThunk
        playgroundDescriptionThunk = anySubscriber.playgroundDescriptionThunk
        combineIdentifier = anySubscriber.combineIdentifier
    }

    @inline(__always)
    internal func receive(subscription: Subscription) {

    }

    @inline(__always)
    internal func receive(_ input: Input) -> Subscribers.Demand {
        return box.takeUnretainedValue().receive(input)
    }

    @inline(__always)
    internal func receive(completion: Subscribers.Completion<Failure>) {

    }

    deinit {

    }
}

extension _ReferencedBasedAnySubscriber: CustomStringConvertible {

    internal var description: String { return descriptionThunk() }
}

extension _ReferencedBasedAnySubscriber: CustomReflectable {

    internal var customMirror: Mirror { return customMirrorThunk() }
}

extension _ReferencedBasedAnySubscriber: CustomPlaygroundDisplayConvertible {

    internal var playgroundDescription: Any { return playgroundDescriptionThunk() }
}
