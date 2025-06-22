//
//  Created by Timothy Moose on 5/30/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

@preconcurrency import Combine
import Foundation
import Testing
import SwiftRepoCore
import SwiftRepoTest
@testable import SwiftRepo

@MainActor
struct DefaultObservableStoreTests {

    // MARK: - Constants

    private struct Item: Hashable, HasMutatedAt {
        var id: String
        var value = ""
        var createdAt = Date(timeIntervalSinceNow: -1)
        var updatedAt: Date?
    }

    private typealias ResultType = Result<String, TestError>
    private typealias StoreResultType = StoreResult<String, String, Error>

    // MARK: - Tests

    @Test("Get operations")
    func get() async throws {
        let key = "1"
        let valueA = "a"
        let valueB = "b"
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
        try await store.set(key: key, value: valueA)
        let getA = try await store.get(key: key)
        #expect(getA == valueA)
        try await store.set(key: key, value: valueB)
        let getB = try await store.get(key: key)
        #expect(getB == valueB)
    }

    @Test("Reset operations")
    func reset() async throws {
        let key = "1"
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
        try await store.set(key: key, value: key)
        try await store.clear()
        let get = try await store.get(key: key)
        #expect(get == nil)
    }

    @Test("KeyPath subscriber")
    func keyPathSubscriber() async throws {
        let key = "1"
        let item = Item(id: key)
        let store = DefaultObservableStore<String, String, Item>(store: DictionaryStore())
        let subscriber = store.subscriber(keyField: \.id)
        _ = subscriber.receive(item)
        try await Task.sleep(for: .seconds(0.1))
        let get = try await store.get(key: key)
        #expect(get == item)
    }

    @Test("Subscriber operations")
    func subscriber() async throws {
        let key1 = "key1"
        let key2 = "key2"
        let idSuccess1 = StoreResultType(key: key1, success: key1)
        let idFailure1 = StoreResultType(key: key1, failure: TestError(category: .failure))
        let idSuccess2 = StoreResultType(key: key2, success: key2)
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
        let spy = PublisherSpy<ResultType>(await store.publisher(for: key1).testErrorFilter())
        _ = store.subscriber.receive(idSuccess1)
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        _ = store.subscriber.receive(idFailure1)
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        _ = store.subscriber.receive(idSuccess2)
        try await Task.sleep(for: .seconds(0.1))
        let get = try await store.get(key: key1)
        #expect(get == key1)
        let success1 = ResultType.success(key1)
        let failure1 = ResultType.failure(TestError(category: .failure))
        try await spy.waitForValues([success1, failure1])
    }

    @Test("Publisher operations")
    func publisher() async throws {
        let key = "1"
        let valueA = "a"
        let valueB = "b"
        let valueC = "c"
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
        let spy1 = PublisherSpy<ResultType>(await store.publisher(for: key).testErrorFilter())
        try await store.set(key: key, value: valueA)
        try await store.set(key: "asdasd", value: valueB)
        // There's a different code path if we get publisher while there are existing values in the store.
        let spy2 = PublisherSpy<ResultType>(await store.publisher(for: key).testErrorFilter())
        try await store.set(key: key, value: valueC)
        let successA = ResultType.success(valueA)
        let successC = ResultType.success(valueC)
        try await Task.sleep(for: .seconds(0.025))
        try await spy1.waitForValues([successA, successC])
        try await spy2.waitForValues([successA, successC])
    }

    @Test("Change publisher operations")
    func changePublisher() async throws {
        let key = "1"
        let valueA = "a"
        let valueB = "b"
        let valueC = "c"
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
        let spy = PublisherSpy<ObservableStoreChange<String>>(store.changePublisher(for: key))
        try await store.set(key: key, value: valueA)
        try await store.set(key: "asdasd", value: valueB)
        try await store.set(key: key, value: valueC)
        try await store.set(key: key, value: nil)
        try await spy.waitForValues([
            .add(valueA),
            .update(valueC, previous: valueA),
            .delete(valueC),
        ])
    }

