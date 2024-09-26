//
//  Created by Timothy Moose on 11/3/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// Adopted by server response types that include data about the query variables that were used to construct the data set.
/// This is primarily used with queries that allow the service to select default variables and pass those selections back to the client.
/// The repository system uses this protocol to maintain unique store keys.
public protocol HasValueVariables {
    associatedtype QueryId: Hashable

    associatedtype Variables: Hashable

    func valueVariables(queryId: QueryId, variables: Variables) -> Variables
}
