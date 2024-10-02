//
//  Created by Timothy Moose on 7/1/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import SwiftRepoCore

/// A single-use query repository where the query ID and variables are equivalent.
///
/// Intended to abstract away the lower-level `Query` and `ObservableStore` protocols into
/// a single, simplified interface. An example use case is formation tracker, where the variables are business entity UUID and time zone.
public protocol VariableQueryRepository<Variables, Value>: HasValueResult {
    
    associatedtype Variables: Hashable

    /// Performs the query, if needed, based on the query stategy of the underlying implementation.
    ///
    /// - Parameters:
    ///   - variables: the query variables
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    ///   - queryStrategy: an optional query strategy to use. If specified, the given strategy will override the repo's default strategy for this call.
    ///   - willGet: a callback that is invoked if the query is performed.
    ///
    ///   When using a loading controller, the function `loadingController.loading` should be passed to the `willGet` parameter.
    func get(
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy?,
        willGet: @escaping Query.WillGet
    ) async

    /// Publishes results for the given query identifier. The publisher's first element will be the currently stored value, if any, at the time of the `publisher(for:)` call.
    ///
    /// - Parameter variables: the query variables
    ///
    /// Values will be published on the main queue, so there is no need to every use `receive(on: DispatchQueue.main)`
    /// and doing so will break the synchronous data pipieline needed for views to appear fully formed.
    @MainActor
    func publisher(for variables: Variables) -> AnyPublisher<ValueResult, Never>

    /// Prefetches for the given variables.
    /// - Parameters:
    ///   - variables: the query variables
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    func prefetch(variables: Variables, errorIntent: ErrorIntent) async
}

public extension VariableQueryRepository {
    
    func get(
        variables: Variables,
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy? = nil,
        willGet: @escaping Query.WillGet
    ) async {
        await get(variables: variables, errorIntent: errorIntent, queryStrategy: queryStrategy, willGet: willGet)
    }
    
    func prefetch(variables: Variables, errorIntent: ErrorIntent = .dispensable) async {
        await prefetch(variables: variables, errorIntent: errorIntent)
    }
}
