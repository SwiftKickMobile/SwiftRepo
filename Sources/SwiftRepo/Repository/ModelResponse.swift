//
//  ModelResponse.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/1/24.
//

import Foundation

/// A constrained response type that contains a `Value` and an array of `Model` types.
/// Partnered with a `QueryRepository` using an additional model store, `Value` will be
/// propagated via an `ObservableStore` and the array of `Model`s will be placed in
/// the `ModelStore`.
@available(iOS 17, *)
public protocol ModelResponse {
    /// Can be used to propagate additional metadata related to the response via an `ObservableStore`
    associatedtype Value
    /// The type that will be used in a repositories model store
    associatedtype Model: StoreModel

    var value: Value { get }
    var models: [Model] { get }
}
