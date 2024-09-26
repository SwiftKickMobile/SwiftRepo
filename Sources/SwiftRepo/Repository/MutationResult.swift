//
//  Created by Timothy Moose on 8/18/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// A `Result` for mutations that includes the associated mutation ID and variables. This is used for mapping results from queries to stores.
public struct MutationResult<MutationId, Variables, Success, Failure> where MutationId: Hashable, Variables: Hashable, Failure: Error {
    
    public let mutationId: MutationId
    public let variables: Variables

    public let result: Result<Success, Failure>

    public init(mutationId: MutationId, variables: Variables, success: Success) {
        self.init(mutationId: mutationId, variables: variables, result: .success(success))
    }

    public init(mutationId: MutationId, variables: Variables, failure: Failure) {
        self.init(mutationId: mutationId, variables: variables, result: .failure(failure))
    }

    public init(mutationId: MutationId, variables: Variables, result: Result<Success, Failure>) {
        self.mutationId = mutationId
        self.variables = variables
        self.result = result
    }
}

extension MutationResult: Equatable where Success: Equatable, Failure: Equatable {}
