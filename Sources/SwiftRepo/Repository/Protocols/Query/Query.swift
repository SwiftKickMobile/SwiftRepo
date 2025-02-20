//
//  Created by Timothy Moose on 5/23/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import SwiftRepoCore

public enum QueryError: String, Error {
    case cancelled
}

/// Provides an interface for objects to layer functionality onto basic service queries, such
/// as query de-duplication and publishing values over time.
///
/// In a typical usage, a repository would query remote data through an
/// instance of `Query`, which would in turn be responsible for making the service call.
public protocol Query<QueryId, Variables, Value>: Sendable {
    /// Query ID identifies a unique request for the purposes of request de-duplication, cancellation and providing ID-scoped publishers.
    associatedtype QueryId: SyncHashable

    /// The variables that provide the request parameters. When two overlapping queries are made with the same query ID and variables,
    /// only one request is made. When two overlapping queries are made with the same query ID and different variables, any ongoing
    /// request is cancelled and a new request is made with the latest variables.
    associatedtype Variables: SyncHashable

    /// The response type returned by the query.
    associatedtype Value: Sendable

    /// The result type used by publishers.
    typealias ResultType = QueryResult<QueryId, Variables, Value, Error>

    /// Called to perform the query.
    @discardableResult
    func get(id: QueryId, variables: Variables) async throws -> Value

    /// Cancells any ongoing query.
    func cancel(id: QueryId) async

    /// Publishes responses for all queries. Cancellation errors are not published. Callers can catch thrown errors from `get()` to check for cancellations.
    var publisher: AnyPublisher<ResultType, Never> { get }

    /// Publishes responses matching the specified query ID. Cancellation errors are not published. Callers can catch thrown errors from `get()` to check for cancellations.
    /// - Parameter id: the query ID to match against.
    /// - Returns: a publisher of responses.
    func publisher(for id: QueryId) -> AnyPublisher<ResultType, Never>

    /// Returns the variables for the most recent successful query for the given query ID.
    /// - Parameter id: the query ID.
    /// - Returns: the variables for the most recent successful query for the given query ID. Returns `nil` if there has been no successul query.
    func latestVariables(for id: QueryId) async -> Variables?
}

public extension Query {
    typealias WillGet = @Sendable () async -> Void

    @discardableResult
    /// Conditionally perform the query if needed based on the specified strategy and the state of the store.
    /// - Parameters:
    ///   - id: The query ID
    ///   - variables: The query variables
    ///   - store: The observable store where query results are cached
    ///   - keyedBy: The store key associated with this query. This is typically either the query ID or `QueryStoreKey`, depending on the granularity of storage being used.
    ///   - valueVariablesFactory: a closure that converts the value into its associated variables
    ///   - keyFactory: a closure that converts the query ID and variables into a store key
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    ///   - strategy: The query strategy
    ///   - willGet: A closure that will be called if and when the query is performed. This is typically the `LoadingController.loading` function.
    /// - Returns: The value if the query was performed. Otherwise, `nil`.
    func get<Store, Key>(
        id: QueryId,
        variables: Variables,
        into store: Store,
        keyedBy unmappedKey: Key,
        valueVariablesFactory: ((QueryId, Variables, Value) -> Variables)?,
        keyFactory: @escaping (QueryId, Variables) -> Key,
        errorIntent: ErrorIntent,
        strategy: QueryStrategy,
        willGet: WillGet?
    ) async throws -> Value?
    where Store: ObservableStore, Store.Value == Value, Store.Key == Key, Store.PublishKey == QueryId {
        try await commonGet(
            id: id,
            variables: variables,
            into: store,
            keyedBy: unmappedKey,
            valueVariablesFactory: valueVariablesFactory,
            keyFactory: keyFactory,
            errorIntent: errorIntent,
            strategy: strategy,
            willGet: willGet,
            storeSet: { storeKey, value in
                // Here we explicitly pass the value as `Value`, since `Store.Value == Value`
                try await store.set(key: storeKey, value: value)
            },
            modelStoreSet: nil
        )
    }

    /// Publishes all values
    var valuePublisher: AnyPublisher<Value, Never> {
        publisher
            .compactMap {
                switch $0.result {
                case let .success(value): return value
                case .failure: return nil
                }
            }
            .eraseToAnyPublisher()
    }
}

public extension Query {
    
