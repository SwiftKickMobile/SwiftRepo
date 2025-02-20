//
//  Created by Timothy Moose on 8/16/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// A list of strategies for determining when stored data needs to be refreshed.
public enum QueryStrategy: Sendable {
    /// A new query is performed if the stored data is older than the specified `TimeInterval`.
    /// Stored data is provided initially, regardless of the age of the stored value.
    case ifOlderThan(TimeInterval)
    /// A new query is performed if there is no stored data.
    case ifNotStored
    /// A new query is always performed. If there is data stored, it will be provided initially.
    case always
    ///  No query called ever, in case the data is derived from some other query
    case never
}
