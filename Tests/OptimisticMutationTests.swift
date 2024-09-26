////
////  Created by Timothy Moose on 6/29/22.
////  Copyright © 2022 ZenBusiness PBC. All rights reserved.
////
//
//import XCTest
//import Mockingbird
//@testable import SwiftRepo
//
//// swiftlint: disable implicitly_unwrapped_optional
//class OptimisticMutationTests: XCTestCase {
//    @MainActor
//    func test_mutation_remoteSuccess_storedValues() async throws {
//        given(store.get(key: key)).willReturn(zero)
//        let mutation = makeMutation()
//        remoteMutationResults.values = [
//            // Success response
//            .makeValue(three),
//        ]
//        Task { await mutation.mutate(id: key, variables: one) }
//        try await Task.sleep(for: .seconds(0.05))
//        verify(store.set(key: key, value: one)).wasCalled(1)
//        Task { await mutation.mutate(id: key, variables: two) }
//        try await Task.sleep(for: .seconds(0.05))
//        verify(store.set(key: key, value: two)).wasCalled(1)
//        // Since we're debouncing, the remote mutation shouldn't have happened yet.
//        verify(store.set(key: key, value: three)).wasNeverCalled()
//        try await Task.sleep(for: .seconds(0.1))
//        // Now, the remote mutation should have been called once.
//        verify(store.set(key: key, value: three)).wasCalled(1)
//    }
//
//    @MainActor
//    func test_mutation_remoteFailure_revertToOriginal() async throws {
//        given(store.get(key: key)).willReturn(zero)
//        let mutation = makeMutation()
//        remoteMutationResults.values = [
//            // Failure response
//            .makeError(TestError(category: .failure)),
//        ]
//        Task { await mutation.mutate(id: key, variables: one) }
//        try await Task.sleep(for: .seconds(0.05))
//        verify(store.set(key: key, value: one)).wasCalled(1)
//        try await Task.sleep(for: .seconds(0.1))
//        // The remote mutation should have failed and the original value restored.
//        verify(store.set(key: key, value: zero)).wasCalled(1)
//    }
//
//    @MainActor
//    func test_mutation_remoteSuccessThenFailure_revertToPreviousSuccess() async throws {
//        given(store.get(key: key)).willReturn(zero)
//        let mutation = makeMutation()
//        remoteMutationResults.values = [
//            // Success response
//            .makeValue(two),
//            // Failure response
//            .makeError(TestError(category: .failure)),
//        ]
//        Task { await mutation.mutate(id: key, variables: one) }
//        try await Task.sleep(for: .seconds(0.05))
//        verify(store.set(key: key, value: one)).wasCalled(1)
//        try await Task.sleep(for: .seconds(0.1))
//        // The first remote mutation should have succeeded.
//        verify(store.set(key: key, value: two)).wasCalled(1)
//        Task { await mutation.mutate(id: key, variables: three) }
//        try await Task.sleep(for: .seconds(0.05))
//        verify(store.set(key: key, value: three)).wasCalled(1)
//        try await Task.sleep(for: .seconds(0.1))
//        // The second remote mutation should have succeeded, reverting back to the last known successfull value.
//        verify(store.set(key: key, value: two)).wasCalled(1)
//    }
//
//    // MARK: Constants
//
//    private let debounceInterval: TimeInterval = 0.1
//    private let key = "key"
//    private let zero = "zero"
//    private let one = "one"
//    private let two = "two"
//    private let three = "three"
//
//    // MARK: Variables
//
//    private var store: StoreMock<String, String>!
//    private let remoteMutationResults = DelayedValues<String>(values: [])
//
//    // MARK: Lifecycle
//
//    override func setUp() {
//        super.setUp()
//        store = mock(Store<String, String>.self)
//        remoteMutationResults.values = []
//    }
//
//    // MARK: Helpers
//
//    private func makeMutation() -> OptimisticMutation<String, String, String> {
//        OptimisticMutation(
//            debounceInterval: debounceInterval,
//            store: store
//        ) { (variables: String, _: String) in
//            // Use the incoming variables as the mutation result to simplify the test writing.
//            variables
//        } remoteMutation: { (_: String, _: String) in
//            try await self.remoteMutationResults.next()
//        }
//    }
//}
