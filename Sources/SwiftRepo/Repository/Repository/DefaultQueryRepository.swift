//
//  Created by Timothy Moose on 7/1/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import Core

/// The default `QueryRepository` implementation.
public final class DefaultQueryRepository<QueryId, Variables, Key, Value>: QueryRepository
where QueryId: Hashable, Variables: Hashable, Key: Hashable {
    
    // MARK: - API

    /// The type-erased query type.
    public typealias QueryType = any Query<QueryId, Variables, Value>

    /// The type-erased observable store type.
    public typealias ObservableStoreType = any ObservableStore<Key, QueryId, Value>

    /// A closure that maps query ID and variables to store key. This provides a range of storage granularity. For example,
    /// when the key is query ID, only one value is stored per query ID. On ther other hand, when the key is `QueryStoreKey`,
    /// one value is stored per unique query ID and variables. For both of these use cases, convenience initializers are provided
    /// that automatically supply the key factory.
    public typealias KeyFactory = (_ queryId: QueryId, _ variables: Variables) -> Key

    /// A closure for extracting variables from values. This closure helps with establishing unique store keys. This is primaryliy used with
    /// sorting and filtering service calls where the client allows the service to select default variables and send them back in the response. These use
    /// cases create a condition where two variables means the same thing. This closure give the repo the ability to detect these situations as they
    /// happen and add key mappings to the observable store via `observableStore.addMapping(from:to:)`
    public typealias ValueVariablesFactory = (_ queryId: QueryId, _ variables: Variables, _ value: Value) -> Variables

    /// Creates a query repository. There are simplified convenience initializers, so this one is typically not called directly.
    public init(
        observableStore: ObservableStoreType,
        query: QueryType,
        queryStrategy: QueryStrategy,
        valueVariablesFactory: ValueVariablesFactory?,
        keyFactory: @escaping KeyFactory
    ) {
        self.observableStore = observableStore
        self.query = query
        self.queryStrategy = queryStrategy
        self.valueVariablesFactory = valueVariablesFactory
        self.keyFactory = keyFactory
    }

    /// Creates a query repository when the store key is equivalent to the query ID. Use this when caching only the most recently used variables for a given query ID.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    ///   - queryStrategy: The query strategy to use.
    ///   - queryOperation: The operation to use to perform the actual query.
    public convenience init(
        observableStore: any ObservableStore<Key, Key, Value>,
        queryStrategy: QueryStrategy,
        queryOperation: @escaping (Variables) async throws -> Value
    ) where Key == QueryId {
        self.init(
            observableStore: observableStore,
            query: DefaultQuery(queryOperation: queryOperation),
            queryStrategy: queryStrategy,
            valueVariablesFactory: nil
        ) { queryId, _ in queryId }
    }

    /// Creates a query repository when the store key is `QueryStoreKey`. Use this for variable-based caching.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    ///   - queryStrategy: The query strategy to use.
    ///   - queryOperation: The operation to use to perform the actual query.
    public convenience init(
        observableStore: any ObservableStore<Key, QueryId, Value>,
        queryStrategy: QueryStrategy,
        queryOperation: @escaping (Variables) async throws -> Value
    ) where Key == QueryStoreKey<QueryId, Variables> {
        self.init(
            observableStore: observableStore,
            query: DefaultQuery(queryOperation: queryOperation),
            queryStrategy: queryStrategy,
            valueVariablesFactory: nil
        ) { queryId, variables in QueryStoreKey(queryId: queryId, variables: variables) }
    }

    /// Creates a query repository when the store key is `QueryStoreKey` and the value conforms to `HasValueVariables`. Use this for variable-based caching
    /// and values that contain information use to construct query variables, such as when the server decides default sort and filter options that get passed back to the client.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    ///   - queryStrategy: The query strategy to use.
    ///   - queryOperation: The operation to use to perform the actual query.
    public convenience init(
        observableStore: any ObservableStore<Key, QueryId, Value>,
        queryStrategy: QueryStrategy,
        queryOperation: @escaping (Variables) async throws -> Value
    )
        where Key == QueryStoreKey<QueryId, Variables>,
        Value: HasValueVariables,
        Variables == Value.Variables,
        QueryId == Value.QueryId {
        self.init(
            observableStore: observableStore,
            query: DefaultQuery(queryOperation: queryOperation),
            queryStrategy: queryStrategy
        ) { queryId, variables, value in
            value.valueVariables(queryId: queryId, variables: variables)
        } keyFactory: { queryId, variables in
            QueryStoreKey(queryId: queryId, variables: variables)
        }
    }

    /// Creates a query repository with no associated query.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    public convenience init(observableStore: any ObservableStore<Key, QueryId, Value>) where Key == QueryId {
        self.init(
            observableStore: observableStore,
            query: DefaultQuery { _ in fatalError("query shouldn't be reached") },
            queryStrategy: .never,
            valueVariablesFactory: nil
        ) { queryId, _ in queryId }
    }

    // MARK: - Constants

    // MARK: - Variables

    private let observableStore: ObservableStoreType
    private let query: QueryType
    private let queryStrategy: QueryStrategy
    private let valueVariablesFactory: ValueVariablesFactory?
    private let keyFactory: (_ queryId: QueryId, _ variables: Variables) -> Key

    // MARK: - QueryRepository

    public func get(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy? = nil,
        willGet: @escaping Query.WillGet
    ) async {
        let key = keyFactory(queryId, variables)
        do {
            _ = try await query.get(
                id: queryId,
                variables: variables,
                into: observableStore,
                keyedBy: key,
                valueVariablesFactory: valueVariablesFactory,
                keyFactory: keyFactory,
                errorIntent: errorIntent,
                strategy: queryStrategy ?? self.queryStrategy,
                willGet: willGet
            )
        } catch let error as QueryError where error == .cancelled {
            // Don't publish cancellation errors – we have no use case for needing to know about this
            // and including them would force view models to remember to ignore cancellation errors.
        } catch {
            let result = StoreResult<Key, Value, Error>(key: key, failure: error)
            _ = observableStore.subscriber
                .receive(result)
        }
    }

    public func publisher(for queryId: QueryId, setCurrent key: Key) -> AnyPublisher<ValueResult, Never> {
        observableStore.set(currentKey: key)
        return observableStore.publisher(for: queryId)
    }

    public func prefetch(queryId: QueryId, variables: Variables, errorIntent: ErrorIntent = .dispensable) async {
        await get(
            queryId: queryId,
            variables: variables,
            errorIntent: errorIntent
        ) {}
    }

    /// Prefetch logic is slightly different when the store key and the query ID are equivalent. This means we only store one
    /// value for a given query ID and should delete the stored value if the variables don't match the last known variables.
    public func prefetch(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent = .dispensable
    ) async where Key == QueryId {
        if await query.latestVariables(for: queryId) != variables {
            await observableStore.set(key: queryId, value: nil)
        }
        await get(
            queryId: queryId,
            variables: variables,
            errorIntent: errorIntent
        ) {}
    }
}
