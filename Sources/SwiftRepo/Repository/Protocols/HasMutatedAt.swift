//
//  Created by Timothy Moose on 10/11/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// A protocol that enforces a consistent pattern for mutation-related timestamps on data models.
/// This is used, for example, to help repositories know when locally mutated data can be overwritten with updates from the server.
public protocol HasMutatedAt {
    var createdAt: Date { get }
    var updatedAt: Date? { get }
}

public extension HasMutatedAt {
    /// Returns a timestamp indicating when the confirming type was last mutated, including it's creation.
    var mutatedAt: Date {
        updatedAt ?? createdAt
    }
}
