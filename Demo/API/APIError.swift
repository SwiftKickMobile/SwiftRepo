//
//  APIError.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftRepo
import Core

public struct APIError: DemoAppError {

    public var uiError: DemoUIError? {
        DemoUIError(
            symbolName: "exclamationmark.triangle.fill",
            title: "Oops!",
            message: "Something bad happened.",
            isRetryable: isRetryable
        )
    }

    public var isNotable: Bool

    public var isRetryable: Bool

    public var intent: ErrorIntent

    public init(isNotable: Bool, isRetryable: Bool, intent: ErrorIntent) {
        self.isNotable = isNotable
        self.isRetryable = isRetryable
        self.intent = intent
    }
}
