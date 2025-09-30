//
//  ErrorIntent.swift
//  
//
//  Created by Carter Foughty on 6/4/24.
//

import Foundation

/// A standard enum indicating an intent or purpose for the error from the perspective of the caller
public enum ErrorIntent: String, Sendable {
    case dispensable
    case indispensable
}
