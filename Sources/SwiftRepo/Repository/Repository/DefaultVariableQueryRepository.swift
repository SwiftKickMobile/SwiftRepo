//
//  Created by Timothy Moose on 7/1/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import SwiftRepoCore

/// The default `VariableQueryRepository` implementation.
public final class DefaultVariableQueryRepository<Variables: Hashable & Sendable, Value: Sendable>: VariableQueryRepository {
    // MARK: - API

    public typealias QueryType = any Query<Variables, Variables, Value>

    public typealias ObservableStoreType = any ObservableStore<Variables, Variables, Value>

    /// Creates a variable query repository. There are simplified convenience initializers, so this one is typically not called directly.
    public init(
        observableStore: ObservableStoreType,
        query: QueryType,
        queryStrategy: QueryStrategy
    ) {
        repository = DefaultQueryRepository(
            observableStore: observableStore,
            query: query,
            queryStrategy: queryStrategy,
            valueVariablesFactory: nil
        ) { queryId, _ in queryId }
    }

    /// Creates a variable query repository.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    ///   - queryStrategy: The query strategy to use.
    ///   - queryOperation: The operation to use to perform the actual query.
    public convenience init(
        observableStore: any ObservableStore<Variables, Variables, Value>,
        queryStrategy: QueryStrategy,
        queryOperation: @escaping @Sendable (Variables) async throws -> Value
    ) {
        self.init(
            observableStore: observableStore,
            query: DefaultQuery(queryOperation: queryOperation),
            queryStrategy: queryStrategy
        )
    }

    /// Creates a variable query repository with no associated query.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    public convenience init(observableStore: any ObservableStore<Variables, Variables, Value>) {
        self.init(
            observableStore: observableStore,
            query: DefaultQuery { _ in fatalError("query shouldn't be reached") },
            queryStrategy: .never
        )
    }

    // MARK: - Constants

    // MARK: - Variables

    private let repository: DefaultQueryRepository<Variables, Variables, Variables, Value>

    // MARK: - VariableQueryRepository

    @AsyncLocked
    public func get(
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy? = nil,
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
    public func publisher(for variables: Variables) async -> AnyPublisher<ValueResult, Never> {
        await repository.publisher(for: variables, setCurrent: variables)
    }

    @AsyncLocked
    public func prefetch(variables: Variables, errorIntent: ErrorIntent = .dispensable) async {
        await repository.prefetch(queryId: variables, variables: variables, errorIntent: errorIntent)
    }
}