    @Test("Set store current key is correct")
    func setStoreCurrentKeyIsCorrect() async throws {
        let keyA = "keyA"
        let keyB = "keyB"
        let publishKey = "publishKey"
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { _ in publishKey }
        do {
            try await store.set(key: keyA, value: keyA)
            let currentKey = await store.currentKey(for: publishKey)
            #expect(currentKey == keyA)
        }
        do {
            try await store.set(key: keyB, value: keyB)
            let currentKey = await store.currentKey(for: publishKey)
            #expect(currentKey == keyB)
        }
    }

    @Test("Keys for publish key returns keys")
    func keysForPublishKeyReturnsKeys() async throws {
        let key1A = "key1A"
        let key1B = "key1B"
        let key2 = "key2"
        let publishKey1 = "publishKey1"
        let publishKey2 = "publishKey2"
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
            switch key {
            case key1A, key1B: return publishKey1
            case key2: return publishKey2
            default: fatalError("Not gonna happen")
            }
        }
        try await store.set(key: key1A, value: key1A)
        try await store.set(key: key1B, value: key1B)
        try await store.set(key: key2, value: key2)
        let keys = try store.keys(for: publishKey1)
        #expect(keys.sorted() == [key1A, key1B].sorted())
    }

    @Test("Clear for publish key clears keys")
    func clearForPublishKeyClearsKeys() async throws {
        let key1A = "key1A"
        let key1B = "key1B"
        let key2 = "key2"
        let publishKey1 = "publishKey1"
        let publishKey2 = "publishKey2"
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
            switch key {
            case key1A, key1B: return publishKey1
            case key2: return publishKey2
            default: fatalError("Not gonna happen")
            }
        }
        try await store.set(key: key1A, value: key1A)
        try await store.set(key: key1B, value: key1B)
        try await store.set(key: key2, value: key2)
        try await store.clear(publishKey: publishKey1)
        let value1A = try await store.get(key: key1A)
        let value1B = try await store.get(key: key1B)
        let value2 = try await store.get(key: key2)
        #expect(value1A == nil)
        #expect(value1B == nil)
        #expect(value2 == key2)
    }

    @Test("Set current key publishes value associated with the new current key")
    func setCurrentKeyPublishesValueAssociatedWithTheNewCurrentKey() async throws {
        let keyA1 = "keyA1"
        let keyA2 = "keyA2"
        let keyB1 = "keyB1"
        let publishKeyA = "publishKeyA"
        let publishKeyB = "publishKeyB"
        let successA1 = ResultType.success(keyA1)
        let successA2 = ResultType.success(keyA2)
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
            switch key {
            case keyA1, keyA2: return publishKeyA
            case keyB1: return publishKeyB
            default: fatalError("Not gonna happen")
            }
        }
        let spy = PublisherSpy<ResultType>(await store.publisher(for: publishKeyA).testErrorFilter())
        do {
            try await store.set(key: keyA1, value: keyA1)
            try await store.set(key: keyB1, value: keyB1)
            // This is the current key, so the value should be published.
            await store.set(currentKey: keyA1)
            // This should have no effect since this key is not in the store
            await store.set(currentKey: keyA2)
            try await Task.sleep(for: .seconds(0.025))
            try await spy.waitForValues([successA1, successA1])
        }
        do {
            try await store.set(key: keyA2, value: keyA2)
            let currentKey1 = await store.currentKey(for: publishKeyA)
            await store.set(currentKey: keyA1)
            let currentKey2 = await store.currentKey(for: publishKeyA)
            try await Task.sleep(for: .seconds(0.025))
            #expect(currentKey1 == keyA2)
            #expect(currentKey2 == keyA1)
            try await spy.waitForValues([successA1, successA1, successA2, successA1])
        }
    }

    @Test("Mutate store updates all cached values")
    func mutateStoreUpdatesAllCachedValues() async throws {
        let keyA1 = "keyA1"
        let keyA2 = "keyA2"
        let keyB1 = "keyB1"
        let publishKeyA = "publishKeyA"
        let publishKeyB = "publishKeyB"
        let successA1 = ResultType.success(keyA1)
        let successA2 = ResultType.success(keyA2)
        let successA2A2 = ResultType.success(keyA2 + keyA2)
        let successB1 = ResultType.success(keyB1)
        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
            switch key {
            case keyA1, keyA2: return publishKeyA
            case keyB1: return publishKeyB
            default: fatalError("Not gonna happen")
            }
        }
        let spyA = PublisherSpy<ResultType>(await store.publisher(for: publishKeyA).testErrorFilter())
        let spyB = PublisherSpy<ResultType>(await store.publisher(for: publishKeyB).testErrorFilter())
        try await store.set(key: keyA1, value: keyA1)
        try await store.set(key: keyA2, value: keyA2)
        try await store.set(key: keyB1, value: keyB1)
        try await store.mutate(publishKey: publishKeyA) { _, value in
            value + value
        }
        try await spyA.waitForValues([successA1, successA2, successA2A2])
        try await spyB.waitForValues([successB1])
        let valueA1 = try await store.get(key: keyA1)
        #expect(valueA1 == keyA1 + keyA1)
    }

    @Test("New value subscriber accepts newer value")
    func newValueSubscriberAcceptsNewerValue() async throws {
        let id = "1"
        let item = Item(id: id)
        let store = DefaultObservableStore<String, String, Item>(store: DictionaryStore())
        try await store.set(key: id, value: item)
        let result = try await store.get(key: id)
        #expect(result == item)
        let newerItem = Item(id: id, value: "different", updatedAt: Date())
        let publisher = Just(newerItem)
        publisher.receive(subscriber: store.newValueSubscriber(keyField: \.id))
        try await Task.sleep(for: .seconds(0.1))
        let newResult = try await store.get(key: id)
        #expect(newResult == newerItem)
    }

    @Test("New value subscriber rejects older value")
    func newValueSubscriberRejectsOlderValue() async throws {
        let id = "1"
        let item = Item(id: id, updatedAt: Date())
        let store = DefaultObservableStore<String, String, Item>(store: DictionaryStore())
        try await store.set(key: id, value: item)
        let result = try await store.get(key: id)
        #expect(result == item)
        // Same age item should not be placed in the store
        do {
            var otherItem = item
            otherItem.value = "different"
            let publisher = Just(otherItem)
            publisher.receive(subscriber: store.newValueSubscriber(keyField: \.id))
            try await Task.sleep(for: .seconds(0.1))
            let result = try await store.get(key: id)
            #expect(result == item)
        }
        // Older item should not be placed in the store
        do {
            var otherItem = item
            otherItem.value = "different"
            otherItem.updatedAt = Date(timeIntervalSinceNow: -1)
            let publisher = Just(otherItem)
            publisher.receive(subscriber: store.newValueSubscriber(keyField: \.id))
            try await Task.sleep(for: .seconds(0.1))
            let result = try await store.get(key: id)
            #expect(result == item)
        }
    }
}

private extension Publisher where Output == Result<String, Error>, Failure == Never {
    /// Filters result to `GraphQLClientError` concrete error type required for publisher spy
    func testErrorFilter() -> AnyPublisher<Result<String, TestError>, Never> {
        errorFilter(errorType: TestError.self)
    }

    func errorFilter<ErrorType: Error>(errorType _: ErrorType.Type) -> AnyPublisher<Result<String, ErrorType>, Never> {
        compactMap {
            switch $0 {
            case let .success(value): return .success(value)
            case let .failure(error as ErrorType): return .failure(error)
            default: return nil
            }
        }
        .eraseToAnyPublisher()
    }
}
