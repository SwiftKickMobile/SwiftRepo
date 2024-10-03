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
    public typealias QueryType<QueryValue> = any Query<QueryId, Variables, QueryValue>

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
    public typealias ValueVariablesFactory<FactoryValue> = (_ queryId: QueryId, _ variables: Variables, _ value: FactoryValue) -> Variables

    /// Creates a query repository. There are simplified convenience initializers, so this one is typically not called directly.
    public init(
        observableStore: ObservableStoreType,
        query: QueryType<Value>,
        queryStrategy: QueryStrategy,
        valueVariablesFactory: ValueVariablesFactory<Value>?,
        keyFactory: @escaping KeyFactory
    ) {
        self.observableStore = observableStore
        self.queryStrategy = queryStrategy
        self.keyFactory = keyFactory
        preGet = { queryId, variables in
            guard let key = queryId as? Key else { return }
            if await query.latestVariables(for: queryId) != variables {
                try await observableStore.set(key: key, value: nil)
            }
        }
        get = { key, queryId, variables, errorIntent, queryStrategy, willGet in
            _ = try await query.get(
                id: queryId,
                variables: variables,
                into: observableStore,
                keyedBy: key,
                valueVariablesFactory: valueVariablesFactory,
                keyFactory: keyFactory,
                errorIntent: errorIntent,
                strategy: queryStrategy,
                willGet: willGet
            )
        }
    }
    
    /// Creates a query repository whose published values differ from those placed in the underlying store.
    /// There are simplified convenience initializers, so this one is typically not called directly.
    public init<Model, QueryValue>(
        observableStore: ObservableStoreType,
        modelStore: any Store<Model.Key, Model>,
        query: QueryType<QueryValue>,
        queryStrategy: QueryStrategy,
        valueVariablesFactory: ValueVariablesFactory<QueryValue>?,
        keyFactory: @escaping KeyFactory
    ) where Model: StoreModel, QueryValue: ModelResponse, Model == QueryValue.Model, Value == QueryValue.Value {
        self.observableStore = observableStore
        self.queryStrategy = queryStrategy
        self.keyFactory = keyFactory
        preGet = { queryId, variables in
            guard let key = queryId as? Key else { return }
            if await query.latestVariables(for: queryId) != variables {
                try await observableStore.set(key: key, value: nil)
            }
        }
        get = { key, queryId, variables, errorIntent, queryStrategy, willGet in
            _ = try await query.get(
                id: queryId,
                variables: variables,
                into: observableStore,
                modelStore: modelStore,
                keyedBy: key,
                valueVariablesFactory: valueVariablesFactory,
                keyFactory: keyFactory,
                errorIntent: errorIntent,
                strategy: queryStrategy,
                willGet: willGet
            )
        }
    }

    /// Creates a query repository when the store key is equivalent to the query ID. Use this when caching only the most recently used variables for a given query ID.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    ///   - queryStrategy: The query strategy to use.
    ///   - queryOperation: The operation to use to perform the actual query.
    public convenience init(
        observableStore: ObservableStoreType,
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
    
    /// Creates a query repository when the store key is equivalent to the query ID. Use this when caching only the most recently used variables for a given query ID.
    ///
    /// - Parameters:
    ///   - observableStore: The underlying `ObservableStore` implementation to use.
    ///   - modelStore: The underlying `Store` implementation to use for models.
    ///   - queryStrategy: The query strategy to use.
    ///   - queryOperation: The operation to use to perform the actual query.
    public convenience init<Model>(
        observableStore: ObservableStoreType,
        modelStore: any Store<Model.Key, Model>,
        queryStrategy: QueryStrategy,
        queryOperation: @escaping (Variables) async throws -> Value
    ) where Model: StoreModel, Value: ModelResponse, Model == Value.Model, Key == QueryId, Value == Value.Value {
        self.init(
            observableStore: observableStore,
            modelStore: modelStore,
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
    private let queryStrategy: QueryStrategy
    private let keyFactory: (_ queryId: QueryId, _ variables: Variables) -> Key

    let preGet: (
        _ queryId: QueryId,
        _ variables: Variables
    ) async throws -> Void

    private let get: (
        _ key: Key,
        _ queryId: QueryId,
        _ variables: Variables,
        _ errorIntent: ErrorIntent,
        _ queryStrategy: QueryStrategy,
        _ willGet: @escaping Query.WillGet
    ) async throws -> Void

    // MARK: - QueryRepository

    @MainActor
    public func get(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy? = nil,
        willGet: @escaping Query.WillGet
    ) async {
        let key = keyFactory(queryId, variables)
        do {
            try await get(key, queryId, variables, errorIntent, queryStrategy ?? self.queryStrategy, willGet)
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
        do {
            try await preGet(queryId, variables)
            await get(
                queryId: queryId,
                variables: variables,
                errorIntent: errorIntent
            ) {}
        } catch {
            // Any errors on prefetch can be propagated through the publisher.
            let key = keyFactory(queryId, variables)
            let result = StoreResult<Key, Value, Error>(key: key, failure: error)
            _ = observableStore.subscriber
                .receive(result)
        }
    }
}
