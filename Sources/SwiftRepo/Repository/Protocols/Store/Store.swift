//
//  Created by Timothy Moose on 6/3/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

/// An interface for in-memory and/or persistent storage of key/value pairs.
public protocol Store<Key, Value> {
    /// The type of key used by the store.
    associatedtype Key: Hashable

    /// The type of value stored.
    associatedtype Value

    /// Set or remove a value from the cache.
    /// - Parameters:
    ///   - key: the unique key
    ///   - value: the value to store. Pass `nil` to delete any existing value.
    @MainActor
    @discardableResult
    func set(key: Key, value: Value?) throws -> Value?

    /// Get a value from the cache.
    /// - Parameter key: the unique key
    /// - Returns: the current value contained in the store. Returns `nil` if there is no value.
    @MainActor
    func get(key: Key) throws -> Value?

    /// Returns the age of the current value assigned to the given key
    @MainActor
    func age(of key: Key) throws -> TimeInterval?

    /// Removes all values. Does not publish any changes.
    func clear() async throws

    /// Return all keys that exist in the store.
    @MainActor
    var keys: [Key] { get }
}
