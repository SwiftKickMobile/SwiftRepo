//
//  Created by Timothy Moose on 7/5/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import XCTest
import SwiftRepoCore
import SwiftRepoTest
@testable import SwiftRepo

class DefaultQueryRepositoryTests: XCTestCase {
    // MARK: - Tests

    func test_GetSuccess() async throws {
        let repo = makeIDStoreRepository()
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: id).success())
        delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
            .makeValue(valueA2, delay: 0.1),
        ])
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        XCTAssertEqual(spy.publishedValues, [valueA1])
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 2)
        XCTAssertEqual(spy.publishedValues, [valueA1, valueA1, valueA1, valueA2])
    }
    
    @MainActor
    func test_GetSuccess_ModelResponse() async throws {
        let repo = makeModelResponseStoreRepository(
            delayedValues: DelayedValues<TestModelResponse>(values: [
                .makeValue(responseA),
                .makeValue(responseB)
            ])
        )
        let spy = PublisherSpy(repo.publisher(for: id, setCurrent: id).success())
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        XCTAssertEqual(spy.publishedValues, [responseA.value])
        XCTAssertEqual(try modelStore.get(key: Self.modelAId), responseA.models.first)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 2)
        XCTAssertEqual(spy.publishedValues, [responseA.value, responseA.value, responseA.value, responseB.value])
        XCTAssertEqual(try modelStore.get(key: Self.modelAId), responseA.models.first)
        XCTAssertEqual(try modelStore.get(key: Self.modelBId), responseB.models.first)
        XCTAssertEqual(try modelStore.get(key: Self.modelCId), responseB.models.last)
    }
    
    @MainActor
    func test_GetSuccess_ModelResponse_Trim() async throws {
        let repo = makeModelResponseStoreRepository(
            mergeStrategy: .trim,
            delayedValues: DelayedValues<TestModelResponse>(values: [
                .makeValue(responseA),
                .makeValue(responseB)
            ])
        )
        let spy = PublisherSpy(repo.publisher(for: id, setCurrent: id).success())
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        XCTAssertEqual(spy.publishedValues, [responseA.value])
        XCTAssertEqual(try modelStore.get(key: Self.modelAId), responseA.models.first)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 1)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 2)
        XCTAssertEqual(spy.publishedValues, [responseA.value, responseA.value, responseA.value, responseB.value])
        XCTAssertEqual(try modelStore.get(key: Self.modelAId), nil)
        XCTAssertEqual(try modelStore.get(key: Self.modelBId), responseB.models.first)
        XCTAssertEqual(try modelStore.get(key: Self.modelCId), responseB.models.last)
    }
    
    @MainActor
    func test_GetSuccess_ModelResponse_Merge() async throws {
        let repo = makeModelResponseStoreRepository(
            merge: { existing, new in
                return existing
            },
            delayedValues: DelayedValues<TestModelResponse>(values: [
                .makeValue(responseA),
                .makeValue(responseA1)
            ])
        )
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        XCTAssertEqual(try modelStore.get(key: Self.modelAId), responseA.models.first)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        XCTAssertEqual(try modelStore.get(key: Self.modelAId), responseA.models.first)
    }

    func test_GetError() async throws {
        let repo = makeIDStoreRepository()
        let spy = PublisherSpy<Error>(await repo.publisher(for: id, setCurrent: id).failure())
        delayedValues = DelayedValues<String>(values: [
            .makeError(TestError(category: .failure), delay: 0.1),
        ])
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable) {}
        try await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(spy.publishedValues.compactMap { $0 as? TestError }, [TestError(category: .failure)])
    }
    
    func test_GetError_ModelResponse() async throws {
        let repo = makeModelResponseStoreRepository(
            delayedValues: DelayedValues<TestModelResponse>(values: [
                .makeError(TestError(category: .failure), delay: 0.1),
            ])
        )
        let spy = PublisherSpy<Error>(await repo.publisher(for: id, setCurrent: id).failure())
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable) {}
        try await Task.sleep(for: .seconds(0.1))
        XCTAssertEqual(spy.publishedValues.compactMap { $0 as? TestError }, [TestError(category: .failure)])
    }

    func test_Prefetch() async throws {
        let repo = makeIDStoreRepository()
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: id).success())
        delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
        ])
        await repo.prefetch(queryId: id, variables: id)
        XCTAssertEqual(spy.publishedValues, [valueA1])
    }

    func test_Get_QueryStrategyIsNever() async throws {
        let repo = makeIDStoreRepository(queryStrategy: .never)
        delayedValues = DelayedValues<String>(values: [])
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        XCTAssertEqual(willGetCount, 0)
    }

    func test_GetWithPreviousVariablesAndFreshCache_ReturnsStoreButDoesNotCallService() async throws {
        // Specify a query strategy that ensures the stored values are fresh.
        let repo = makeVariablesStoreRepository(queryStrategy: .ifOlderThan(1))
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA).success())
        delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0),
            .makeValue(valueB1, delay: 0),
        ])
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesB, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        XCTAssertEqual(willGetCount, 2)
        XCTAssertEqual(spy.publishedValues, [valueA1, valueB1, valueA1])
    }

    func test_GetWithPreviousVariablesAndStaleCache_ReturnsStoreThenCallsService() async throws {
        // Specify a query strategy that ensures the stored values are stale.
        let repo = makeVariablesStoreRepository(queryStrategy: .always)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA).success())
        delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0),
            .makeValue(valueB1, delay: 0),
            .makeValue(valueA2, delay: 0),
        ])
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesB, errorIntent: .indispensable, willGet: willGet)
        // Wait long enough for stored values to be stale
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        XCTAssertEqual(willGetCount, 3)
        XCTAssertEqual(spy.publishedValues, [valueA1, valueB1, valueA1, valueA2])
    }

    func test_Get_OverridesDefaultStrategy() async throws {
        let repo = makeVariablesStoreRepository(queryStrategy: .always)
        delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
        ])
        var willGetCount = 0
        let willGet = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, queryStrategy: .never, willGet: willGet)

        XCTAssertEqual(willGetCount, 1)
    }
    
    func test_GetWithErrorIntent() async throws {
        let repo = makeVariablesStoreRepository(queryStrategy: .always)
        delayedValues = DelayedValues<String>(values: [
            .makeError(TestError(category: .failure), delay: 0.1),
            .makeError(TestError(category: .failure), delay: 0.1),
        ])
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA))
        await repo.get(queryId: id, variables: id, errorIntent: .dispensable, willGet: {})
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        try await arbitraryWait()
        XCTAssertTrue((spy.publishedValues.first?.failure as? any AppError)?.intent == .dispensable)
        XCTAssertTrue((spy.publishedValues.last?.failure as? any AppError)?.intent == .indispensable)
    }
    
    func test_valuesWithIdenticalKeysPublish() async throws {
        let repo = makeStoreRepository(queryStrategy: .always)
        delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
            .makeValue(valueA2, delay: 0.1),
        ])
        let loadingController = await LoadingController<String>()
        
        await repo.publisher(for: .unused, setCurrent: .unused)
            .receive(subscriber: loadingController.resultSubscriber)
        
        let spy = PublisherSpy(await repo.publisher(for: .unused, setCurrent: .unused).success())
        let loadingControllerSpy = await PublisherSpy(loadingController.state)
        await repo.get(queryId: .unused, variables: .unused, errorIntent: .dispensable, willGet: {})
        await repo.get(queryId: .unused, variables: .unused, errorIntent: .indispensable, willGet: {})
        try await arbitraryWait()
        XCTAssertEqual(spy.publishedValues, [valueA1, valueA1, valueA2])
        XCTAssertEqual(
            loadingControllerSpy.publishedValues,
            [.loading(isHidden: false), .loaded(valueA1, nil, isUpdating: false),
                .loaded(valueA1, nil, isUpdating: false), .loaded(valueA2, nil, isUpdating: false)]
        )
    }

    // MARK: - Constants

    typealias QueryStoreKeyType = QueryStoreKey<String, String>
    private typealias Model = TestModelResponse.Model
    
    private struct TestModelResponse: ModelResponse {
        var value: String
        var models: [TestStoreModel]
        
        struct TestStoreModel: StoreModel, Equatable {
            var id: UUID
            var updatedAt = Date()
            var value: String
            
            init(id: UUID, value: String = "1") {
                self.id = id
                self.value = value
            }
            
            static func predicate(key: UUID) -> Predicate<DefaultQueryRepositoryTests.TestModelResponse.TestStoreModel> {
                #Predicate { $0.id == key }
            }
        }
    }

    private let id = "id"
    private let variablesA = "variablesA"
    private let variablesB = "variablesB"
    private let valueA1 = "valueA1"
    private let valueA2 = "valueA2"
    private let valueB1 = "valueB1"
    private var keyA: QueryStoreKeyType { QueryStoreKeyType(queryId: id, variables: variablesA) }
    
    private static let modelAId = UUID()
    private static let modelBId = UUID()
    private static let modelCId = UUID()
    
    private let responseA = TestModelResponse(value: "responseA", models: [.init(id: modelAId)])
    private let responseA1 = TestModelResponse(value: "responseA", models: [.init(id: modelAId, value: "2")])
    private let responseB = TestModelResponse(value: "responseB", models: [.init(id: modelBId), .init(id: modelCId)])

    // MARK: - Variables
    
    private var delayedValues: DelayedValues<String>!
    private var modelStore: (any Store<TestModelResponse.Model.Key, TestModelResponse.Model>)!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()
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
    
    /// Makes a repository that stores a single value per unique query ID.
    private func makeStoreRepository(
        queryStrategy: QueryStrategy = .ifOlderThan(0.1)
    ) -> DefaultQueryRepository<Unused, Unused, Unused, String> {
        let observableStore = DefaultObservableStore<Unused, Unused, String>(
            store: DictionaryStore()
        )
        return DefaultQueryRepository(observableStore: observableStore, queryStrategy: queryStrategy) { _ in
            try await self.delayedValues.next()
        }
    }
    
    /// Makes a repository that stores a single value per unique query ID,
    /// and places ModelResponse values in a separate model store.
    private func makeModelResponseStoreRepository(
        mergeStrategy: ModelStoreMergeStrategy = .append,
        merge: @escaping (_ existing: Model, _ new: Model) -> Model = { _, newValue in newValue },
        queryStrategy: QueryStrategy = .ifOlderThan(0.1),
        delayedValues: DelayedValues<TestModelResponse>
    ) -> DefaultQueryRepository<String, String, String, TestModelResponse.Value> {
        self.modelStore = DictionaryStore<TestModelResponse.Model.Key, TestModelResponse.Model>(merge: merge)
        return DefaultQueryRepository<String, String, String, TestModelResponse.Value>(
            observableStore: DefaultObservableStore<String, String, TestModelResponse.Value>(store: DictionaryStore()),
            modelStore: modelStore,
            mergeStrategy: mergeStrategy,
            query: DefaultQuery(queryOperation: { _ in
                try await delayedValues.next()
            }),
            queryStrategy: queryStrategy,
            valueVariablesFactory: nil
        ) { queryId, _ in queryId }
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
    
    /// Waits for a somewhat arbitrary amount of time, giving the publisher a beat to update the state properly.
    /// If tests unexpectedly fail, first try bumping this value up a bit.
    private func arbitraryWait() async throws {
        try await Task.sleep(for: .seconds(0.1))
    }
}
