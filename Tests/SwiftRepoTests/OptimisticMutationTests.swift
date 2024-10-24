//
//  Created by Timothy Moose on 6/29/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import XCTest
import SwiftRepoTest
@testable import SwiftRepo

@MainActor
class OptimisticMutationTests: XCTestCase {
    
    func test_mutation_remoteSuccess_storedValues() async throws {
        XCTAssertEqual(try store.get(key: key), zero)
        let mutation = makeMutation()
        remoteMutationResults = DelayedValues<String>(values: [
            .makeValue(three) // Success response
        ])
        Task { try await mutation.mutate(id: key, variables: one) }
        try await Task.sleep(for: .seconds(0.05))
        try store.set(key: key, value: one)
        XCTAssertEqual(try store.get(key: key), one)
        Task { try await mutation.mutate(id: key, variables: two) }
        try await Task.sleep(for: .seconds(0.05))
        try store.set(key: key, value: two)
        XCTAssertEqual(try store.get(key: key), two)
        // Since we're debouncing, the remote mutation shouldn't have happened yet.
        try store.set(key: key, value: three)
        XCTAssertEqual(try store.get(key: key), three)
        try await Task.sleep(for: .seconds(0.1))
        // Now, the remote mutation should have been called once.
        try store.set(key: key, value: three)
        XCTAssertEqual(try store.get(key: key), three)
    }

    func test_mutation_remoteFailure_revertToOriginal() async throws {
        XCTAssertEqual(try store.get(key: key), zero)
        let mutation = makeMutation()
        remoteMutationResults = DelayedValues<String>(values: [
            .makeError(TestError(category: .failure)), // Failure response
        ])
        Task { try await mutation.mutate(id: key, variables: one) }
        try await Task.sleep(for: .seconds(0.05))
        try store.set(key: key, value: one)
        XCTAssertEqual(try store.get(key: key), one)
        try await Task.sleep(for: .seconds(0.1))
        // The remote mutation should have failed and the original value restored.
        try store.set(key: key, value: zero)
        XCTAssertEqual(try store.get(key: key), zero)
    }

    @MainActor
    func test_mutation_remoteSuccessThenFailure_revertToPreviousSuccess() async throws {
        XCTAssertEqual(try store.get(key: key), zero)
        let mutation = makeMutation()
        remoteMutationResults = DelayedValues<String>(values: [
            .makeValue(two), // Success response
            .makeError(TestError(category: .failure)), // Failure response
        ])
        Task { try await mutation.mutate(id: key, variables: one) }
        try await Task.sleep(for: .seconds(0.05))
        try store.set(key: key, value: one)
        XCTAssertEqual(try store.get(key: key), one)
        try await Task.sleep(for: .seconds(0.1))
        // The first remote mutation should have succeeded.
        try store.set(key: key, value: two)
        XCTAssertEqual(try store.get(key: key), two)
        Task { try await mutation.mutate(id: key, variables: three) }
        try await Task.sleep(for: .seconds(0.05))
        try store.set(key: key, value: three)
        XCTAssertEqual(try store.get(key: key), three)
        try await Task.sleep(for: .seconds(0.1))
        // The second remote mutation should have succeeded, reverting back to the last known successfull value.
        try store.set(key: key, value: two)
        XCTAssertEqual(try store.get(key: key), two)
    }

    // MARK: Constants

    private let debounceInterval: TimeInterval = 0.1
    private let key = "key"
    private let zero = "zero"
    private let one = "one"
    private let two = "two"
    private let three = "three"

    // MARK: Variables

    private var store: (any Store<String, String>)!
    private var remoteMutationResults: DelayedValues<String>!

    // MARK: Lifecycle

    override func setUp() {
        super.setUp()
        store = DictionaryStore<String, String>()
        try! store.set(key: key, value: zero)
    }

    // MARK: Helpers

    private func makeMutation() -> OptimisticMutation<String, String, String> {
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
