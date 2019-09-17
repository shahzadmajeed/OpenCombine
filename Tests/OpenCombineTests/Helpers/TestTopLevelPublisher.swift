//
//  TestTopLevelPublisher.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.08.2019.
//

import GottaGoFast
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
extension PerformanceTestCase {

    func testTopLevelPublisherSubscriptionPerformance<Sut: Publisher>(
        _ sut: Sut,
        file: StaticString = #file,
        line: UInt = #line
    ) throws where Sut.Output: Equatable {
        let subscriberCount = 10000
        var subscribers = [TrackingSubscriberBase<Sut.Output, Sut.Failure>]()
        subscribers.reserveCapacity(subscriberCount)

        for _ in 0 ..< subscriberCount {
            subscribers.append(.init())
        }

        try benchmark(file: file, line: line, executionCount: 50) {
            for subscriber in subscribers {
                sut.subscribe(subscriber)
            }
        }

        XCTAssertFalse(subscribers[0].history.isEmpty, file: file, line: line)
    }

    func testTopLevelPublisherCancelSubscriptionPerformance<Sut: Publisher>(
        _ sut: Sut,
        file: StaticString = #file,
        line: UInt = #line
    ) throws where Sut.Output: Equatable {
        let subscriberCount = 100000
        var subscribers = [TrackingSubscriberBase<Sut.Output, Sut.Failure>]()
        subscribers.reserveCapacity(subscriberCount)

        var subscriptions = [Subscription]()
        subscriptions.reserveCapacity(subscriberCount)

        for _ in 0 ..< subscriberCount {
            let subscriber = TrackingSubscriberBase<Sut.Output, Sut.Failure>()
            subscribers.append(subscriber)
            sut.subscribe(subscriber)
            try subscriptions
                .append(XCTUnwrap(subscriber.subscriptions.first?.underlying))
        }

        subscriptions.shuffle()
        try benchmark(file: file, line: line, executionCount: 100) {
            for subscription in subscriptions {
                subscription.cancel()
            }
        }
    }
}
