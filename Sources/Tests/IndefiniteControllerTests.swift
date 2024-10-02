//
//  Created by Carter Foughty on 1/31/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import XCTest
@testable import SwiftRepo

class IndefiniteControllerTests: XCTestCase {
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

    func test_delayExceeded_callsIsRunningDelegate() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stop, delay: delayExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [true, false]
        )
    }

    func test_delayNotExceeded_doesNotCallIsRunningDelegate() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stop, delay: delayNotExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: []
        )
    }

    func test_stopSync_trueIfDelayNotExceeded() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stopSync, delay: delayNotExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [false]
        )
    }

    func test_stopSync_falseIfDelayExceeded() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .stopSync, delay: delayExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: [true, true]
        )
    }

    func test_resetDelayNotExceeded_doesNotRun() async throws {
        let delayedSteps = [
            DelayedStep(step: .start, delay: 0),
            DelayedStep(step: .reset, delay: delayNotExceeded),
        ]
        try await perform(
            delayedSteps: delayedSteps,
            expectedExceededDelayChanges: []
        )
    }

    func test_resetDelayExceeded_doesNotStop() async throws {
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
    func test_random1() async throws {
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
    func test_random2() async throws {
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

    // MARK: - Variables

    private var exceededDelayChanged: [Bool] = []
    private var controller: IndefiniteController!

    // MARK: - Lifecycle

    @MainActor
    override func setUp() {
        super.setUp()
        exceededDelayChanged = []
        controller = IndefiniteController(delay: delay, minimumDuration: minRunTime, delegate: self)
    }

    // MARK: - Helpers

    func perform(delayedSteps: [DelayedStep], expectedExceededDelayChanges: [Bool]?) async throws {
        for delayedStep in delayedSteps {
            Task.detached(priority: .high) {
                try await Task.sleep(for: delayedStep.delay, tolerance: self.sleepTolerance)
                switch delayedStep.step {
                case .reset: await self.controller.prepareForReuse()
                case .start: await self.controller.start()
                case .stop: await self.controller.stop()
                case .stopSync: await self.exceededDelayChanged.append(!self.controller.tryStoppingSynchronously())
                }
            }
        }
        let maxDelay = delayedSteps.map(\.delay).max() ?? .zero
        try await Task.sleep(for: maxDelay + minRunTime + .seconds(0.5), tolerance: sleepTolerance)
        if let expectedIsRunningChanges = expectedExceededDelayChanges {
            XCTAssertEqual(expectedIsRunningChanges, exceededDelayChanged)
        } else {
            print("isRunningChanged=\(exceededDelayChanged)")
        }
    }
}

extension IndefiniteControllerTests: IndefiniteControllerDelegate {
    func didExceedDelayChanged(_ didExceedDelay: Bool) {
        exceededDelayChanged.append(didExceedDelay)
    }
}
