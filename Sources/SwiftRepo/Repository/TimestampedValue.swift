//
//  Created by Timothy Moose on 6/9/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation
import SwiftData

/// A helper type that can be used with implementations of `Store` that provides the `ageOf` calculation.
struct TimestampedValue<Value> {
    
    var timestamp: TimeInterval
    var value: Value

    init(value: Value) {
        timestamp = Date().timeIntervalSince1970
        self.value = value
    }

    var ageOf: TimeInterval {
        Date().timeIntervalSince1970 - timestamp
    }
}
