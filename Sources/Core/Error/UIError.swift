//
//  Created by Timothy Moose on 6/18/23.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import SwiftUI

/// A model for user-facing error messages to be displayed in the UI
public protocol UIError: Error, Identifiable {
    var message: String { get }
    var isRetryable: Bool { get }
}

public extension UIError {
    var id: String { message + "_\(isRetryable)" }
}

public struct DefaultUIError: UIError {

    public static func `default`(isRetryable: Bool) -> some UIError {
        DefaultUIError(
            icon: Image(systemName: "car"),
            message: isRetryable ? "Something went wrong—please try again." : "Something went wrong.",
            isRetryable: isRetryable
        )
    }

    public var icon: Image
    public var title: String
    public var message: String
    public var isRetryable: Bool

    public init(
        icon: Image,
        title: String = "Error",
        message: String,
        isRetryable: Bool
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }
}
