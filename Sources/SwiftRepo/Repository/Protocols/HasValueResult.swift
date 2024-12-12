//
//  Created by Timothy Moose on 7/20/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// This is a common parent of protocols like `QueryRepository`. For some reason, if I put these definitions
/// directly in `QueryRepository`, the compiler doesn't like it and I was getting compiler segmentation faults
/// compiling generated mocks.
public protocol HasValueResult {
    associatedtype Value: Sendable
    typealias ValueResult = Result<Value, Error>
}
