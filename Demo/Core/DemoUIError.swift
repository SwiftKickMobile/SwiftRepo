//
//  DemoUIError.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftRepo

public struct DemoUIError: UIError, Equatable {
    public var symbolName: String
    public var title: String
    public var message: String
    public var isRetryable: Bool

    public var id: String {
        title + message
    }

    public init(symbolName: String, title: String, message: String, isRetryable: Bool) {
        self.symbolName = symbolName
        self.title = title
        self.message = message
        self.isRetryable = isRetryable
    }
}
