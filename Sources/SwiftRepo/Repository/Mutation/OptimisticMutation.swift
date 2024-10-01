//
//  Created by Timothy Moose on 6/27/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import Core

/// A mutation implementation that optimistically updates the store using the supplied `localMutation` closure and performs the serive mutation
/// using the supplied `remoteMutation` closure. If multiple rapid mutation calls are made, the store will be updated optimistically for each call, but
/// the calls will be debounced, based on the given `debounceInterval`, before the remote mutation is performed.
///
/// If the remote mutation fails and there are no pending remote mutations, then the last known valid value is restored, potentially reverting optimistic local mutations.
/// A valid value is defined as either the original value from the last idle period or the most recent success result from a remote mutation.
public final actor OptimisticMutation<MutationId, Variables, Value>: Mutation
    where MutationId: Hashable, Variables: Hashable {
    // MARK: - API

    public func mutate(id: MutationId, variables: Variables) async throws {
        guard let value = try await store.get(key: id) else {
            assertionFailure()
            return
        }
        let newValue = localMutation(variables, value)
        try await store.set(key: id, value: newValue)
        let requestId = UUID()
        var collateral = mutationCollaterals[id] ?? {
            let collateral = MutationCollateral(
                requestId: requestId,
                fallbackValue: value,
                debounce: Debounce(rate: debounceInterval)
            )
            return collateral
        }()
        collateral.requestId = requestId
        mutationCollaterals[id] = collateral
        if await collateral.debounce.send((variables, newValue)) {
            try await performRemoteMutation(id: id, requestId: requestId, variables: variables, newValue: newValue)
        }
    }

    public nonisolated func publisher(for id: MutationId) -> AnyPublisher<ResultType, Never> {
        subject
            .filter { $0.mutationId == id }
            .eraseToAnyPublisher()
    }

    /// Create a `OptimisticMutation` for a remote mutation that does not return a new value from the server.
    /// - Parameters:
    ///   - debounceInterval: Defines the debounce interval for mutation calls.
    ///   - store: The store to provide and receive values.
    ///   - localMutation: A closure that performs an optimistic local mutation of the current value in the store and the given mutation variables.
    ///   - remoteMutation: A closure that performs the remote mutation using the given mutation variables.
    public init(
        debounceInterval: TimeInterval,
        store: any Store<MutationId, Value>,
        localMutation: @escaping (_ variables: Variables, _ value: Value) -> Value,
        remoteMutation: @escaping (_ variables: Variables, _ value: Value) async throws -> Void
    ) {
        self.init(
            debounceInterval: debounceInterval,
            store: store,
            localMutation: localMutation
        ) { id, value -> Value in
            try await remoteMutation(id, value)
            return value
        }
    }

    /// Create a `OptimisticMutation` for a remote mutation that does return a new value from the server.
    ///   - debounceInterval: Defines the debounce interval for mutation calls.
    ///   - store: The store to provide and receive values.
    ///   - localMutation: A closure that performs an optimistic local mutation of the current value in the store and the given mutation variables.
    ///   - remoteMutation: A closure that performs the remote mutation using the given mutation variables.
    public init(
        debounceInterval: TimeInterval,
        store: any Store<MutationId, Value>,
        localMutation: @escaping (Variables, Value) -> Value,
        remoteMutation: @escaping (Variables, Value) async throws -> Value
    ) {
        self.debounceInterval = debounceInterval
        self.store = store
        self.localMutation = localMutation
        self.remoteMutation = remoteMutation
    }

    // MARK: - Constants

    private struct MutationCollateral {
        var requestId: UUID
        var fallbackValue: Value
        let debounce: Debounce<(Variables, Value)>
    }

    // MARK: - Variables

    private let debounceInterval: TimeInterval
    private let localMutation: (Variables, Value) -> Value
    private let remoteMutation: (Variables, Value) async throws -> Value
    private let store: any Store<MutationId, Value>
    private var fallbackValue: [MutationId: Value] = [:]
    private var mutationCollaterals: [MutationId: MutationCollateral] = [:]
    private let subject = PassthroughSubject<ResultType, Never>()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Remote mutation

    private func performRemoteMutation(id: MutationId, requestId: UUID, variables: Variables, newValue: Value) async throws {
        do {
            let value = try await remoteMutation(variables, newValue)
            guard var collateral = mutationCollaterals[id] else {
                return
            }
            if collateral.requestId == requestId {
                mutationCollaterals[id] = nil
                try await store.set(key: id, value: value)
            } else {
                collateral.fallbackValue = value
                mutationCollaterals[id] = collateral
            }
            subject.send(ResultType(mutationId: id, variables: variables, result: .success(value)))
        } catch {
            guard let collateral = mutationCollaterals[id] else {
                assertionFailure("Missing mutation collateral for id=\(id)")
                return
            }
            if collateral.requestId == requestId {
                mutationCollaterals[id] = nil
                try await store.set(key: id, value: collateral.fallbackValue)
            }
            subject.send(ResultType(mutationId: id, variables: variables, result: .failure(error)))
        }
    }
}
