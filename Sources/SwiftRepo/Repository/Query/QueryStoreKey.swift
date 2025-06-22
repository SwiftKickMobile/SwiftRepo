//
//  Created by Timothy Moose on 8/16/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// A data model to use for storing query results by query ID and variables. This can type can be used as the store key in order to
/// maintain a cache for all variables rather than just the most recently used variable.
public struct QueryStoreKey<QueryId: Hashable & Sendable, Variables: Hashable & Sendable>: Hashable, Sendable {
    public let queryId: QueryId
    public let variables: Variables

    public init(queryId: QueryId, variables: Variables) {
        self.queryId = queryId
        self.variables = variables
    }
}

public extension QueryStoreKey where QueryId == Unused {
    init(variables: Variables) {
        queryId = .unused
        self.variables = variables
    }
}

public extension QueryStoreKey where QueryId == Unused, Variables == Unused {
    init() {
        queryId = .unused
        variables = .unused
    }
}
