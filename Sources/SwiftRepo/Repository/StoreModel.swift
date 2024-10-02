//
//  StoreModel.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/1/24.
//

import Foundation

/// A model that can be placed and fetched in a store.
public protocol StoreModel {
    /// The type to use as the identifier for the model
    associatedtype Key = any Hashable

    var id: Key { get }
    var updatedAt: Date { get set }
    /// A predicate that can be used to query for the `StoreModel`
    static func predicate(key: Key, olderThan: TimeInterval?) -> Predicate<Self>
    /// A merge strategy to use when a `Value` with the `Key` is already saved in a `Store`.
    /// If the new `Value` should be used, simply return `new`.
    static func merge(existing: Self, new: Self) -> Self
}

public extension StoreModel {
    // By default, assume a strategy of replacing the existing value.
    static func merge(existing: Self, new: Self) -> Self {
        new
    }
}

public extension StoreModel where Key == UUID {

    static func predicate(key: Key, olderThan: TimeInterval?) -> Predicate<Self> {
        if let olderThan {
            let olderThanDate = Date().advanced(by: -olderThan)
            return #Predicate<Self> { model in
                model.id == key && model.updatedAt < olderThanDate
            }
        } else {
            return #Predicate<Self> { model in
                model.id == key
            }
        }
    }
}
