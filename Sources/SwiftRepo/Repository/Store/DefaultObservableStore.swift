//
//  Created by Timothy Moose on 5/30/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import Foundation

@MainActor
public final class DefaultObservableStore<Key: Hashable & Sendable, PublishKey: Hashable & Sendable, Value: Sendable>: ObservableStore {
    // MARK: - API

    /// A closure that converts a key into a publish key. This mapping is required in order to route changes to the relevant publishers. The most common
    /// use cases are a) when both the key and publish keys are equivalent, typically the query ID and b) when the key is `QueryStoreKey` and the
    /// publish key is `key.queryId`. For both cases, convenience initializers are provided that supply the publish key mapping for you.
    public typealias PublishKeyMapping = (Key) -> PublishKey

    /// A closure that maps a key into another key. All keys that enter the store through public APIs are mapped. By default, the mapping returns the original key.
    /// However, with paged queries, the key, containing page info, is mapped to an equivalent key representing the first page. This provides a conanical
    /// way of accessing the paged data.
    public typealias KeyMapping = (Key) -> Key

    @discardableResult
    @AsyncLocked
    public func set(key: Key, value: Value?) async throws -> Value? {
        let mappedKey = map(key: key)
        let currentValue = try await store.get(key: mappedKey)
        let updatedValue: Value?
        switch value {
        case .some(let value):
            updatedValue = try await store.set(key: mappedKey, value: value)
        case .none:
            updatedValue = try await store.set(key: mappedKey, value: nil)
        }
        currentKey[publishKeyMapping(mappedKey)] = updatedValue.map { _ in mappedKey }
        if let updatedValue = updatedValue {
            subject.send(StoreResult(key: mappedKey, result: .success(updatedValue)))
        }
        let change: ObservableStoreChange<Value>?
        switch (currentValue, updatedValue) {
        case let (.none, updatedValue?): change = .add(updatedValue)
        case let (current?, updatedValue?): change = .update(updatedValue, previous: current)
        case let (current?, .none): change = .delete(current)
        case (.none, .none): change = nil
        }
        if let change = change {
            changeSubject.send((mappedKey, change))
        }
        return updatedValue
    }

    @AsyncLocked
    public func get(key: Key) async throws -> Value? {
        try await store.get(key: map(key: key))
    }

    @AsyncLocked
    public func age(of key: Key) async throws -> TimeInterval? {
        try await store.age(of: map(key: key))
    }

    @AsyncLocked
    public func clear() async throws {
        try await store.clear()
    }

    public var keys: [Key] {
        get throws {
            try store.keys
        }
    }

    @AsyncLocked
    public func publisher(for publishKey: PublishKey) async -> AnyPublisher<ValueResult, Never> {
        let publisher: AnyPublisher<ValueResult, Never> = subject
            .filter { [weak self] in self?.publishKeyMapping($0.key) == publishKey }
            .map(\.result)
            .eraseToAnyPublisher()
        do {
            if let key = currentKey[publishKey], let current = try await store.get(key: key) {
                // Prepend the current value to the sequence.
                return Publishers.Merge(Just(.success(current)), publisher)
                    .eraseToAnyPublisher()
            } else {
                return publisher.eraseToAnyPublisher()
            }
        } catch {
            // Prepend the error to the sequence.
            return Publishers.Merge(Just(.failure(error)), publisher)
                .eraseToAnyPublisher()
        }
    }

    public var publisher: AnyPublisher<StoreResultType, Never> {
        subject
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
    } receiveValue: { @Sendable unmappedResult in
        let unmappedKey = unmappedResult.key
        let unmappedResultValue = unmappedResult.result
        Task { @MainActor [weak self] in
            // TODO: This needs to do proper error handling
            guard let self = self else { return }
            let result = StoreResult(key: self.map(key: unmappedKey), result: unmappedResultValue)
            switch result.result {
            case let .success(value):
                try await self.set(key: result.key, value: value)
            case .failure:
                self.subject.send(result)
            }
        }
        return .unlimited
    } receiveCompletion: { @Sendable _ in
    }

    public func subscriber(keyField: KeyPath<Value, Key>) -> AnySubscriber<Value, Never> {
        AnySubscriber { subscription in
            subscription.request(.unlimited)
        } receiveValue: { value in
            Task { @MainActor [weak self, keyField] in
                guard let self = self else { return }
                let key = value[keyPath: keyField]
                try await self.set(key: self.map(key: key), value: value)
            }
            return .unlimited
        } receiveCompletion: { @Sendable _ in
        }
    }

    public func currentKey(for publishKey: PublishKey) async -> Key? {
        currentKey[publishKey]
    }

    @AsyncLocked
    public func set(currentKey key: Key) async {
        let mappedKey = map(key: key)
        // Nothing to do here if the key doesn't exist in the store. We explicitly do not check if the incoming
        // key is equal to the current key because if has been a query error, we need to publish the value again
        // in order to clear the error.
        do {
            let value = try await store.get(key: mappedKey)
            // There are no new values being stored, so there is no need to write to store.
            if let value = value {
                currentKey[publishKeyMapping(mappedKey)] = mappedKey
                subject.send(StoreResult(key: mappedKey, result: .success(value)))
            }
        } catch {
            subject.send(StoreResult(key: mappedKey, result: .failure(error)))
        }
    }

    public func map(key: Key) -> Key {
        let mappedKey = keyMapping(key)
        return additionalKeyMappings[mappedKey] ?? mappedKey
    }

    public func addMapping(from unmappedFromKey: Key, to unmappedToKey: Key) {
        let fromKey = map(key: unmappedFromKey)
        let toKey = map(key: unmappedToKey)
        guard fromKey != toKey else { return }
        additionalKeyMappings[fromKey] = toKey
    }

    public func keys(for publishKey: PublishKey) throws -> [Key] {
        try keys.filter { publishKey == publishKeyMapping($0) }
    }

    @AsyncLocked
    public func evict(for key: Key, ifOlderThan: TimeInterval) async throws {
        guard let ageOf = try await store.age(of: key) else { return }
        if ageOf > ifOlderThan {
            try await store.set(key: key, value: nil)
        }
    }

    @AsyncLocked
    public func mutate(publishKey: PublishKey, mutation: (Key, Value) -> Value?) async throws {
        let timestamp = Date().timeIntervalSince1970
        for key in try keys(for: publishKey) {
            let elapsedTime = Date().timeIntervalSince1970 - timestamp
            guard let value = try await store.get(key: key),
                  (try await store.age(of: key) ?? TimeInterval.greatestFiniteMagnitude) > elapsedTime,
                  let mutatedValue = mutation(key, value) else { continue }
            switch currentKey[publishKey] == key {
            case true:
                // For current key, update and publish
                let updatedValue = try await store.set(key: key, value: mutatedValue)
                if let updatedValue = updatedValue {
                    subject.send(StoreResult(key: key, result: .success(updatedValue)))
                }
                let change = ObservableStoreChange.update(updatedValue ?? mutatedValue, previous: value)
                changeSubject.send((key, change))
            case false:
                try await store.set(key: key, value: mutatedValue)
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

    private var store: any Store<Key, Value>
    private let publishKeyMapping: PublishKeyMapping
    private let keyMapping: KeyMapping
    private var additionalKeyMappings: [Key: Key] = [:]
    private let subject = PassthroughSubject<StoreResultType, Never>()
    private let changeSubject = PassthroughSubject<(key: Key, value: ObservableStoreChange<Value>), Never>()
    private var currentKey: [PublishKey: Key] = [:]

    // MARK: - Helpers
}
