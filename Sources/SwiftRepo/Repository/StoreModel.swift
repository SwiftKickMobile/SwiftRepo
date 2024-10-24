//
//  StoreModel.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/1/24.
//

import Foundation

/// A model that can be placed and fetched in a `Store`.
/// This interface is to be used with models that will be retrieved by the app
/// through database queries, rather than published by a `QueryRepository`,
/// such as when using SwiftData.
public protocol StoreModel {
    /// The type to use as the identifier for the model
    associatedtype Key = any Hashable

    /// The identifier of the model
    var id: Key { get }

    /// A predicate that can be used to query for the `StoreModel`
    static func predicate(key: Key) -> Predicate<Self>
}

public extension StoreModel where Key == Data {

    static func predicate(key: Key) -> Predicate<Self> {
        #Predicate<Self> { model in
            model.id == key
        }
    }
}

public extension StoreModel where Key == UUID {

    static func predicate(key: Key) -> Predicate<Self> {
        #Predicate<Self> { model in
            model.id == key
        }
    }
}

public extension StoreModel where Key == String {

    static func predicate(key: Key) -> Predicate<Self> {
        #Predicate<Self> { model in
            model.id == key
        }
    }
}

public extension StoreModel where Key == Int {

    static func predicate(key: Key) -> Predicate<Self> {
        #Predicate<Self> { model in
            model.id == key
        }
    }
}
