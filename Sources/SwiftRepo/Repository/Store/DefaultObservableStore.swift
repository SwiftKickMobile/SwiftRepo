//
//  Created by Timothy Moose on 5/30/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation

public final class DefaultObservableStore<Key, PublishKey, Value>: ObservableStore where Key: Hashable, PublishKey: Hashable {
    // MARK: - API

    /// A closure that converts a key into a publish key. This mapping is required in order to route changes to the relevant publishers. The most common
    /// use cases are a) when both the key and publish keys are equivalent, typically the query ID and b) when the key is `QueryStoreKey` and the
    /// publish key is `key.queryId`. For both cases, convenience initializers are provided that supply the publish key mapping for you.
    public typealias PublishKeyMapping = (Key) -> PublishKey

    /// A closure that maps a key into another key. All keys that enter the store through public APIs are mapped. By default, the mapping returns the original key.
    /// However, with paged queries, the key, containing page info, is mapped to an equivalent key representing the first page. This provides a conanical
    /// way of accessing the paged data.
    public typealias KeyMapping = (Key) -> Key

    @MainActor
    @discardableResult
    public func set(key: Key, value: Value?) -> Value? {
        actorSet(key: map(key: key), value: value, isSettingCurrentKey: false)
    }

    @MainActor
    public func get(key: Key) -> Value? {
        store.get(key: map(key: key))
    }

    @MainActor
    public func age(of key: Key) -> TimeInterval? {
        store.age(of: map(key: key))
    }

    public func clear() async {
        await store.clear()
    }

    @MainActor
    public var keys: [Key] {
        store.keys
    }

    @MainActor
    public func publisher(for publishKey: PublishKey) -> AnyPublisher<ValueResult, Never> {
        let publisher: AnyPublisher<ValueResult, Never> = subject
            .filter { [weak self] in self?.publishKeyMapping($0.key) == publishKey }
            .map(\.result)
            .eraseToAnyPublisher()
        if let key = currentKey[publishKey], let current = store.get(key: key) {
            // Prepend the current value to the sequence.
            return Publishers.Merge(Just(.success(current)), publisher)
                .eraseToAnyPublisher()
        } else {
            return publisher.eraseToAnyPublisher()
        }
    }

    public var publisher: AnyPublisher<ValueResult, Never> {
        subject
            .map(\.result)
            .eraseToAnyPublisher()
    }

    public func changePublisher(for publishKey: PublishKey) -> AnyPublisher<ObservableStoreChange<Value>, Never> {
        changeSubject
            .filter { [weak self] in self?.publishKeyMapping($0.key) == publishKey }
            .map(\.value)
            .eraseToAnyPublisher()
    }

