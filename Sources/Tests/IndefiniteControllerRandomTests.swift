//
//  Created by Timothy Moose on 9/22/23.
//

import Swift
import XCTest
import Test
@testable import SwiftRepo

class IndefiniteControllerRandomTests: XCTestCase {

    // MARK: - Constants

    private typealias DelayedStep = IndefiniteControllerTests.DelayedStep
    private typealias Step = IndefiniteControllerTests.Step
    private let minRunTime: Duration = .seconds(0.1)
    private let delay: Duration = .seconds(0.1)
    private var isRunningChanged: [Bool] = []

    // MARK: - Variables

    private var controller: IndefiniteController!

    // MARK: - Tests

    /// WARNING: Use this to iterate over random API calls to generate test cases and check for assertion failures.
    /// We must keep this commented out when checking in changes.
//    func test_randomizer() async throws {
//        try await performRandom(raceConditions: false)
//    }

    /// WARNING: Use this to iterate over random API calls to generate test cases and check for assertion failures.
    /// We must keep this commented out when checking in changes.
//    func test_randomizerWithRaceConditions() async throws {
//        try await performRandom(raceConditions: true)
//    }

    private func performRandom(raceConditions: Bool) async throws {
        for testIndex in 0 ..< 1000 {
            try await setUp()
            var random = RandomNumberGeneratorWithSeed(seed: UInt64(testIndex))
            let stepCount: UInt = 3 + random.next(upperBound: 5)
            var cummulativeDelay: Duration = .zero
            var delayedSteps: [DelayedStep] = [DelayedStep(step: .start, delay: 0)]
            for _ in 0 ..< stepCount {
                let rawValue: UInt = random.next(upperBound: UInt(Step.allCases.count))
                let step = Step(rawValue: Int(rawValue))!
                // Simulate race conditions randomly by not always incrementing the delay.
                if !raceConditions || Bool.random(using: &random) {
                    let randomDelay = Double(Int64(random.next(upperBound: UInt(100_001)))) / Double(1000_000)
                    cummulativeDelay += .seconds(0.05) + (delay + minRunTime) * randomDelay
                }
                delayedSteps.append(DelayedStep(step: step, delay: cummulativeDelay))
            }
            print("randomSeed=\(testIndex), \(delayedSteps.description)")
            isRunningChanged = []
            try await perform(delayedSteps: delayedSteps, expectedIsRunningChanges: nil)
        }
    }

    // MARK: - Lifecycle

    @MainActor
    override func setUp() {
        super.setUp()
        isRunningChanged = []
        controller = IndefiniteController(delay: delay, minimumDuration: minRunTime, delegate: self)
    }

    // MARK: - Helpers

    private func perform(delayedSteps: [DelayedStep], expectedIsRunningChanges: [Bool]?) async throws {
        for delayedStep in delayedSteps {
            Task.detached(priority: .high) {
                try await Task.sleep(for: delayedStep.delay)
                switch delayedStep.step {
                case .reset: await self.controller.prepareForReuse()
                case .start: await self.controller.start()
                case .stop: await self.controller.stop()
                case .stopSync: await self.isRunningChanged.append(!self.controller.tryStoppingSynchronously())
                }
            }
        }
        let maxDelay = delayedSteps.map(\.delay).max() ?? .zero
        try await Task.sleep(for: maxDelay + minRunTime + .seconds(0.5))
        if let expectedIsRunningChanges = expectedIsRunningChanges {
            XCTAssertEqual(expectedIsRunningChanges, isRunningChanged)
        } else {
            print("isRunningChanged=\(isRunningChanged)")
        }
    }
}

extension IndefiniteControllerRandomTests: IndefiniteControllerDelegate {
    func didExceedDelayChanged(_ didExceedDelay: Bool) {
        isRunningChanged.append(didExceedDelay)
    }
}
