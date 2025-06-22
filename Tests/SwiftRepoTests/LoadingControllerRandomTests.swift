//
//  Created by Timothy Moose on 1/28/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import Testing
import SwiftRepoCore
import SwiftRepoTest
@testable import SwiftRepo

// swiftlint:disable implicitly_unwrapped_optional force_unwrapping fatal_error_message

@MainActor
struct LoadingControllerRandomTests {
    // MARK: - Tests

    // MARK: - Generating random tests

    /// WARNING: Use this to iterate over random API calls to generate test cases and check for assertion failures.
    /// We must keep this commented out when checking in changes.
//    @Test("Randomizer")
//    func randomizer() async throws {
//        try await performRandom(raceConditions: false)
//    }
//
    /// WARNING: Use this to iterate over random API calls to generate test cases and check for assertion failures.
    /// We must keep this commented out when checking in changes.
//    @Test("Randomizer with race conditions")
//    func randomizerWithRaceConditions() async throws {
//        try await performRandom(raceConditions: true)
//    }

    private func performRandom(raceConditions: Bool) async throws {
        for testIndex in 0 ..< 1000 {
            let testState = TestState()
            var random: RandomNumberGenerator = RandomNumberGeneratorWithSeed(seed: UInt64(testIndex))
            let initialData = testState.makeInitialData(random: &random)
            let loadingBehavior = testState.makeLoadingBehavior(random: &random)
            let stepCount: UInt = 3 + random.next(upperBound: 10)
            var cummulativeDelay: TimeInterval = 0
            var delayedSteps: [TestState.DelayedStep] = [TestState.DelayedStep(step: .loading, delay: 0)]
            for _ in 0 ..< stepCount {
                delayedSteps.append(testState.makeDelayedStep(random: &random, cummulativeDelay: &cummulativeDelay, raceConditions: raceConditions))
            }
            print(
                "randomSeed=\(testIndex), "
                    + "data=\(initialData?.description ?? "none"), "
                    + "behavior=\(loadingBehavior?.description ?? "none") "
                    + "\(delayedSteps.description)"
            )
            try await testState.perform(loadingBehavior: loadingBehavior, initialData: initialData, delayedSteps: delayedSteps, expectedStates: nil)
        }
    }
}

// MARK: - Test State Helper

@MainActor
private class TestState {
    // MARK: - Constants

    let delay: TimeInterval = 0.1
    let minRunTime: TimeInterval = 0.1
    var delayNotExceeded: TimeInterval { delay * 0.5 }
    var delayExceeded: TimeInterval { delay + 0.05 }

    typealias ControllerType = LoadingController<Data>

    enum Step: CustomStringConvertible {
        case loading
        case success(Data)
        case failure
        case reset

        var description: String {
            switch self {
            case .loading: return "loading"
            case let .success(data): return "success(.\(data))"
            case .failure: return "failure"
            case .reset: return "reset"
            }
        }

        static func random(using random: inout RandomNumberGenerator) -> Step {
            switch random.next(upperBound: UInt(4)) {
            case 0: return .loading
            case 1: return .success(.allCases.randomElement(using: &random)!)
            case 2: return .failure
            case 3: return .reset
            default: fatalError()
            }
        }
    }

    struct DelayedStep: CustomStringConvertible {
        var step: Step
        var delay: TimeInterval

        var description: String {
            "DelayedStep(step: .\(step), delay: \(delay))"
        }
    }

    enum Data: String, Error, CaseIterable, Emptyable, CustomStringConvertible {
        case empty
        case one
        case two
        case three

        var isEmpty: Bool {
            self == .empty
        }

        var description: String {
            rawValue
        }
    }

    // MARK: - Variables

    var controller: ControllerType!
    var spy: PublisherSpy<ControllerType.State>!
    var resultSubject = PassthroughSubject<ControllerType.ResultType, Never>()

    // MARK: - Helpers

    func makeInitialData(random: inout RandomNumberGenerator) -> Data? {
        guard Bool.random(using: &random) else { return nil }
        return Data.allCases.randomElement(using: &random)
    }

    func makeLoadingBehavior(random: inout RandomNumberGenerator) -> ControllerType.LoadingBehavior? {
        guard Bool.random(using: &random) else { return nil }
        return ControllerType.LoadingBehavior(
            delay: .zero,
            minimumDuration: .zero,
            loadedErrorsToEmpty: Bool.random(using: &random)
        )
    }

    func makeDelayedStep(
        random: inout RandomNumberGenerator,
        cummulativeDelay: inout TimeInterval,
        raceConditions _: Bool
    ) -> DelayedStep {
        let step = Step.random(using: &random)
        // Simulate race conditions by not always incrementing the delay
        if Bool.random(using: &random) {
            cummulativeDelay += 0.05 + TimeInterval(integerLiteral: Int64(random.next(upperBound: UInt(100_001))))
                / 100_000
                * (delay + minRunTime)
        }
        return DelayedStep(step: step, delay: cummulativeDelay)
    }

    func perform(
        loadingBehavior: ControllerType.LoadingBehavior?,
        initialData: Data?,
        delayedSteps: [DelayedStep],
        expectedStates: [ControllerType.State]?
    ) async throws {
        await setUp(loadingBehavior: loadingBehavior, initialData: initialData)
        for delayedStep in delayedSteps {
            Task.detached(priority: .high) { @Sendable in
                try await Task.sleep(for: .seconds(delayedStep.delay))
                switch delayedStep.step {
                case .loading: await self.controller.loading()
                case let .success(data):
                    // The loading controller's subject isn't properly actor-isolated and must be called
                    // from the main queue in order to avoid race conditions.
                    Task { @MainActor in
                        self.resultSubject.send(.success(data))
                    }
                case .failure:
                    // The loading controller's subject isn't properly actor-isolated and must be called
                    // from the main queue in order to avoid race conditions.
                    Task { @MainActor in
                        self.resultSubject.send(.failure(Data.empty))
                    }
                case .reset: await self.controller.reset()
                }
            }
        }
        let maxDelay = delayedSteps.map(\.delay).max() ?? 0
        try await Task.sleep(for: .seconds(maxDelay + minRunTime + 0.5))
        if let expectedStates = expectedStates {
            #expect(expectedStates == spy.publishedValues)
        } else {
            print("states=\(spy.publishedValues)")
        }
    }

    func setUp(loadingBehavior: ControllerType.LoadingBehavior?, initialData: Data?) async {
        controller = LoadingController<Data>(loadingBehavior: loadingBehavior, data: initialData)
        spy = PublisherSpy(controller.state)
        resultSubject.receive(subscriber: controller.resultSubscriber)
    }
}

extension LoadingController.LoadingBehavior: CustomStringConvertible {
    public var description: String {
        "delay=\(delay), minDuration=\(minimumDuration), loadedErrorsToEmpty=\(loadedErrorsToEmpty)"
    }
}
