//
//  TestError.swift
//
//
//  Created by Timothy Moose on 9/22/23.
//

import Foundation
import Core

public struct TestError: AppError, Equatable {
    
    // MARK: - API
    
    public var isRetryable: Bool = true
    
    public var isNotable: Bool = true
    
    public var uiError: (any Core.UIError)?
    
    public var category: Category
    
    public init(category: Category) {
        self.category = category
        self.uiError = DefaultUIError(message: "Oops", isRetryable: true)
    }
    
    // MARK: - Constants
    
    public enum Category {
        case failure
    }
    
    // MARK: - ErrorIntent
    
    public var intent: ErrorIntent = .dispensable
    
    public static func == (lhs: TestError, rhs: TestError) -> Bool {
        lhs.category == rhs.category
    }
}
