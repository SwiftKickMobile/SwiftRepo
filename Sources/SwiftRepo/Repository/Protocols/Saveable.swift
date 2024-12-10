//
//  Saveable.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 12/10/24.
//

import Foundation

/// A protocol for a `Store` that provides a hook to `save`, or commit any outstanding changes.
public protocol Saveable {
    
    /// Commit any outstanding changes made to a store.
    func save() async throws
}
