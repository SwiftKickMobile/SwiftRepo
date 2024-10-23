//
//  Created by Timothy Moose on 10/23/24.
//

import SwiftRepoCore

/// A protocol that clients of `LoadingControllerView` can use to enable retry functionality for error states and pull-to-refresh.
public protocol Refreshable: AnyObject {
    func refresh(retryError: (any UIError)?) async
}
