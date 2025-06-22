//
//  Created by Timothy Moose on 6/3/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// A `Result` for queries that includes the associated query ID and variables. This is used for mapping results from queries to stores.
public struct QueryResult<QueryId, Variables, Success, Failure>: Sendable where QueryId: Hashable, Variables: Hashable, Failure: Error, QueryId: Sendable, Variables: Sendable, Success: Sendable, Failure: Sendable {
    
    public let queryId: QueryId
    public let variables: Variables

    public let result: Result<Success, Failure>

    public init(queryId: QueryId, variables: Variables, success: Success) {
        self.init(queryId: queryId, variables: variables, result: .success(success))
    }

    public init(queryId: QueryId, variables: Variables, failure: Failure) {
        self.init(queryId: queryId, variables: variables, result: .failure(failure))
    }

    public init(queryId: QueryId, variables: Variables, result: Result<Success, Failure>) {
        self.queryId = queryId
        self.variables = variables
        self.result = result
    }
}

extension QueryResult: Equatable where Success: Equatable, Failure: Equatable {}