    public private(set) lazy var subscriber: AnySubscriber<StoreResultType, Never> = AnySubscriber { subscription in
        subscription.request(.unlimited)
    } receiveValue: { unmappedResult in
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let result = StoreResult(key: self.map(key: unmappedResult.key), result: unmappedResult.result)
            switch result.result {
            case let .success(value):
                self.set(key: result.key, value: value)
            case .failure:
                self.subject.send(result)
            }
        }
        return .unlimited
    } receiveCompletion: { _ in
    }

    public func subscriber(keyField: KeyPath<Value, Key>) -> AnySubscriber<Value, Never> {
        AnySubscriber { subscription in
            subscription.request(.unlimited)
        } receiveValue: { value in
            Task { [weak self] in
                guard let self = self else { return }
                let key = value[keyPath: keyField]
                await self.set(key: self.map(key: key), value: value)
            }
            return .unlimited
        } receiveCompletion: { _ in
        }
    }

    public func currentKey(for publishKey: PublishKey) async -> Key? {
        await currentKey[publishKey]
    }

    @MainActor
    public func set(currentKey: Key) {
        actorSet(currentKey: map(key: currentKey))
    }

    @MainActor
    public func map(key: Key) -> Key {
        let mappedKey = keyMapping(key)
        return additionalKeyMappings[mappedKey] ?? mappedKey
    }

    @MainActor
    public func addMapping(from unmappedFromKey: Key, to unmappedToKey: Key) {
        let fromKey = map(key: unmappedFromKey)
        let toKey = map(key: unmappedToKey)
        guard fromKey != toKey else { return }
        additionalKeyMappings[fromKey] = toKey
    }

    @MainActor
    public func keys(for publishKey: PublishKey) -> [Key] {
        keys.filter { publishKey == publishKeyMapping($0) }
    }

    @MainActor
    public func evict(for key: Key, ifOlderThan: TimeInterval) {
        guard let ageOf = store.age(of: key) else { return }
        if ageOf > ifOlderThan {
            store.set(key: key, value: nil)
        }
    }

    public func mutate(publishKey: PublishKey, mutation: (Key, Value) -> Value?) async {
        let timestamp = Date().timeIntervalSince1970
        for key in await keys(for: publishKey) {
            let elapsedTime = Date().timeIntervalSince1970 - timestamp
            guard let value = await store.get(key: key),
                  (await store.age(of: key) ?? TimeInterval.greatestFiniteMagnitude) > elapsedTime,
                  let mutatedValue = mutation(key, value) else { continue }
            switch await currentKey[publishKey] == key {
            case true:
                await actorSet(key: key, value: mutatedValue, isSettingCurrentKey: false)
            case false:
                await store.set(key: key, value: mutatedValue)
            }
        }
    }

    /// Creates a default observable store. There are simplified convenience initializers, so this one is typically not called directly.
    public init<Store: SwiftRepo.Store>(
        store: Store,
        keyMapping: @escaping KeyMapping = { $0 },
        publishKeyMapping: @escaping PublishKeyMapping
    )
        where Store.Key == Key, Store.Value == Value {
        self.store = store
        self.keyMapping = keyMapping
        self.publishKeyMapping = publishKeyMapping
    }

    /// Creates a default observable store when the key and publish keys are equivalent, typically the query ID.
    public convenience init<Store>(store: Store)
        where Store: SwiftRepo.Store,
        Key == Store.Key,
        Key == PublishKey,
        Value == Store.Value {
        self.init(store: store) { $0 }
    }

    /// Creates a default observable store when the key is `QueryStoreKey` and the publish key is inferred to be `key.queryId`.
    public convenience init<Store, Variables>(store: Store)
        where Store: SwiftRepo.Store,
        Variables: Hashable,
        Key == Store.Key,
        Key == QueryStoreKey<PublishKey, Variables>,
        Value == Store.Value {
        self.init(store: store) { $0.queryId }
    }

    /// Creates a default observable store a) when the is `QueryStoreKey` and the publish key is inferred to be  `key.queryId`
    /// and b) the variables conform to `HasCursorPaginationInput`
    public convenience init<Store, Variables>(store: Store)
        where Store: SwiftRepo.Store,
        Variables: Hashable & HasCursorPaginationInput,
        Key == Store.Key,
        Key == QueryStoreKey<PublishKey, Variables>,
        Value == Store.Value {
        self.init(store: store) { key in
            QueryStoreKey(queryId: key.queryId, variables: key.variables.asFirstPage)
        } publishKeyMapping: { key in
            key.queryId
        }
    }

    // MARK: - Constants

    // MARK: - Variables

    @MainActor
    private var store: any Store<Key, Value>
    @MainActor
    private let publishKeyMapping: PublishKeyMapping
    @MainActor
    private let keyMapping: KeyMapping
    @MainActor
    private var additionalKeyMappings: [Key: Key] = [:]
    @MainActor
    private let subject = PassthroughSubject<StoreResultType, Never>()
    @MainActor
    private let changeSubject = PassthroughSubject<(key: Key, value: ObservableStoreChange<Value>), Never>()
    @MainActor
    private var currentKey: [PublishKey: Key] = [:]

    // MARK: - Helpers

    // MARK: - Accessing actor-isolated state

    @MainActor
    @discardableResult
    private func actorSet(key: Key, value: Value?, isSettingCurrentKey: Bool) -> Value? {
        let currentValue = store.get(key: key)
        let updatedValue: Value?
        switch isSettingCurrentKey {
        case true: updatedValue = value
        case false: updatedValue = store.set(key: key, value: value)
        }
        currentKey[publishKeyMapping(key)] = value.map { _ in key }
        if let updatedValue = updatedValue {
            subject.send(StoreResult(key: key, result: .success(updatedValue)))
        }
        let change: ObservableStoreChange<Value>?
        switch (currentValue, updatedValue) {
        case let (.none, updatedValue?): change = .add(updatedValue)
        case let (current?, updatedValue?): change = .update(updatedValue, previous: current)
        case let (current?, .none): change = .delete(current)
        case (.none, .none): change = nil
        }
        if let change = change {
            changeSubject.send((key, change))
        }
        return updatedValue
    }

    @MainActor
    private func actorSet(key: Key, error: Error) {
        subject.send(StoreResult(key: key, result: .failure(error)))
    }

    @MainActor
    private func actorSet(currentKey key: Key) {
        // Nothing to do here if the key doesn’t exist in the store. We explicitly do not check if the incoming
        // key is equal to the current key because if has been a query error, we need to publish the value again
        // in order to clear the error.
        let value = store.get(key: key)
        print("XXXX CACHE \(value == nil ? "MISS" : "HIT") key=\(key)")
        // There are no new values being stored, so there is no need to write to store.
        actorSet(key: key, value: value, isSettingCurrentKey: true)
    }
}