    @discardableResult
    /// Conditionally perform the query if needed based on the specified strategy and the state of the store.
    /// This `get` function is to be used when `Value` is a `ModelResponse`. The `ModelResponse.Value`
    /// will be placed in `store`, while the `ModelResponse.Model`s will be placed in the `modelStore`.
    /// - Parameters:
    ///   - id: The query ID
    ///   - variables: The query variables
    ///   - store: The observable store where query result values are cached
    ///   - modelStore: The model store where query result models are cached
    ///   - mergeStrategy: Specifies how models are stored in the `modelStore`
    ///   - unmappedKey: The store key associated with this query. This is typically either the query ID or `QueryStoreKey`, depending on the granularity of storage being used.
    ///   - valueVariablesFactory: a closure that converts the value into its associated variables
    ///   - keyFactory: a closure that converts the query ID and variables into a store key
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    ///   - strategy: The query strategy
    ///   - willGet: A closure that will be called if and when the query is performed. This is typically the `LoadingController.loading` function.
    /// - Returns: The value if the query was performed. Otherwise, `nil`.
    @available(iOS 17, *)
    func get<Store, Key, ModelStore>(
        id: QueryId,
        variables: Variables,
        into store: Store,
        modelStore: ModelStore,
        mergeStrategy: ModelStoreMergeStrategy,
        keyedBy unmappedKey: Key,
        valueVariablesFactory: ((QueryId, Variables, Value) -> Variables)?,
        keyFactory: @escaping (QueryId, Variables) -> Key,
        errorIntent: ErrorIntent,
        strategy: QueryStrategy,
        willGet: WillGet?
    ) async throws -> Value?
    where Value: ModelResponse,
          Store: ObservableStore,
          Store.Value == Value.Value,
          Store.Key == Key,
          Store.PublishKey == QueryId,
          ModelStore: SwiftRepo.Store,
          ModelStore.Value == Value.Model,
          ModelStore.Key == Value.Model.Key
    {
        try await commonGet(
            id: id,
            variables: variables,
            into: store,
            keyedBy: unmappedKey,
            valueVariablesFactory: valueVariablesFactory,
            keyFactory: keyFactory,
            errorIntent: errorIntent,
            strategy: strategy,
            willGet: willGet,
            storeSet: { storeKey, value in
                // For this version, we pass `value.value`, since `Store.Value == Value.Value`
                try await store.set(key: storeKey, value: value.value)
            },
            modelStoreSet: { @MainActor value in
                for model in value.models {
                    try modelStore.set(key: model.id, value: model)
                }
                
                switch mergeStrategy {
                case .append:
                    // No additional action required
                    break
                case .trim:
                    // Capture keys for models not in the new `Value.models` array,
                    // and remove the associated model from the store.
                    let keepModelKeys = Set(value.models.map { $0.id })
                    let allModelKeys = Set(try modelStore.keys)
                    let trimModelKeys = allModelKeys.subtracting(keepModelKeys)
                    for modelKey in trimModelKeys {
                        try modelStore.set(key: modelKey, value: nil)
                    }
                }
                
                // After setting all the models in the store, call save
                // on the store if it conforms to `Saveable`.
                if let modelStore = modelStore as? Saveable {
                    try await modelStore.save()
                }
            }
        )
    }
}

private extension Query {
    func shouldGet(
        strategy: QueryStrategy,
        ageOfStore: TimeInterval?,
        variablesChanged: Bool,
        isPaging: Bool
    ) async -> Bool {
        guard !isPaging else { return true }
        switch strategy {
        case let .ifOlderThan(timeInterval):
            return (ageOfStore ?? TimeInterval.greatestFiniteMagnitude >= timeInterval) ||
                variablesChanged
        case .ifNotStored:
            return ageOfStore == nil || variablesChanged
        case .always:
            return true
        case .never:
            return false
        }
    }
    
    /// Common logic to conditionally perform the query if needed based on the specified strategy and state of the store.
    private func commonGet<Store, Key>(
        id: QueryId,
        variables: Variables,
        into store: Store,
        keyedBy unmappedKey: Key,
        valueVariablesFactory: ((QueryId, Variables, Value) -> Variables)?,
        keyFactory: @escaping (QueryId, Variables) -> Key,
        errorIntent: ErrorIntent,
        strategy: QueryStrategy,
        willGet: WillGet?,
        storeSet: @escaping (Key, Value) async throws -> Void,
        modelStoreSet: (@MainActor (Value) async throws -> Void)?
    ) async throws -> Value?
    where Store: ObservableStore, Store.Key == Key, Store.PublishKey == QueryId {
        let key = await store.map(key: unmappedKey)
        // Set the current key to this query's key. If the key exists in the store and is not already the current
        // key, the new current value will be published.
        await store.set(currentKey: key)
        let variablesChanged: Bool
        // We have two techniques for determining if the query variables have changed. When using `QueryStoreKey`, the variables
        // are part of the key, so we just check if the key is changing. For all other keys, we rely on comparing the incoming variables
        // to the latest variables used in the query.
        if let queryStoreKey = key as? QueryStoreKey<QueryId, Variables> {
            let currentKey = await store.currentKey(for: id) as? QueryStoreKey<QueryId, Variables>
            variablesChanged = queryStoreKey != currentKey
        } else {
            let latestVariables = await latestVariables(for: id)
            variablesChanged = variables != latestVariables
        }
        let isPaging: Bool = {
            switch variables as? HasCursorPaginationInput {
            case let variables?: return variables.isPaging
            case .none: return false
            }
        }()
        // Don't do anything if the data is fresh enough and the variables haven't changed.
        guard await shouldGet(
            strategy: strategy,
            ageOfStore: try await store.age(of: key),
            variablesChanged: variablesChanged,
            isPaging: isPaging
        ) else {
            // This closes a loophole:
            // 1. There is an ongoing query with variables A
            // 2. This function is called again with variables B
            // 3. The store publishes a cached value for variables B
            // 4. The ongoing query with variables A needs to be cancelled explicitly
            //    since we're here and not peroforming a query with variables B
            await cancel(id: id)
            return nil
        }
        await willGet?()
        do {
            let value = try await get(id: id, variables: variables)
            if let valueVariables = valueVariablesFactory?(id, variables, value) {
                let valueKey = keyFactory(id, valueVariables)
                await store.addMapping(from: valueKey, to: key)
            }
            // If a closure was provided to populate the value models, do so.
            if let modelStoreSet {
                try await modelStoreSet(value)
            }
            // Then, set the new value to the observable store.
            try await storeSet(key, value)
            return value
        } catch var error as AppError {
            // On error, apply the error intent
            error.intent = errorIntent
            throw error
        }
    }
}
