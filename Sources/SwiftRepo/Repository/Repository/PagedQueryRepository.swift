//
//  Created by Timothy Moose on 11/7/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import SwiftRepoCore

/// A query repository implementation that supports paged service calls. The primary difference between `PagedQueryRepository` and
/// `DefaultQueryRepository` is that `PagedQueryRepository` treats paged data sets as non-refreshable. That is, a paged data set
/// cannot be refreshed while in use because the user may have loaded multiple pages. Refreshing multiple pages while in use would revert
/// UI back to a single page, which isn't a viable user experience. `PagedQueryRepository` applies this non-refreshable strategy in two ways:
///
/// 1. Evict data from the store if it is older than the specified `ifOlderThan` parameter. This prevents stale data from being published while being refreshed.
///     1. When requesting the first page. This prevents stale data from being published when calling `get` with new variables.
///     2. When requesting a publisher. This prevents stale data from being published on view model initialization.
/// 2. Using the `.ifNotStored` query strategy to ensure that, as additional pages are loaded, they are appended to the existing store.
public final class PagedQueryRepository<QueryId: Hashable & Sendable, Variables: Hashable & Sendable, Key: Hashable & Sendable, Value: Sendable>: QueryRepository
    where Variables: HasCursorPaginationInput {
    // MARK: - API

    public typealias QueryType = any Query<QueryId, Variables, Value>

    public typealias ObservableStoreType = any ObservableStore<Key, QueryId, Value>

    public typealias KeyFactory = (_ queryId: QueryId, _ variables: Variables) -> Key

    public typealias ValueVariablesFactory = (_ queryId: QueryId, _ variables: Variables, _ value: Value) -> Variables

    @AsyncLocked
    public func get(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy _: QueryStrategy? = nil,
        willGet: @escaping @MainActor () async -> Void
    ) async {
        // Evict stale data when getting the first page.
        if !variables.isPaging {
            do {
                let key = keyFactory(queryId, variables)
                try await observableStore.evict(for: key, ifOlderThan: ifOlderThan)
            } catch {
                // Any errors on prefetch can be propagated through the publisher.
                let key = keyFactory(queryId, variables)
                let result = StoreResult<Key, Value, Error>(key: key, failure: error)
                _ = observableStore.subscriber
                    .receive(result)
                // Return early on error
                return
            }
        }
        // Ignore the `queryStrategy` parameter for now, forcing `.ifNotStored`. No other strategy makes sense with paging.
        await repository.get(
            queryId: queryId,
            variables: variables,
            errorIntent: errorIntent,
            queryStrategy: .ifNotStored,
            willGet: willGet
        )
    }

    @AsyncLocked
    public func publisher(for queryId: QueryId, setCurrent key: Key) async -> AnyPublisher<ValueResult, Never> {
        // Evict stale data before returning the publisher to ensure that stale data isn't displayed
        // before `get` is called.
        try? await observableStore.evict(for: key, ifOlderThan: ifOlderThan)
        return await repository.publisher(for: queryId, setCurrent: key)
    }

    @AsyncLocked
    public func prefetch(queryId: QueryId, variables: Variables, errorIntent: ErrorIntent = .dispensable) async {
        await repository.prefetch(queryId: queryId, variables: variables, errorIntent: errorIntent)
    }

    /// Creates a paged query repository for variables that adopt `HasCursorPaginationInput` and store key `QueryStoreKey<QueryId, Variables>`.
    /// - Parameters:
    ///   - observableStore: the observable store that is keyed by `QueryStoreKey<QueryId, Variables>`
    ///   - ifOlderThan: the maximum age of stored paged before being considered stale.
    ///   - queryOperation: the query operation
    public convenience init(
        observableStore: any ObservableStore<Key, QueryId, Value>,
        ifOlderThan: TimeInterval,
        queryOperation: @escaping @Sendable (Variables) async throws -> Value
    )
        where Key == QueryStoreKey<QueryId, Variables>,
        Value: HasValueVariables,
        Variables == Value.Variables,
        Variables: HasCursorPaginationInput,
        QueryId == Value.QueryId {
        self.init(
            observableStore: observableStore,
            query: DefaultQuery(queryOperation: queryOperation),
            ifOlderThan: ifOlderThan
        ) { queryId, variables, value in
            value.valueVariables(queryId: queryId, variables: variables)
        } keyFactory: { queryId, variables in
            QueryStoreKey(queryId: queryId, variables: variables)
        }
    }

    /// Creates a paged query repository.  There are simplified convenience initializers, so this one is typically not called directly.
    public init(
        observableStore: ObservableStoreType,
        query: QueryType,
        ifOlderThan: TimeInterval,
        valueVariablesFactory: ValueVariablesFactory?,
        keyFactory: @escaping KeyFactory
    ) {
        self.ifOlderThan = ifOlderThan
        self.observableStore = observableStore
        self.keyFactory = keyFactory
        repository = DefaultQueryRepository(
            observableStore: observableStore,
            query: query,
            queryStrategy: .ifNotStored,
            valueVariablesFactory: valueVariablesFactory,
            keyFactory: keyFactory
        )
    }

    // MARK: - Constants

    // MARK: - Variables

    private let ifOlderThan: TimeInterval
    private let observableStore: ObservableStoreType
    private let keyFactory: KeyFactory
    private let repository: DefaultQueryRepository<QueryId, Variables, Key, Value>
}
