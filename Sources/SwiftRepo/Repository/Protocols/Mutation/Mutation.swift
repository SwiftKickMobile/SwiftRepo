//
//  Created by Timothy Moose on 6/28/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

@preconcurrency import Combine
import Foundation

/// This base protocol exists purely for Mockingbird. For some reason, if these definitions live in `Mutation`, then Mockingbird mocks
/// are somehow causing a segmentation fault during compilation. It seems to be explicitly due to the `typealias ResultType`.
/// For some reason, pushing `typealias ResultType` into a parent protocol fixes the segumentation fault. It also, unfortunately,
/// forces the order of the mocked generic types to be `<Variables, MutationId, Value>` rather than `<MutationId, Variables, Value>`.
public protocol MutationBase {
    /// Mutation ID identifies a unique mutation for the purposes of optimistic updating, debouncing and providing ID-scoped publishers.
    associatedtype MutationId: Hashable & Sendable

    /// The mutation parameters.
    associatedtype Variables: Hashable & Sendable

    /// The type of value being mutated.
    associatedtype Value: Sendable

    /// The result type used by publishers.
    typealias ResultType = MutationResult<MutationId, Variables, Value, Error>
}

/// Provides an interface for objects to layer functionality onto basic service mutations, such
/// as optimistic mutations and debounding.
///
/// In a typical usage, a repository would perform a remote mutation through an
/// instance of `Mutation`, which would in turn be responsible for making the service call.
@MainActor
public protocol Mutation<MutationId, Variables, Value>: MutationBase {
    /// Called to perform the mutation
    func mutate(id: MutationId, variables: Variables) async throws

    /// Publishes results matching the specified mutation ID.
    /// - Parameter id: the mutation ID to match against.
    /// - Returns: a publisher of mutation results.
    func publisher(for id: MutationId) -> AnyPublisher<ResultType, Never>
}
