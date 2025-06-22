//
//  Created by Timothy Moose on 10/23/24.
//

import SwiftRepoCore

/// A protocol that clients of `LoadingControllerView` can use to enable retry functionality for error states and pull-to-refresh.
@MainActor
public protocol Refreshable<UIErrorType>: AnyObject {
    associatedtype UIErrorType: UIError
    func refresh(retryError: UIErrorType?) async
}
