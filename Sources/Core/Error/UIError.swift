//
//  Created by Timothy Moose on 6/18/23.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import SwiftUI

/// A model for user-facing error messages to be displayed in the UI
///
/// Use `DefaultUIError` or implement your own to have more rich
/// data types including images, titles, etc.
public protocol UIError: Error, Identifiable {
    var message: String { get }
    var isRetryable: Bool { get }
}

public extension UIError {
    
    /// Override this if needed, for example, if
    /// your error implementation includes a title.
    var id: String { message + "_\(isRetryable)" }
}

/// This is a default, minimal implementation. If you need titles, images, etc.
/// you can provide your own implementation of `UIError`.
public struct DefaultUIError: UIError {

    public static func `default`(isRetryable: Bool) -> some UIError {
        DefaultUIError(
            message: isRetryable ? "Something went wrong—please try again." : "Something went wrong.",
            isRetryable: isRetryable
        )
    }

    public var message: String
    public var isRetryable: Bool

    public init(
        message: String,
        isRetryable: Bool
    ) {
        self.message = message
        self.isRetryable = isRetryable
    }
}
