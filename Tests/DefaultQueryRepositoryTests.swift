//
//  Created by Timothy Moose on 7/5/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import XCTest
import Mockingbird
@testable import SwiftRepo

class DefaultQueryRepositoryTests: XCTestCase {
    // MARK: - Tests

    func testGetSuccess() async throws {
        let repo = makeIDStoreRepository()
        let spy = PublisherSpy(await repo.publisher(for: id).success())
        delayedValues.values = [
            .makeValue(valueA1, delay: 0.1),
            .makeValue(valueA2, delay: 0.1),
        ]
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        XCTAssertEqual(spy.publishedValues, [valueA1])
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: id, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, willGet: willGet)
        XCTAssertEqual(willGetCount, 2)
        XCTAssertEqual(spy.publishedValues, [valueA1, valueA1, valueA1, valueA2])
    }

    func testGetError() async throws {
        let repo = makeIDStoreRepository()
        let spy = PublisherSpy<Error>(await repo.publisher(for: id).failure())
        delayedValues.values = [
            .makeError(TestError(category: .failure), delay: 0.1),
        ]
        await repo.get(queryId: id, variables: id) {}
        try await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(spy.publishedValues.compactMap { $0 as? TestError }, [TestError(category: .failure)])
    }

    func testPrefetch() async throws {
        let repo = makeIDStoreRepository()
        let spy = PublisherSpy(await repo.publisher(for: id).success())
        delayedValues.values = [
            .makeValue(valueA1, delay: 0.1),
        ]
        await repo.prefetch(queryId: id, variables: id)
        XCTAssertEqual(spy.publishedValues, [valueA1])
    }

    func test_Get_QueryStrategyIsNever() async {
        let repo = makeIDStoreRepository(queryStrategy: .never)
        delayedValues.values = []
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, willGet: willGet)
        XCTAssertEqual(willGetCount, 0)
    }

    func test_GetWithPreviousVariablesAndFreshCache_ReturnsStoreButDoesNotCallService() async throws {
        // Specify a query strategy that ensures the stored values are fresh.
        let repo = makeVariablesStoreRepository(queryStrategy: .ifOlderThan(1))
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA).success())
        delayedValues.values = [
            .makeValue(valueA1, delay: 0),
            .makeValue(valueB1, delay: 0),
        ]
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: variablesA, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesB, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesA, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        XCTAssertEqual(willGetCount, 2)
        XCTAssertEqual(spy.publishedValues, [valueA1, valueB1, valueA1])
    }

    func test_GetWithPreviousVariablesAndStaleCache_ReturnsStoreThenCallsService() async throws {
        // Specify a query strategy that ensures the stored values are stale.
        let repo = makeVariablesStoreRepository(queryStrategy: .always)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA).success())
        delayedValues.values = [
            .makeValue(valueA1, delay: 0),
            .makeValue(valueB1, delay: 0),
            .makeValue(valueA2, delay: 0),
        ]
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: variablesA, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesB, willGet: willGet)
        // Wait long enough for stored values to be stale
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesA, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        XCTAssertEqual(willGetCount, 3)
        XCTAssertEqual(spy.publishedValues, [valueA1, valueB1, valueA1, valueA2])
    }

    func test_Get_OverridesDefaultStrategy() async {
        let repo = makeVariablesStoreRepository(queryStrategy: .always)
        delayedValues.values = [
            .makeValue(valueA1, delay: 0.1),
        ]
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, willGet: willGet)
        await repo.get(queryId: id, variables: id, queryStrategy: .never, willGet: willGet)

        XCTAssertEqual(willGetCount, 1)
    }
    
    func test_GetWithErrorIntent() async {
        let repo = makeVariablesStoreRepository(queryStrategy: .always)
        delayedValues.values = [
            .makeError(TestError(category: .failure), delay: 0.1),
            .makeError(TestError(category: .failure), delay: 0.1),
        ]
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA))
        await repo.get(queryId: id, variables: id, errorIntent: .dispensable, willGet: {})
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        
        XCTAssertTrue((spy.publishedValues.first?.failure as? any AppError)?.intent == .dispensable)
        XCTAssertTrue((spy.publishedValues.last?.failure as? any AppError)?.intent == .indispensable)
    }

    // MARK: - Constants

    typealias QueryStoreKeyType = QueryStoreKey<String, String>

    private let id = "id"
    private let variablesA = "variablesA"
    private let variablesB = "variablesB"
    private let valueA1 = "valueA1"
    private let valueA2 = "valueA2"
    private let valueB1 = "valueB1"
    private var keyA: QueryStoreKeyType { QueryStoreKeyType(queryId: id, variables: variablesA) }

    // MARK: - Variables

    private let delayedValues = DelayedValues<String>(values: [])

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
        delayedValues.values = []
    }

    // MARK: - Helpers

    /// Makes a repository that stores a single value per unique query ID.
    private func makeIDStoreRepository(
        queryStrategy: QueryStrategy = .ifOlderThan(0.1)
    ) -> DefaultQueryRepository<String, String, String, String> {
        let observableStore = DefaultObservableStore<String, String, String>(
            store: DictionaryStore()
        )
        return DefaultQueryRepository(observableStore: observableStore, queryStrategy: queryStrategy) { _ in
            try await self.delayedValues.next()
        }
    }

    /// Makes a repository that stores a single value per unique query variable.
    private func makeVariablesStoreRepository(
        queryStrategy: QueryStrategy = .ifOlderThan(0.1)
    ) -> DefaultQueryRepository<String, String, QueryStoreKeyType, String> {
        let observableStore = DefaultObservableStore<QueryStoreKeyType, String, String>(
            store: DictionaryStore()
        )
        return DefaultQueryRepository(observableStore: observableStore, queryStrategy: queryStrategy) { _ in
            try await self.delayedValues.next()
        }
    }
}
