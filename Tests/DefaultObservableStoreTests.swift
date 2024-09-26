////
////  Created by Timothy Moose on 5/30/22.
////  Copyright © 2022 ZenBusiness PBC. All rights reserved.
////
//
//import Combine
//import XCTest
//@testable import SwiftRepo
//
//class DefaultObservableStoreTests: XCTestCase {
//
//    // MARK: - API
//
//    // MARK: - Constants
//
//    private typealias ItemStoreMock = ObservableStoreMock<String, String, Item>
//    private typealias ItemArrayStoreMock = ObservableStoreMock<String, String, [Item]>
//
//    private struct Item: Hashable, HasMutatedAt {
//        var id: String
//        var value = ""
//        var createdAt = Date(timeIntervalSinceNow: -1)
//        var updatedAt: Date?
//    }
//
//    private typealias ResultType = Result<String, TestError>
//    private typealias StoreResultType = StoreResult<String, String, Error>
//
//    // MARK: - Variables
//
//    // MARK: - Lifecycle
//
//    // MARK: - Tests
//
//    func testGet() async {
//        let key = "1"
//        let valueA = "a"
//        let valueB = "b"
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
//        await store.set(key: key, value: valueA)
//        let getA = await store.get(key: key)
//        XCTAssertEqual(getA, valueA)
//        await store.set(key: key, value: valueB)
//        let getB = await store.get(key: key)
//        XCTAssertEqual(getB, valueB)
//    }
//
//    func testReset() async {
//        let key = "1"
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
//        await store.set(key: key, value: key)
//        await store.clear()
//        let get = await store.get(key: key)
//        XCTAssertNil(get)
//    }
//
//    func testKeyPathSubscriber() async throws {
//        let key = "1"
//        let item = Item(id: key)
//        let store = DefaultObservableStore<String, String, Item>(store: DictionaryStore())
//        let subscriber = store.subscriber(keyField: \.id)
//        _ = subscriber.receive(item)
//        try await Task.sleep(for: .seconds(0.1))
//        let get = await store.get(key: key)
//        XCTAssertEqual(get, item)
//    }
//
//    func testSubscriber() async throws {
//        let key1 = "key1"
//        let key2 = "key2"
//        let idSuccess1 = StoreResultType(key: key1, success: key1)
//        let idFailure1 = StoreResultType(key: key1, failure: TestError(category: .failure))
//        let idSuccess2 = StoreResultType(key: key2, success: key2)
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
//        let spy = PublisherSpy<ResultType>(await store.publisher(for: key1).testErrorFilter())
//        _ = store.subscriber.receive(idSuccess1)
//        // Pause briefly to avoid race conditions
//        try await Task.sleep(for: .seconds(0.025))
//        _ = store.subscriber.receive(idFailure1)
//        // Pause briefly to avoid race conditions
//        try await Task.sleep(for: .seconds(0.025))
//        _ = store.subscriber.receive(idSuccess2)
//        try await Task.sleep(for: .seconds(0.1))
//        let get = await store.get(key: key1)
//        XCTAssertEqual(get, key1)
//        let success1 = ResultType.success(key1)
//        let failure1 = ResultType.failure(TestError(category: .failure))
//        assertPublished([success1, failure1], spy: spy)
//    }
//
//    func testPublisher() async throws {
//        let key = "1"
//        let valueA = "a"
//        let valueB = "b"
//        let valueC = "c"
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
//        let spy1 = PublisherSpy<ResultType>(await store.publisher(for: key).testErrorFilter())
//        await store.set(key: key, value: valueA)
//        await store.set(key: "asdasd", value: valueB)
//        // There's a different code path if we get publisher while there are existing values in the store.
//        let spy2 = PublisherSpy<ResultType>(await store.publisher(for: key).testErrorFilter())
//        await store.set(key: key, value: valueC)
//        let successA = ResultType.success(valueA)
//        let successC = ResultType.success(valueC)
//        try await Task.sleep(for: .seconds(0.025))
//        assertPublished([successA, successC], spy: spy1)
//        assertPublished([successA, successC], spy: spy2)
//    }
//
//    func testChangePublisher() async {
//        let key = "1"
//        let valueA = "a"
//        let valueB = "b"
//        let valueC = "c"
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore())
//        let spy = PublisherSpy<ObservableStoreChange<String>>(store.changePublisher(for: key))
//        await store.set(key: key, value: valueA)
//        await store.set(key: "asdasd", value: valueB)
//        await store.set(key: key, value: valueC)
//        await store.set(key: key, value: nil)
//        assertPublished(
//            [
//                .add(valueA),
//                .update(valueC, previous: valueA),
//                .delete(valueC),
//            ],
//            spy: spy
//        )
//    }
//
//    func test_setStore_currentKeyIsCorrect() async {
//        let keyA = "keyA"
//        let keyB = "keyB"
//        let publishKey = "publishKey"
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { _ in publishKey }
//        do {
//            await store.set(key: keyA, value: keyA)
//            let currentKey = await store.currentKey(for: publishKey)
//            XCTAssertEqual(currentKey, keyA)
//        }
//        do {
//            await store.set(key: keyB, value: keyB)
//            let currentKey = await store.currentKey(for: publishKey)
//            XCTAssertEqual(currentKey, keyB)
//        }
//    }
//
//    func test_keysForPublishKey_returnsKeys() async {
//        let key1A = "key1A"
//        let key1B = "key1B"
//        let key2 = "key2"
//        let publishKey1 = "publishKey1"
//        let publishKey2 = "publishKey2"
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
//            switch key {
//            case key1A, key1B: return publishKey1
//            case key2: return publishKey2
//            default: fatalError("Not gonna happen")
//            }
//        }
//        await store.set(key: key1A, value: key1A)
//        await store.set(key: key1B, value: key1B)
//        await store.set(key: key2, value: key2)
//        let keys = await store.keys(for: publishKey1)
//        XCTAssertEqual(keys.sorted(), [key1A, key1B].sorted())
//    }
//
//    func test_clearForPublishKey_clearsKeys() async {
//        let key1A = "key1A"
//        let key1B = "key1B"
//        let key2 = "key2"
//        let publishKey1 = "publishKey1"
//        let publishKey2 = "publishKey2"
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
//            switch key {
//            case key1A, key1B: return publishKey1
//            case key2: return publishKey2
//            default: fatalError("Not gonna happen")
//            }
//        }
//        await store.set(key: key1A, value: key1A)
//        await store.set(key: key1B, value: key1B)
//        await store.set(key: key2, value: key2)
//        await store.clear(publishKey: publishKey1)
//        let value1A = await store.get(key: key1A)
//        let value1B = await store.get(key: key1B)
//        let value2 = await store.get(key: key2)
//        XCTAssertNil(value1A)
//        XCTAssertNil(value1B)
//        XCTAssertEqual(value2, key2)
//    }
//
//    func test_setCurrentKey_publishesValueAssociatedWithTheNewCurrentKey() async throws {
//        let keyA1 = "keyA1"
//        let keyA2 = "keyA2"
//        let keyB1 = "keyB1"
//        let publishKeyA = "publishKeyA"
//        let publishKeyB = "publishKeyB"
//        let successA1 = ResultType.success(keyA1)
//        let successA2 = ResultType.success(keyA2)
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
//            switch key {
//            case keyA1, keyA2: return publishKeyA
//            case keyB1: return publishKeyB
//            default: fatalError("Not gonna happen")
//            }
//        }
//        let spy = PublisherSpy<ResultType>(await store.publisher(for: publishKeyA).testErrorFilter())
//        do {
//            await store.set(key: keyA1, value: keyA1)
//            await store.set(key: keyB1, value: keyB1)
//            // This is the current key, so the value should be published.
//            await store.set(currentKey: keyA1)
//            // This should have no effect since this key is not in the store
//            await store.set(currentKey: keyA2)
//            try await Task.sleep(for: .seconds(0.025))
//            assertPublished([successA1, successA1], spy: spy)
//        }
//        do {
//            await store.set(key: keyA2, value: keyA2)
//            let currentKey1 = await store.currentKey(for: publishKeyA)
//            await store.set(currentKey: keyA1)
//            let currentKey2 = await store.currentKey(for: publishKeyA)
//            try await Task.sleep(for: .seconds(0.025))
//            XCTAssertEqual(currentKey1, keyA2)
//            XCTAssertEqual(currentKey2, keyA1)
//            assertPublished([successA1, successA1, successA2, successA1], spy: spy)
//        }
//    }
//
//    func test_mutateStore_updatesAllCachedValues() async {
//        let keyA1 = "keyA1"
//        let keyA2 = "keyA2"
//        let keyB1 = "keyB1"
//        let publishKeyA = "publishKeyA"
//        let publishKeyB = "publishKeyB"
//        let successA1 = ResultType.success(keyA1)
//        let successA2 = ResultType.success(keyA2)
//        let successA2A2 = ResultType.success(keyA2 + keyA2)
//        let successB1 = ResultType.success(keyB1)
//        let store = DefaultObservableStore<String, String, String>(store: DictionaryStore()) { key in
//            switch key {
//            case keyA1, keyA2: return publishKeyA
//            case keyB1: return publishKeyB
//            default: fatalError("Not gonna happen")
//            }
//        }
//        let spyA = PublisherSpy<ResultType>(await store.publisher(for: publishKeyA).testErrorFilter())
//        let spyB = PublisherSpy<ResultType>(await store.publisher(for: publishKeyB).testErrorFilter())
//        await store.set(key: keyA1, value: keyA1)
//        await store.set(key: keyA2, value: keyA2)
//        await store.set(key: keyB1, value: keyB1)
//        await store.mutate(publishKey: publishKeyA) { _, value in
//            value + value
//        }
//        assertPublished([successA1, successA2, successA2A2], spy: spyA)
//        assertPublished([successB1], spy: spyB)
//        let valueA1 = await store.get(key: keyA1)
//        XCTAssertEqual(valueA1, keyA1 + keyA1)
//    }
//
//    func test_newValueSubscriber_acceptsNewerValue() async throws {
//        let id = "1"
//        let item = Item(id: id)
//        let store: ItemStoreMock = mock(ObservableStore.self)
//        given(store.get(key: id)).willReturn(item)
//        let newerItem = Item(id: id, value: "different", updatedAt: Date())
//        let publisher = Just(newerItem)
//        publisher.receive(subscriber: store.newValueSubscriber(keyField: \.id))
//        try await Task.sleep(for: .seconds(0.1))
//        verify(store.set(key: id, value: any(of: newerItem))).wasCalled()
//    }
//
//    func test_newValueSubscriber_rejectsOlderValue() async throws {
//        let id = "1"
//        let item = Item(id: id, updatedAt: Date())
//        let store: ItemStoreMock = mock(ObservableStore.self)
//        given(store.get(key: id)).willReturn(item)
//        // Same age item should not be placed in the store
//        do {
//            var otherItem = item
//            otherItem.value = "different"
//            let publisher = Just(otherItem)
//            publisher.receive(subscriber: store.newValueSubscriber(keyField: \.id))
//            try await Task.sleep(for: .seconds(0.1))
//            verify(store.set(key: id, value: any())).wasNeverCalled()
//        }
//        // Older item should not be placed in the store
//        do {
//            var otherItem = item
//            otherItem.value = "different"
//            otherItem.updatedAt = Date(timeIntervalSinceNow: -1)
//            let publisher = Just(otherItem)
//            publisher.receive(subscriber: store.newValueSubscriber(keyField: \.id))
//            try await Task.sleep(for: .seconds(0.1))
//            verify(store.set(key: id, value: any())).wasNeverCalled()
//        }
//    }
//
//}
//
//private extension Publisher where Output == Result<String, Error>, Failure == Never {
//    /// Filters result to `GraphQLClientError` concrete error type required for publisher spy
//    func testErrorFilter() -> AnyPublisher<Result<String, TestError>, Never> {
//        errorFilter(errorType: TestError.self)
//    }
//
//    func errorFilter<ErrorType: Error>(errorType _: ErrorType.Type) -> AnyPublisher<Result<String, ErrorType>, Never> {
//        compactMap {
//            switch $0 {
//            case let .success(value): return .success(value)
//            case let .failure(error as ErrorType): return .failure(error)
//            default: return nil
//            }
//        }
//        .eraseToAnyPublisher()
//    }
//}
