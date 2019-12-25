//
//  CatchTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.12.2019.
//

import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
#endif

@available(macOS 10.15, iOS 13.0, *)
final class CatchTests: XCTestCase {

    // MARK: - Catch

    func testSimpleCatch() {
        CatchTests.testWithSequence { upstream, newPublisher in
            upstream.catch { _ in newPublisher }
        }
    }

    func testCatchReflection() throws {
        try testReflection(parentInput: Int.self,
                           parentFailure: TestingError.self,
                           description: "Catch",
                           customMirror: expectedChildren(
                               ("downstream", .contains("TrackingSubscriberBase")),
                               ("demand", "max(0)")
                           ),
                           playgroundDescription: "Catch",
                           { $0.catch(Fail.init) })

        try testReflection(
            parentInput: Int.self,
            parentFailure: TestingError.self,
            description: "Catch",
            customMirror: expectedChildren(
                ("downstream", .contains("TrackingSubscriberBase")),
                ("demand", "max(0)")
            ),
            playgroundDescription: "Catch",
            { publisher in
                Fail<Int, TestingError>(error: .oops).catch { _ in publisher }
            }
        )
    }

    // MARK: - TryCatch

    // MARK: - Generic tests

    private typealias TestSequence = Publishers.Sequence<[Int], Never>

    private static func testWithSequence<Operator: Publisher>(
        _ makeCatch: (Publishers.TryMap<TestSequence, Int>, TestSequence) -> Operator
    ) where Operator.Output == Int {
        let throwingSequence = TestSequence(sequence: Array(0 ..< 10))
            .tryMap { v -> Int in
                if v < 5 {
                    return v
                } else {
                    throw TestingError.oops
                }
            }

        let `catch` = makeCatch(throwingSequence, [3, 2, 1, 0].publisher)

        let tracking = TrackingSubscriberBase<Int, Operator.Failure>(
            receiveSubscription: { $0.request(.max(1)) },
            receiveValue: { _ in .max(1) }
        )
        `catch`.subscribe(tracking)

        XCTAssertEqual(tracking.history, [.subscription("Catch"),
                                          .value(0),
                                          .value(1),
                                          .value(2),
                                          .value(3),
                                          .value(4),
                                          .value(3),
                                          .value(2),
                                          .value(1),
                                          .value(0),
                                          .completion(.finished)])
    }
}
