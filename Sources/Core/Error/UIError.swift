//
//  Created by Timothy Moose on 6/18/23.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import SwiftUI



/// A model for user-facing error messages to be displayed in the UI
public struct UIError: Error, Hashable {

    public static func `default`(isRetryable: Bool) -> UIError {
        UIError(
            message: isRetryable ? "Something went wrong—please try again." : "Something went wrong.",
            isRetryable: isRetryable
        )
    }

    public var symbol: SFSymbol
    public var title: String
    public var message: String
    public var isRetryable: Bool

    public init(
        symbol: SFSymbol = .exclamationmarkTriangle,
        title: String = "Error",
        message: String,
        isRetryable: Bool
    ) {
        self.symbol = symbol
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }
}

extension UIError: Identifiable {
    public var id: String { message + "_\(isRetryable)" }
}
