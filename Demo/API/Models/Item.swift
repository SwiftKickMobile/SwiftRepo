//
//  Item.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

public struct Item: Equatable, Identifiable {
    public var id: Int
    public var text: String

    public enum Fixtures {}
}

public extension Item.Fixtures {
    static let item1 = Item(id: 1, text: "Item 1")
    static let item2 = Item(id: 2, text: "Item 2")
    static let item3 = Item(id: 3, text: "Item 3")
    static let item4 = Item(id: 4, text: "Item 4")
}

