//
//  Created by Timothy Moose on 7/5/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import SwiftRepoCore

/// The default `ConstantQueryRepository` implementation.
public final class DefaultConstantQueryRepository<Variables: Hashable & Sendable, Value: Sendable>: ConstantQueryRepository {
    // MARK: - API

    public typealias QueryType = any Query<Variables, Variables, Value>

    public typealias ObservableStoreType = any ObservableStore<Variables, Variables, Value>

    /// Creates a constant query repository. There are simplified convenience initializers, so this one is typically not called directly.
    public init(
        variables: Variables,
        observableStore: ObservableStoreType,
        query: QueryType,
        queryStrategy: QueryStrategy
    ) {
        self.variables = variables
        repository = DefaultQueryRepository(
            observableStore: observableStore,
            query: query,
            queryStrategy: queryStrategy,
            valueVariablesFactory: nil
        ) { queryId, _ in queryId }
    }

    /// Creates a constant query repository.
    ///
    /// - Parameters:
    ///   - variables: The constant variables to use when performing the query operation.
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    ///   - queryStrategy: The query strategy to use.
    ///   - queryOperation: The operation to use to perform the actual query.
    public convenience init(
        variables: Variables,
        observableStore: ObservableStoreType,
        queryStrategy: QueryStrategy,
        queryOperation: @escaping @Sendable (Variables) async throws -> Value
    ) {
        self.init(
            variables: variables,
            observableStore: observableStore,
            query: DefaultQuery(queryOperation: queryOperation),
            queryStrategy: queryStrategy
        )
    }

    // MARK: - Constants

    // MARK: - Variables

    private let variables: Variables
    private let repository: DefaultQueryRepository<Variables, Variables, Variables, Value>

    // MARK: - ConstantQueryRepository

    @AsyncLocked
    public func get(
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy?,
        willGet: @escaping @MainActor () async -> Void
    ) async {
        await repository.get(
            queryId: variables,
            variables: variables,
            errorIntent: errorIntent,
            queryStrategy: queryStrategy,
            willGet: willGet
        )
    }

    @AsyncLocked
    public func getValue(
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy?,
        willGet: @escaping @MainActor () async -> Void
    ) async throws -> Value {
        return try await repository.getValue(
            queryId: variables,
            variables: variables,
            errorIntent: errorIntent,
            queryStrategy: queryStrategy,
            willGet: willGet
        )
    }

    @AsyncLocked
    public func publisher() async -> AnyPublisher<ValueResult, Never> {
        await repository.publisher(for: variables, setCurrent: variables)
    }

    @AsyncLocked
    public func prefetch(errorIntent: ErrorIntent = .dispensable) async {
        await repository.prefetch(queryId: variables, variables: variables, errorIntent: errorIntent)
    }
}
