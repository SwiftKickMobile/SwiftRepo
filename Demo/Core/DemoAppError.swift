//
//  DemoAppError.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftRepo

public protocol DemoAppError: AppError {
    var uiError: DemoUIError? { get }
    var isNotable: Bool { get }
    var isRetryable: Bool { get }
    var intent: ErrorIntent { get set }
}
