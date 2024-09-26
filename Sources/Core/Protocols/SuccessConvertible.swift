//
//  Created by Timothy Moose on 6/17/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

public protocol SuccessConvertible {
    associatedtype Success
    var success: Success? { get }
}
