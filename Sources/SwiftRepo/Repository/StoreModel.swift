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

    /// The identifier of the model
    var id: Key { get }
    /// A predicate that can be used to query for the `StoreModel`
    static func predicate(key: Key, olderThan: TimeInterval?) -> Predicate<Self>
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
