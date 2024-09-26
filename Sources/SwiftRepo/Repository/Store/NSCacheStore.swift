//
//  Created by Timothy Moose on 6/9/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation

// An in-memory implementation of `Store` that uses a default `NSCache`
public final actor NSCacheStore<Key, Value>: Store where Key: Hashable {
    // MARK: - API

    @MainActor
    public func set(key: Key, value: Value?) -> Value? {
        let wrappedKey = KeyBox(key: key)
        switch value {
        case let value?:
            let boxed = ValueBox(value: TimestampedValue(value: value))
            store.setObject(boxed, forKey: wrappedKey)
            knownSetKeys.insert(key)
        case .none:
            store.removeObject(forKey: wrappedKey)
            knownSetKeys.remove(key)
        }
        return value
    }

    @MainActor
    public func get(key: Key) -> Value? {
        store.object(forKey: KeyBox(key: key))?.boxed.value
    }

    @MainActor
    public func age(of key: Key) -> TimeInterval? {
        store.object(forKey: KeyBox(key: key))?.boxed.ageOf
    }

    public func clear() async {
        await actorClear()
    }

    @MainActor
    public var keys: [Key] {
        // Need to check that known keys are still valid since the `NSCache` may evict keys from the store.
        // The `NSCacheDelegate` protocol inexplicably doesn't specify the key when reporting object evictions,
        // so it doesn't help with this bookeeping.
        knownSetKeys.filter { key in
            if store.object(forKey: KeyBox(key: key)) == nil {
                knownSetKeys.remove(key)
                return false
            }
            return true
        }
    }

    public init() {}

    // MARK: - Constants

    // MARK: - Variables

    @MainActor
    private var store = NSCache<KeyBox<Key>, ValueBox<Value>>()

    @MainActor
    // `NSCache` doesn't provide a list of known keys, so we need to track this ourselves.
    private var knownSetKeys = Set<Key>()

    // MARK: - Accessing actor-isolated state

    @MainActor
    private func actorClear() {
        store.removeAllObjects()
    }
}

/// Box the key in an `NSObject` as required by `NSCache`
private final class KeyBox<Key>: NSObject where Key: Hashable {
    init(key: Key) {
        boxed = key
    }

    private let boxed: Key

    override var hash: Int { boxed.hashValue }

    override func isEqual(_ object: Any?) -> Bool {
        guard let value = object as? KeyBox else {
            return false
        }

        return value.boxed == boxed
    }
}

/// Box `TimeStampedValue` in a class as required by `NSCache`.
private final class ValueBox<Value> {
    init(value: TimestampedValue<Value>) {
        boxed = value
    }

    let boxed: TimestampedValue<Value>
}
