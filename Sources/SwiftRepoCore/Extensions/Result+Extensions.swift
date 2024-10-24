//
//  Created by Timothy Moose on 6/17/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine

extension Result: SuccessConvertible {
    public var success: Success? {
        switch self {
        case let .success(output): return output
        case .failure: return nil
        }
    }
}

extension Result: FailureConvertible {
    public var failure: Failure? {
        switch self {
        case .success: return nil
        case let .failure(error): return error
        }
    }
}
