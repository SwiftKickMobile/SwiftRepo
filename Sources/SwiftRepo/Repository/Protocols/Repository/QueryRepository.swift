//
//  Created by Timothy Moose on 7/1/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import SwiftRepoCore

/// A single-use query repository.
///
/// Intended to abstract away the lower-level `Query` and `ObservableStore` protocols into
/// a single, simplified interface. An few example use cases:
/// 1. Document list repository, where the query ID is business entity + document category while the variables include sorting and filtering options.
/// 2. File repository, where the query ID is typically some unique string, such as a UUID + prefix and the variables are a potentially temporary file URL.
public protocol QueryRepository<QueryId, Variables, Key, Value>: HasValueResult {
    
    associatedtype QueryId: SyncHashable

    associatedtype Variables: SyncHashable

    associatedtype Key: SyncHashable

    /// Performs the query, if needed, based on the query stategy of the underlying implementation.
    ///
    /// - Parameters:
    ///   - queryId: the query identifier
    ///   - variables: the query variables
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    ///   - queryStrategy: an optional query strategy to use. If specified, the given strategy will override the repo's default strategy for this call.
    ///   - willGet: a callback that is invoked if the query is performed.
    ///
    ///   When using a loading controller, the function `loadingController.loading` should be passed to the `willGet` parameter.
    @MainActor
    func get(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy?,
        willGet: @escaping Query.WillGet
    ) async

    /// Publishes results for the given query identifier. The publisher's first element will be the currently stored value, if any, at the time of the `publisher(for:setCurrent:)` call.
    ///
    /// - Parameter queryId: the query identifier
    /// - Parameter setCurrent: specifies the store key to switch to before creating the publisher
    ///
    /// Values will be published on the main queue, so there is no need to every use `receive(on: DispatchQueue.main)`
    /// and doing so will break the synchronous data pipieline needed for views to appear fully formed.
    ///
    /// It is important to recognize that this function has the side effect of setting the current key for the repository's internal observable store. This is done because the publisher
    /// emits the current value and view models should be explicit about what initial value the expect to receive rather than taking an arbitrary value. This is primarily needed for
    /// variable-based caching.
    @MainActor
    func publisher(for queryId: QueryId, setCurrent key: Key) -> AnyPublisher<ValueResult, Never>

    /// Prefetches for the given query ID and variables.
    /// - Parameters:
    ///   - queryId: the query identifier
    ///   - variables: the query variables
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    func prefetch(queryId: QueryId, variables: Variables, errorIntent: ErrorIntent) async
}

public extension QueryRepository {
    
    @MainActor
    func get(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy? = nil,
        willGet: @escaping Query.WillGet
    ) async {
        await get(
            queryId: queryId,
            variables: variables,
            errorIntent: errorIntent,
            queryStrategy: queryStrategy,
            willGet: willGet
        )
    }
    
    func prefetch(queryId: QueryId, variables: Variables, errorIntent: ErrorIntent = .dispensable) async {
        await prefetch(queryId: queryId, variables: variables, errorIntent: errorIntent)
    }
}

public extension QueryRepository where QueryId == Key {
    /// A convenience function that eliminates the need to specify the current key when values are stored by query ID.
    @MainActor
    func publisher(for queryId: QueryId) -> AnyPublisher<ValueResult, Never> {
        publisher(for: queryId, setCurrent: queryId)
    }
}
