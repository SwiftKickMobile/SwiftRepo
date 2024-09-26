//
//  Created by Timothy Moose on 5/24/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation
import Core

/// A sub-protocol of `Store` for in-memory and/or persistent caching of key/value pairs and publishing changes over time.
///
/// An `ObservableStore` is typically connected to an instace of `Query` where remote data would flow into the system as follows:
///
///     `[data access component] < ObservableStore < Query < [service query]`
public protocol ObservableStore<Key, PublishKey, Value>: Store {

    associatedtype Value
    typealias ValueResult = Result<Value, Error>

    /// The key to use for publishing a subset of values in the store, most typically the query ID. This decouples the scope of a publisher from any specific key. The most common use case
    /// for this decoupling is when storing the values for all variables for a given query ID in order to provide highly granular caching. In this scenario, the convenience
    /// type `QueryStoreKey` serves as the key, encapsulating both the query ID and the variables, while the query ID serves as the publish key. If this level of granulatity is not needed,
    /// the key and publish key can be equivalent, e.g. the query ID, if only the most recent value needs to be stored for a given key. In most cases, `QueryStoreKey` should be
    /// used because it provides the most responsive user experience. Query ID is a better choice if the variables are constant or cannot be relied upon to as a stable identifier
    /// (e.g. temporary FileStack URLs).
    associatedtype PublishKey: Hashable

    /// The identifiable result type used by subscribers.
    typealias StoreResultType = StoreResult<Key, Value, Error>

    /// Publishes values for the specified publish key, including the current value, if there is one. The store implementation is responsible for knowing how to map from key to publish key
    /// in order to route stored values to the revevant publishers. Implementations must also treat the most recently used key as the "current key" in order to initialize new
    /// publishers with the current value.
    /// - Parameter publishKey: The publish key, most typically the query ID.
    /// - Returns: a publisher that emits the sequence of values for the specified key.
    @MainActor
    func publisher(for publishKey: PublishKey) -> AnyPublisher<ValueResult, Never>

    /// Publishes results for all keys. Does not publish current values.
    var publisher: AnyPublisher<ValueResult, Never> { get }

    /// Publishes changes for the specified publish key. The store implementation is responsible for knowing how to map from key to publish key
    /// in order to route stored values to the revevant publishers.
    /// - Parameter publishKey: The publish key, most typically the query ID.
    /// - Returns: a publisher that emits the sequence of changes.
    /// This publisher can be used for fine grained observation of addtion, change and deletion of values for the specified key.
    func changePublisher(for publishKey: PublishKey) -> AnyPublisher<ObservableStoreChange<Value>, Never>

    /// Subscribes to a sequence of identifiable results.
    /// - Returns: a subscriber that can be assigned to an identifiable results publisher.
    /// This function is typically used to connect a `Query` publisher to the store.
    var subscriber: AnySubscriber<StoreResultType, Never> { get }

    /// Subscribes to a sequence of values using the specified key path to retrieve the value's key.
    /// - Parameter keyField: the key path on `Value` that returns the value's key.
    /// - Returns: a subscriber that can be connected to a result publisher.
    /// This function is typically used to map an array of values into the store, e.g. `[Value].publisher.assign(to: store.subscriber(keyField \.uuid)`
    func subscriber(keyField: KeyPath<Value, Key>) -> AnySubscriber<Value, Never>

    /// Returns the key associated with the most recent value placed in the store for the given publish key. This can be used to retrieve the current value. However, it primarily
    /// exists for use with `QueryStoreKey` and query logic to determine if the variables of the query match the variables for the current value.
    func currentKey(for publishKey: PublishKey) async -> Key?

    /// Explicitly sets the current key. Store implementations must ignore this call if the given key does not already existin the store or if the key is already the current key.
    /// This primarily exists for use with `QueryStoreKey` and query logic. Making this call before performing a new query causes the new current value to be published, allowing
    /// views to display stored data matchin the new variables while the query is being performed (or if the data is fresh enough, the query need not be performed at all).
    @MainActor
    func set(currentKey key: Key)

    /// Returns all of the keys associated with the specified publish key.
    /// - Parameter publishKey: the publish key
    /// - Returns: all keys associated with the given publish key
    @MainActor
    func keys(for publishKey: PublishKey) -> [Key]

    /// Add an equivalence mapping from one key to another that helps the observable store internally maintain uniqueness of store keys. This is primarily used with queries
    /// that return variables in the response.
    /// - Parameters:
    ///   - fromKey: the key that will be mapped to the `toKey`
    ///   - toKey: the key that the store uses as the canonical key.
    @MainActor
    func addMapping(from fromKey: Key, to toKey: Key)

    /// Returns the canonical key used by the store for the given key.
    /// - Parameter key: the possibly non-canonical key
    /// - Returns: the canonical key
    /// There are a number of scenarios where keys are not unique and the store needs to keep track of canonical keys and their equivalents. Scenarios where keys
    /// aren't unique is when they contain paging variables or were added explicitly with `addMapping(from:to:)`
    @MainActor
    func map(key: Key) -> Key

    @MainActor
    /// Removes the specified key from the store if it is older than the specified time interval.
    /// - Parameters:
    ///   - key: the key to evict
    ///   - ifOlderThan: the threshold that designates a value as being old enough to evict
    func evict(for key: Key, ifOlderThan: TimeInterval)

