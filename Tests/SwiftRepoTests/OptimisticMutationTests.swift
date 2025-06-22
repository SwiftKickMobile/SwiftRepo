//
//  Created by Timothy Moose on 6/29/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation
import Testing
import SwiftRepoTest
@testable import SwiftRepo

@MainActor
struct OptimisticMutationTests {
    
    @Test("Mutation remote success stored values")
    func mutationRemoteSuccessStoredValues() async throws {
        let testState = TestState()
        #expect(testState.store.get(key: testState.key) == testState.zero)
        let mutation = testState.makeMutation()
        testState.remoteMutationResults = DelayedValues<String>(values: [
            .makeValue(testState.three) // Success response
        ])
        Task { try await mutation.mutate(id: testState.key, variables: testState.one) }
        try await Task.sleep(for: .seconds(0.05))
        _ = testState.store.set(key: testState.key, value: testState.one)
        #expect(testState.store.get(key: testState.key) == testState.one)
        Task { try await mutation.mutate(id: testState.key, variables: testState.two) }
        try await Task.sleep(for: .seconds(0.05))
        _ = testState.store.set(key: testState.key, value: testState.two)
        #expect(testState.store.get(key: testState.key) == testState.two)
        // Since we're debouncing, the remote mutation shouldn't have happened yet.
        _ = testState.store.set(key: testState.key, value: testState.three)
        #expect(testState.store.get(key: testState.key) == testState.three)
        try await Task.sleep(for: .seconds(0.1))
        // Now, the remote mutation should have been called once.
        _ = testState.store.set(key: testState.key, value: testState.three)
        #expect(testState.store.get(key: testState.key) == testState.three)
    }

    @Test("Mutation remote failure revert to original")
    func mutationRemoteFailureRevertToOriginal() async throws {
        let testState = TestState()
        #expect(testState.store.get(key: testState.key) == testState.zero)
        let mutation = testState.makeMutation()
        testState.remoteMutationResults = DelayedValues<String>(values: [
            .makeError(TestError(category: .failure)), // Failure response
        ])
        Task { try await mutation.mutate(id: testState.key, variables: testState.one) }
        try await Task.sleep(for: .seconds(0.05))
        _ = testState.store.set(key: testState.key, value: testState.one)
        #expect(testState.store.get(key: testState.key) == testState.one)
        try await Task.sleep(for: .seconds(0.1))
        // The remote mutation should have failed and the original value restored.
        _ = testState.store.set(key: testState.key, value: testState.zero)
        #expect(testState.store.get(key: testState.key) == testState.zero)
    }

    @Test("Mutation remote success then failure revert to previous success")
    func mutationRemoteSuccessThenFailureRevertToPreviousSuccess() async throws {
        let testState = TestState()
        #expect(testState.store.get(key: testState.key) == testState.zero)
        let mutation = testState.makeMutation()
        testState.remoteMutationResults = DelayedValues<String>(values: [
            .makeValue(testState.two), // Success response
            .makeError(TestError(category: .failure)), // Failure response
        ])
        Task { try await mutation.mutate(id: testState.key, variables: testState.one) }
        try await Task.sleep(for: .seconds(0.05))
        _ = testState.store.set(key: testState.key, value: testState.one)
        #expect(testState.store.get(key: testState.key) == testState.one)
        try await Task.sleep(for: .seconds(0.1))
        // The first remote mutation should have succeeded.
        _ = testState.store.set(key: testState.key, value: testState.two)
        #expect(testState.store.get(key: testState.key) == testState.two)
        Task { try await mutation.mutate(id: testState.key, variables: testState.three) }
        try await Task.sleep(for: .seconds(0.05))
        _ = testState.store.set(key: testState.key, value: testState.three)
        #expect(testState.store.get(key: testState.key) == testState.three)
        try await Task.sleep(for: .seconds(0.1))
        // The second remote mutation should have succeeded, reverting back to the last known successfull value.
        _ = testState.store.set(key: testState.key, value: testState.two)
        #expect(testState.store.get(key: testState.key) == testState.two)
    }
}

// MARK: - Test State Helper

@MainActor
private class TestState {
    // MARK: Constants

    let debounceInterval: TimeInterval = 0.1
    let key = "key"
    let zero = "zero"
    let one = "one"
    let two = "two"
    let three = "three"

    // MARK: Variables

    var store: DictionaryStore<String, String>!
    var remoteMutationResults: DelayedValues<String>!

    // MARK: Lifecycle

    init() {
        store = DictionaryStore<String, String>()
        _ = store.set(key: key, value: zero)
    }

    // MARK: Helpers

    func makeMutation() -> OptimisticMutation<String, String, String> {
        OptimisticMutation(
            debounceInterval: debounceInterval,
            store: store
        ) { (variables: String, _: String) in
            // Use the incoming variables as the mutation result to simplify the test writing.
            variables
        } remoteMutation: { (_: String, _: String) in
            try await self.remoteMutationResults.next()
        }
    }
}
