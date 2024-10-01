//
//  StoreModel.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/1/24.
//

import Foundation

public protocol StoreModel {
    associatedtype Key = any Hashable

    var id: Key { get }
    var updatedAt: Date { get set }
    static func predicate(key: Key) -> Predicate<Self>
}

public extension StoreModel where Key == UUID {

    static func predicate(key: Key) -> Predicate<Self> {
        #Predicate<Self> { model in
            model.id == key
        }
    }
}