    /// Iterates over all keys in the store associated with the given publish key and applies the specified optional mutation. If the value of the current key is mutated,
    /// then the mutated value is puslished. This primarily exists for use with `QueryStoreKey` and optimistic mutation since there may be multiple stored values
    /// for any given query ID that need to be updated. If a particular value does not need to be mutated, the mutation may return `nil`.
    func mutate(publishKey: PublishKey, mutation: (_ key: Key, _ value: Value) -> Value?) async
}

/// Enumerates the types of changes that may be published by the store.
public enum ObservableStoreChange<Value> {
    /// Value is newly added
    case add(Value)

    /// Existing value is updated
    case update(Value, previous: Value)

    /// Value was deleted
    case delete(Value)
}

public extension ObservableStore {
    /// Maps a list of values emitted by this observable store into a single-value observable store, but only if the upstream values are newer. The newness criteria allows
    /// local (optimistic) updates to be made without concern for them being overwritten. This version of `setNewerValues` is for cases where the list of values is
    /// accessible at a key path on the upstream value.
    ///
    /// The following conventions must be followed for this system to work:
    ///
    /// 1. Values must adopt the `HasMutatedAt` protocol to provide the timestamp.
    /// 2. Local updates must not modify these timestamps.
    /// 3. Local updates to values must only be made in the downstream, single-value observable store (the upstream store can modify the list of values by inserting, deleting or moving)
    ///
    /// A typical example is the product catalog, in which we have an obserable store for the product list and an observable store for individual products.
    ///
    /// The product list store provides an array of products. However, these products are only used as placeholders to avoid optionality in view models. View models should always
    /// get individual products from the product store.
    ///
    /// ````
    /// productListStore.publisher
    ///    .receiveNewerValues(keyField: \.uuid, store: productStore)
    /// ````
    /// - Parameters:
    ///   - keyField: a `KeyPath` into `Value` that provides a `Key` for the store
    ///   - store: the single-value observable store
    func setNewerValues<Key, PublishKey, Value>(
        keyField: KeyPath<Value, Key>,
        store: some ObservableStore<Key, PublishKey, Value>
    ) where Value: HasMutatedAt, ValueResult: SuccessConvertible, ValueResult.Success == [Value] {
        publisher.success()
            .flatMap(\.publisher)
            .receive(subscriber: store.newValueSubscriber(keyField: keyField))
    }

    /// Maps a list of values emitted by this observable store into a single-value observable store, but only if the upstream values are newer.
    /// The newness criteria allows local (optimistic) updates to be made without concern for them being overwritten.
    ///
    /// The following conventions must be followed for this system to work:
    ///
    /// 1. Values must adopt the `HasMutatedAt` protocol to provide the timestamp.
    /// 2. Local updates must not modify these timestamps.
    /// 3. Local updates to values must only be made in the downstream, single-value observable store (the upstream store can modify the list of values by inserting, deleting or moving)
    ///
    /// A typical example is document center, in which we have an obserable store for document list results and an observable store for individual documents.
    ///
    /// The document list store provides list metadata, such as the unread document count, and a list of documents. However, these documents are only used as
    /// placeholders to avoid optionality in view models. View models should always get individual documents from the document store.

    /// ````
    /// documentListStore.publisher
    ///    .receiveNewerValues(fromField: \.documents, keyField: \.documentUuid, store: documentStore)
    /// ````
    /// - Parameters:
    ///   - fromField: a `KeyPath` into this publisher's `Success` that provides the array of values.
    ///   - keyField: a `KeyPath` into `Value` that provides its store `Key`.
    ///   - store: the single-value observable store.
    func setNewerValues<Success, Key, PublishKey, Value>(
        fromField: KeyPath<Success, [Value]>,
        keyField: KeyPath<Value, Key>,
        store: some ObservableStore<Key, PublishKey, Value>
    ) where Value: HasMutatedAt, ValueResult: SuccessConvertible, ValueResult.Success == Success {
        publisher.success()
            .map { $0[keyPath: fromField] }
            .flatMap(\.publisher)
            .receive(subscriber: store.newValueSubscriber(keyField: keyField))
    }

    /// Clears keys associated with a given publish key.
    /// - Parameter publishKey: the publish key to clear
    func clear(publishKey: PublishKey) async {
        for key in await keys(for: publishKey) {
            await set(key: key, value: nil)
        }
    }
}

extension ObservableStore where Value: HasMutatedAt {
    /// Creates a subscriber that updates the store if the incoming values are newer than the existing value. `Value` must conform to `HasMutatedAt`.
    /// - Parameter keyField: a `KeyPath` into `Value` that provides its store `Key`.
    /// - Returns: the subscriber.
    func newValueSubscriber(keyField: KeyPath<Value, Key>) -> AnySubscriber<Value, Never> {
        AnySubscriber { subscription in
            subscription.request(.unlimited)
        } receiveValue: { value in
            Task {
                let key = value[keyPath: keyField]
                if let currentMutatedAt = await self.get(key: key)?.mutatedAt,
                   value.mutatedAt <= currentMutatedAt {
                    return
                }
                await self.set(key: key, value: value)
            }
            return .unlimited
        } receiveCompletion: { _ in
        }
    }
}

extension ObservableStoreChange: Equatable where Value: Equatable {}
