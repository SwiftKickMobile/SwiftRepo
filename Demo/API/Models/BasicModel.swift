//
//  BasicModel.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftRepo

public struct BasicModel: Equatable {
    public var items: [Item]

    public init(items: [Item]) {
        self.items = items
    }

    public enum Fixtures {}
}

public extension BasicModel.Fixtures {
    static let model0 = BasicModel(items: [])
    static let model1 = BasicModel(items: [Item.Fixtures.item1, Item.Fixtures.item2])
    static let model2 = BasicModel(items: [Item.Fixtures.item1, Item.Fixtures.item2, Item.Fixtures.item3, Item.Fixtures.item4])
}
