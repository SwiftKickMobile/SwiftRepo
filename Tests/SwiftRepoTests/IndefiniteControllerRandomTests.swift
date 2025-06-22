//
//  Created by Timothy Moose on 9/22/23.
//

import Swift
import Testing
import SwiftRepoTest
@testable import SwiftRepo

@MainActor
struct IndefiniteControllerRandomTests {

    // MARK: - Constants

    private typealias DelayedStep = IndefiniteControllerTests.DelayedStep
    private typealias Step = IndefiniteControllerTests.Step
    private let minRunTime: Duration = .seconds(0.1)
    private let delay: Duration = .seconds(0.1)

    // MARK: - Tests

    /// WARNING: Use this to iterate over random API calls to generate test cases and check for assertion failures.
    /// We must keep this commented out when checking in changes.
//    @Test("Randomizer")
//    func randomizer() async throws {
//        try await performRandom(raceConditions: false)
//    }

    /// WARNING: Use this to iterate over random API calls to generate test cases and check for assertion failures.
    /// We must keep this commented out when checking in changes.
//    @Test("Randomizer with race conditions")
//    func randomizerWithRaceConditions() async throws {
//        try await performRandom(raceConditions: true)
//    }

    private func performRandom(raceConditions: Bool) async throws {
        for testIndex in 0 ..< 1000 {
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
            try await perform(delayedSteps: delayedSteps, expectedIsRunningChanges: nil)
        }
    }

    // MARK: - Helpers

    private func perform(delayedSteps: [DelayedStep], expectedIsRunningChanges: [Bool]?) async throws {
        actor ResultCollector {
            private var isRunningChanged: [Bool] = []
            
            func append(_ value: Bool) {
                isRunningChanged.append(value)
            }
            
            func getResults() -> [Bool] {
                isRunningChanged
            }
        }
        
        let resultCollector = ResultCollector()
        let controller = IndefiniteController(delay: delay, minimumDuration: minRunTime) { didExceedDelay in
            Task { await resultCollector.append(didExceedDelay) }
        }
        
        for delayedStep in delayedSteps {
            Task.detached(priority: .high) { @Sendable in
                try await Task.sleep(for: delayedStep.delay)
                switch delayedStep.step {
                case .reset: await controller.prepareForReuse()
                case .start: await controller.start()
                case .stop: await controller.stop()
                case .stopSync: await resultCollector.append(!controller.tryStoppingSynchronously())
                }
            }
        }
        let maxDelay = delayedSteps.map(\.delay).max() ?? .zero
        try await Task.sleep(for: maxDelay + minRunTime + .seconds(0.5))
        
        let isRunningChanged = await resultCollector.getResults()
        if let expectedIsRunningChanges = expectedIsRunningChanges {
            #expect(expectedIsRunningChanges == isRunningChanged)
        } else {
            print("isRunningChanged=\(isRunningChanged)")
        }
    }
}
