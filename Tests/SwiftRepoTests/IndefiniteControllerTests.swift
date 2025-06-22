//
//  Created by Carter Foughty on 1/31/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation
import Testing
@testable import SwiftRepo

@MainActor
struct IndefiniteControllerTests {
    // MARK: - API

    struct DelayedStep: CustomStringConvertible {
        var step: Step
        var delay: Duration

        init(step: Step, delay: Double) {
            self.step = step
            self.delay = .seconds(delay)
        }

        init(step: Step, delay: Duration) {
            self.step = step
            self.delay = delay
        }

        var description: String {
            "DelayedStep(step: .\(step), delay: \(delay))"
        }
    }

    enum Step: Int, CaseIterable, CustomStringConvertible {
        case start
        case stop
        case stopSync
        case reset

        var description: String {
            switch self {
            case .reset: return "reset"
            case .start: return "start"
            case .stop: return "stop"
            case .stopSync: return "stopSync"
            }
        }
    }

    // MARK: - Tests

    @Test("Delay exceeded calls is running delegate")
    func delayExceededCallsIsRunningDelegate() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stop, delay: delayExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [true, false]
        )
    }

    @Test("Delay not exceeded does not call is running delegate")
    func delayNotExceededDoesNotCallIsRunningDelegate() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stop, delay: delayNotExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: []
        )
    }

    @Test("Stop sync true if delay not exceeded")
    func stopSyncTrueIfDelayNotExceeded() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stopSync, delay: delayNotExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [false]
        )
    }

    @Test("Stop sync false if delay exceeded")
    func stopSyncFalseIfDelayExceeded() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stopSync, delay: delayExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [true, true]
        )
    }

    @Test("Reset delay not exceeded does not run")
    func resetDelayNotExceededDoesNotRun() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .reset, delay: delayNotExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: []
        )
    }

    @Test("Reset delay exceeded does not stop")
    func resetDelayExceededDoesNotStop() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .reset, delay: delayExceeded),
            DelayedStep(step: .stopSync, delay: delayExceeded + .seconds(0.05)),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [true, false, false]
        )
    }

    /// A random test that was hitting an assertion failure due to a bug.
    @Test("Random test 1")
    func random1() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            // Exceeds delay at 0.1. Must run until 0.237 => `true`
            DelayedStep(step: .stop, delay: 0.1373025),
            // Still running, but this should abort that => `false`
            DelayedStep(step: .reset, delay: 0.18752749999999999),
            DelayedStep(step: .stop, delay: 0.38808),
            // Starts again
            DelayedStep(step: .start, delay: 0.572695),
            // Stops before exceeding delay
            DelayedStep(step: .stop, delay: 0.647875),
            DelayedStep(step: .stop, delay: 0.822905),
            DelayedStep(step: .reset, delay: 0.9368175),
            DelayedStep(step: .stop, delay: 1.1716374999999999),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [true, false]
        )
    }

    /// A random test.
    @Test("Random test 2")
    func random2() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .start, delay: 0.1601575),
            DelayedStep(step: .stop, delay: 0.26617250000000003),
            DelayedStep(step: .start, delay: 0.4089225),
            DelayedStep(step: .start, delay: 0.527325),
            DelayedStep(step: .reset, delay: 0.6080575),
            DelayedStep(step: .stop, delay: 0.8402575),
            DelayedStep(step: .start, delay: 0.9015275),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [true, false, true, false, true]
        )
    }

    // MARK: - Constants

    private let delay: Duration = .seconds(0.1)
    private let minRunTime: Duration = .seconds(0.1)
    private var delayNotExceeded: Duration { delay * 0.5 }
    private var delayExceeded: Duration { delay + .seconds(0.05) }
    private let sleepTolerance: Duration = .seconds(0.001)

    // MARK: - Helpers

    func perform(delayedSteps: [DelayedStep], expectedExceededDelayChanges: [Bool]?) async throws {
        final class ResultCollector: @unchecked Sendable {
            private let lock = NSLock()
            private var exceededDelayChanged: [Bool] = []
            
            func append(_ value: Bool) {
                lock.withLock {
                    exceededDelayChanged.append(value)
                }
            }
            
            func getResults() -> [Bool] {
                lock.withLock {
                    exceededDelayChanged
                }
            }
        }
        
        let resultCollector = ResultCollector()
        let controller = IndefiniteController(delay: delay, minimumDuration: minRunTime) { didExceedDelay in
            resultCollector.append(didExceedDelay)
        }
        
        let sleepToleranceLocal = sleepTolerance
        for delayedStep in delayedSteps {
            Task.detached(priority: .high) { @Sendable in
                try await Task.sleep(for: delayedStep.delay, tolerance: sleepToleranceLocal)
                switch delayedStep.step {
                case .reset: await controller.prepareForReuse()
                case .start: await controller.start()
                case .stop: await controller.stop()
                case .stopSync: await resultCollector.append(!controller.tryStoppingSynchronously())
                }
            }
        }
        let maxDelay = delayedSteps.map(\.delay).max() ?? .zero
        try await Task.sleep(for: maxDelay + minRunTime + .seconds(0.5), tolerance: sleepTolerance)
        
        let exceededDelayChanged = resultCollector.getResults()
        if let expectedIsRunningChanges = expectedExceededDelayChanges {
            #expect(expectedIsRunningChanges == exceededDelayChanged)
        } else {
            print("isRunningChanged=\(exceededDelayChanged)")
        }
    }
}
