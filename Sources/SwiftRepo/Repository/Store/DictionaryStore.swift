//
//  Created by Timothy Moose on 6/9/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

// An in-memory implementation of `Store` that uses a `Dictionary`
public final actor DictionaryStore<Key, Value>: Store where Key: Hashable {
    // MARK: - API

    /// A closure that defines how old values are merged with new values.
    public typealias Merge = (_ old: Value, _ new: Value) -> Value

    @MainActor
    public func set(key: Key, value: Value?) -> Value? {
        switch value {
        case let value?:
            if var currentValue = store[key], let merge = merge {
                currentValue.value = merge(currentValue.value, value)
                store[key] = currentValue
            } else {
                store[key] = TimestampedValue(value: value)
            }
        case .none:
            store[key] = nil
        }
        return store[key]?.value
    }

    @MainActor
    public func get(key: Key) -> Value? {
        store[key]?.value
    }

    @MainActor
    public func age(of key: Key) -> TimeInterval? {
        store[key]?.ageOf
    }

    public func clear() async {
        await actorClear()
    }

    @MainActor
    public var keys: [Key] {
        Array(store.keys)
    }

    /// Creates a dictionary store. An optional merge operation can be defined for cases like paged queries.
    /// - Parameter merge: the optional operation to merge existing value with new value.
    public init(merge: Merge? = nil) {
        self.merge = merge
    }

    // MARK: - Constants

    // MARK: - Variables

    @MainActor
    private var store: [Key: TimestampedValue<Value>] = [:]
    private let merge: Merge?

    // MARK: - Accessing actor-isolated state

    @MainActor
    private func actorClear() {
        store.removeAll()
    }
}
