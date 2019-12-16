//
//  RunLoopSchedulerTests.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.12.2019.
//

import Dispatch
import Foundation
import XCTest

#if OPENCOMBINE_COMPATIBILITY_TEST
import Combine
#else
import OpenCombine
import OpenCombineFoundation
#endif

@available(macOS 10.15, iOS 13.0, *)
final class RunLoopSchedulerTests: XCTestCase {

    private func executeOnBackgroundThread<ResultType>(
        _ body: @escaping () -> ResultType
    ) -> ResultType {
        var result: ResultType?
        let semaphore = DispatchSemaphore(value: 0)
        Thread {
            result = body()
            semaphore.signal()
        }.start()
        semaphore.wait()
        return result!
    }

    func testScheduleNow() {
        let runLoop = RunLoop.main
        var counter = 0
        executeOnBackgroundThread {
            makeScheduler(runLoop).schedule {
                XCTAssertTrue(Thread.isMainThread)
                counter += 1
                RunLoop.current.run(until: Date())
            }
        }
        XCTAssertEqual(counter, 0)
        runLoop.run(until: Date())
        XCTAssertEqual(counter, 1)
    }

    func testScheduleAfterDate() {
        let runLoop = RunLoop.main
        var counter = 0
        executeOnBackgroundThread {
            let scheduler = makeScheduler(runLoop)
            scheduler
                .schedule(after: scheduler.now.advanced(by: .milliseconds(200))) {
                    // This is a bug in Combine! (FB7493579)
                    // This should be XCTAssertTrue. When they fix it, this test will fail
                    // and we'll know to fix our implementation.
                    XCTAssertFalse(Thread.isMainThread)
                    counter += 1
                }
            RunLoop.current.run(until: Date() + 0.25)
        }
        /*
        XCTAssertEqual(counter, 0)
        runLoop.run(until: Date())
        XCTAssertEqual(counter, 0)
        runLoop.run(until: Date() + 0.05)
        XCTAssertEqual(counter, 0)
        runLoop.run(until: Date() + 0.05)
        */
        XCTAssertEqual(counter, 1)
    }

    func testSchedulerWithInterval() {
        let runLoop = RunLoop.main
        var counter = 0
        let cancellable = executeOnBackgroundThread { () -> Cancellable in
            let scheduler = makeScheduler(runLoop)
            return scheduler
                .schedule(after: scheduler.now.advanced(by: .milliseconds(500)),
                          interval: .milliseconds(50)) {
                    XCTAssertTrue(Thread.isMainThread)
                    counter += 1
                    RunLoop.current.run(until: Date())
                }
        }
        XCTAssertEqual(counter, 0)
        runLoop.run(until: Date())
        XCTAssertEqual(counter, 0)
        runLoop.run(until: Date() + 0.2) // 200 ms passed
        XCTAssertEqual(counter, 0)
        runLoop.run(until: Date() + 0.31) // 510 ms passed
        XCTAssertEqual(counter, 1)
        runLoop.run(until: Date() + 0.07) // 580 ms passed
        XCTAssertEqual(counter, 2)
        runLoop.run(until: Date() + 0.05) // 630 ms passed
        XCTAssertEqual(counter, 3)
        cancellable.cancel()
        runLoop.run(until: Date() + 0.5)
        XCTAssertEqual(counter, 3)
    }
}

#if OPENCOMBINE_COMPATIBILITY_TEST || !canImport(Combine)
func makeScheduler(_ runLoop: RunLoop) -> RunLoop {
    return runLoop
}
#else
func makeScheduler(_ runLoop: RunLoop) -> RunLoop.OCombine {
    return runLoop.ocombine
}
#endif
