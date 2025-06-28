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
@MainActor
public protocol QueryRepository<QueryId, Variables, Key, Value>: HasValueResult {
    
    associatedtype QueryId: Hashable

    associatedtype Variables: Hashable

    associatedtype Key: Hashable

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
    func get(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy?,
        willGet: @escaping Query.WillGet
    ) async

    /// Performs the query and returns the result value directly.
    ///
    /// This method is intended for use cases where you need a single value and don't require streaming updates.
    /// Unlike the standard `get()` method, this variant throws errors and returns the fetched value directly.
    ///
    /// - Parameters:
    ///   - queryId: the query identifier
    ///   - variables: the query variables
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    ///   - queryStrategy: an optional query strategy to use. If specified, the given strategy will override the repo's default strategy for this call.
    ///   - willGet: a callback that is invoked if the query is performed.
    /// - Returns: The fetched value
    /// - Throws: Any error that occurs during the query operation
    ///
    ///   When using a loading controller, the function `loadingController.loading` should be passed to the `willGet` parameter.
    func getValue(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy?,
        willGet: @escaping Query.WillGet
    ) async throws -> Value

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
    func publisher(for queryId: QueryId, setCurrent key: Key) async -> AnyPublisher<ValueResult, Never>

    /// Prefetches for the given query ID and variables.
    /// - Parameters:
    ///   - queryId: the query identifier
    ///   - variables: the query variables
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    func prefetch(queryId: QueryId, variables: Variables, errorIntent: ErrorIntent) async
}

public extension QueryRepository {
    
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
    
    func getValue(
        queryId: QueryId,
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy? = nil,
        willGet: @escaping Query.WillGet
    ) async throws -> Value {
        return try await getValue(
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
    func publisher(for queryId: QueryId) async -> AnyPublisher<ValueResult, Never> {
        await publisher(for: queryId, setCurrent: queryId)
    }
}
