//
//  Created by Timothy Moose on 8/17/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// A `Result` for stores that includes the store key associated with the result. This is used for mapping results from queries to stores.
public struct StoreResult<Key, Success, Failure> where Key: Hashable, Failure: Error {
    
    public let key: Key
    public let result: Result<Success, Failure>

    public init(key: Key, success: Success) {
        self.init(key: key, result: .success(success))
    }

    public init(key: Key, failure: Failure) {
        self.init(key: key, result: .failure(failure))
    }

    public init(key: Key, result: Result<Success, Failure>) {
        self.key = key
        self.result = result
    }
}

extension StoreResult: Equatable where Success: Equatable, Failure: Equatable {}
