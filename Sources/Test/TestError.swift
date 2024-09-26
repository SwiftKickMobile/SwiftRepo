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
    
    public var uiError: Core.UIError?
    
    public var category: Category
    
    public init(category: Category) {
        self.category = category
        self.uiError = UIError(message: "Oops", title: "Bad", image: nil, isRetryable: true)
    }
    
    // MARK: - Constants
    
    public enum Category {
        case failure
    }
    
    // MARK: - ErrorIntent
    
    public var intent: ErrorIntent = .dispensable
}
