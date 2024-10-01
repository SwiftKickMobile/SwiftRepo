//
//  ModelResponse.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/1/24.
//

import Foundation

public protocol ModelResponse {
    associatedtype Value
    associatedtype Model: StoreModel

    var value: Value { get }
    var models: [Model] { get }
}
