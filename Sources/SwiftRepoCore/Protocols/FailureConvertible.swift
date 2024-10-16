//
//  Created by Timothy Moose on 7/5/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

public protocol FailureConvertible {
    associatedtype Failure: Error
    var failure: Failure? { get }
}
