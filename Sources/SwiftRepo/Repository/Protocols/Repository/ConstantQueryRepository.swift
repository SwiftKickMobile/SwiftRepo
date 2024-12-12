//
//  Created by Timothy Moose on 7/5/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import SwiftRepoCore

/// A single-use query repository where the query ID and variables are both equivalent and constant.
///
/// Intended to abstract away the lower-level `Query` and `ObservableStore` protocols into
/// a single, simplified interface.  An example use case is account service. Specifically getting account info, which requires no input variables.
public protocol ConstantQueryRepository<Variables, Value>: HasValueResult {
    
    associatedtype Variables: SyncHashable

    /// Performs the query, if needed, based on the query stategy of the underlying implementation.
    ///
    /// - Parameters:
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    ///   - queryStrategy: an optional query strategy to use. If specified, the given strategy will override the repo's default strategy for this call.
    ///   - willGet: a callback that is invoked if the query is performed.
    ///
    ///   When using a loading controller, the function `loadingController.loading` should be passed to the `willGet` parameter.
    @MainActor
    func get(errorIntent: ErrorIntent, queryStrategy: QueryStrategy?, willGet: @escaping Query.WillGet) async

    /// Publishes results. The publisher's first element will be the currently stored value, if any, at the time of the `publisher()` call.
    ///
    /// - Parameter variables: the query variables
    ///
    /// Values will be published on the main queue, so there is no need to every use `receive(on: DispatchQueue.main)`
    /// and doing so will break the synchronous data pipieline needed for views to appear fully formed.
    @MainActor
    func publisher() -> AnyPublisher<ValueResult, Never>

    /// Prefetches.
    ///
    /// - Parameters:
    ///   - errorIntent: The error intent to apply to errors that are thrown by the query
    func prefetch(errorIntent: ErrorIntent) async
}

public extension ConstantQueryRepository {
    
    @MainActor
    func get(
        errorIntent: ErrorIntent,
        queryStrategy: QueryStrategy? = nil,
        willGet: @escaping Query.WillGet
    ) async {
        return await get(errorIntent: errorIntent, queryStrategy: queryStrategy, willGet: willGet)
    }
    
    func prefetch(errorIntent: ErrorIntent = .dispensable) async {
        return await prefetch(errorIntent: errorIntent)
    }
}
