//
//  Created by Timothy Moose on 7/5/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Testing
import Foundation
import SwiftData
import SwiftRepoCore
import SwiftRepoTest
@testable import SwiftRepo

@MainActor
struct DefaultQueryRepositoryTests {
    // MARK: - Tests

    @Test("Get success with basic repository")
    func getSuccess() async throws {
        let delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
            .makeValue(valueA2, delay: 0.1),
        ])
        let repo = await makeIDStoreRepository(delayedValues: delayedValues)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: id).success())
        
        var willGetCount = 0
        let willGet: @MainActor @Sendable () async -> Void = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 1)
        #expect(spy.publishedValues == [valueA1])
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 1) // Should still be 1 due to caching
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 2)
        #expect(spy.publishedValues == [valueA1, valueA1, valueA1, valueA2])
    }

    @Test("Get success with model response")
    func getSuccessModelResponse() async throws {
        let delayedValues = DelayedValues<TestModelResponse>(values: [
            .makeValue(responseA, delay: 0.1),
            .makeValue(responseB, delay: 0.2),
        ])
        let (repo, modelStore) = await makeModelResponseStoreRepository(delayedValues: delayedValues)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: id).success())

        var willGetCount = 0
        let willGet: @MainActor @Sendable () async -> Void = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 1)
        #expect(spy.publishedValues == [responseA.value])
        let modelAValue = try await modelStore.get(key: Self.modelAId)
        #expect(modelAValue == responseA.models.first)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 1)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 2)
        #expect(spy.publishedValues == [responseA.value, responseA.value, responseA.value, responseB.value])
        let modelAValue2 = try await modelStore.get(key: Self.modelAId)
        #expect(modelAValue2 == responseA.models.first)
        let modelBValue = try await modelStore.get(key: Self.modelBId)
        #expect(modelBValue == responseB.models.first)
        let modelCValue = try await modelStore.get(key: Self.modelCId)
        #expect(modelCValue == responseB.models.last)
    }

    @Test("Get success with model response trim strategy")
    func getSuccessModelResponseTrim() async throws {
        let delayedValues = DelayedValues<TestModelResponse>(values: [
            .makeValue(responseA, delay: 0.1),
            .makeValue(responseB, delay: 0.2),
        ])
        let (repo, modelStore) = await makeModelResponseStoreRepository(
            mergeStrategy: .trim,
            delayedValues: delayedValues
        )
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: id).success())

        var willGetCount = 0
        let willGet: @MainActor @Sendable () async -> Void = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 1)
        #expect(spy.publishedValues == [responseA.value])
        let modelAValue = try await modelStore.get(key: Self.modelAId)
        #expect(modelAValue == responseA.models.first)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 1)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 2)
        #expect(spy.publishedValues == [responseA.value, responseA.value, responseA.value, responseB.value])
        let modelAValueAfter = try await modelStore.get(key: Self.modelAId)
        #expect(modelAValueAfter == nil)
        let modelBValue = try await modelStore.get(key: Self.modelBId)
        #expect(modelBValue == responseB.models.first)
        let modelCValue = try await modelStore.get(key: Self.modelCId)
        #expect(modelCValue == responseB.models.last)
    }

    @Test("Get success with model response merge strategy")
    func getSuccessModelResponseMerge() async throws {
        let delayedValues = DelayedValues<TestModelResponse>(values: [
            .makeValue(responseA, delay: 0.1),
            .makeValue(responseA1, delay: 0.2),
        ])
        let (repo, modelStore) = await makeModelResponseStoreRepository(
            merge: { existing, new in existing },
            delayedValues: delayedValues
        )

        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        let modelAValue = try await modelStore.get(key: Self.modelAId)
        #expect(modelAValue == responseA.models.first)
        try await Task.sleep(for: .seconds(0.1))
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        let modelAValue2 = try await modelStore.get(key: Self.modelAId)
        #expect(modelAValue2 == responseA.models.first)
    }

    @Test("Get error handling")
    func getError() async throws {
        let delayedValues = DelayedValues<String>(values: [
            .makeError(TestError(category: .failure), delay: 0.1),
        ])
        let repo = await makeIDStoreRepository(delayedValues: delayedValues)
        let spy = PublisherSpy<Error>(await repo.publisher(for: id, setCurrent: id).failure())

        await repo.get(queryId: id, variables: id, errorIntent: .indispensable) {}
        try await Task.sleep(for: .seconds(0.1))
        #expect(spy.publishedValues.compactMap { $0 as? TestError } == [TestError(category: .failure)])
    }

    @Test("Get error with model response")
    func getErrorModelResponse() async throws {
        let delayedValues = DelayedValues<TestModelResponse>(values: [
            .makeError(TestError(category: .failure), delay: 0.1),
        ])
        let (repo, _) = await makeModelResponseStoreRepository(delayedValues: delayedValues)
        let spy = PublisherSpy<Error>(await repo.publisher(for: id, setCurrent: id).failure())

        await repo.get(queryId: id, variables: id, errorIntent: .indispensable) {}
        try await Task.sleep(for: .seconds(0.1))
        #expect(spy.publishedValues.compactMap { $0 as? TestError } == [TestError(category: .failure)])
    }

    @Test("Prefetch functionality")
    func prefetch() async throws {
        let delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
        ])
        let repo = await makeIDStoreRepository(delayedValues: delayedValues)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: id).success())

        await repo.prefetch(queryId: id, variables: id)
        #expect(spy.publishedValues == [valueA1])
    }

    @Test("Get with never query strategy")
    func getQueryStrategyIsNever() async throws {
        let delayedValues = DelayedValues<String>(values: [])
        let repo = await makeIDStoreRepository(queryStrategy: .never, delayedValues: delayedValues)

        var willGetCount = 0
        let willGet: @MainActor @Sendable () async -> Void = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        #expect(willGetCount == 0)
    }

    @Test("Get with previous variables and fresh cache")
    func getWithPreviousVariablesAndFreshCache() async throws {
        // Specify a query strategy that ensures the stored values are fresh.
        let delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0),
            .makeValue(valueB1, delay: 0),
        ])
        let repo = await makeVariablesStoreRepository(queryStrategy: .ifOlderThan(1), delayedValues: delayedValues)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA).success())

        var willGetCount = 0
        let willGet: @MainActor @Sendable () async -> Void = { willGetCount += 1 }
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesB, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        #expect(willGetCount == 2)
        #expect(spy.publishedValues == [valueA1, valueB1, valueA1])
    }

    @Test("Get with previous variables and stale cache")
    func getWithPreviousVariablesAndStaleCache() async throws {
        // Specify a query strategy that ensures the stored values are stale.
        let delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0),
            .makeValue(valueB1, delay: 0),
            .makeValue(valueA2, delay: 0),
        ])
        let repo = await makeVariablesStoreRepository(queryStrategy: .always, delayedValues: delayedValues)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA).success())

        var willGetCount = 0
        let willGet: @MainActor @Sendable () async -> Void = { willGetCount += 1 }
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesB, errorIntent: .indispensable, willGet: willGet)
        // Wait long enough for stored values to be stale
        try await Task.sleep(for: .seconds(0.05))
        await repo.get(queryId: id, variables: variablesA, errorIntent: .indispensable, willGet: willGet)
        try await Task.sleep(for: .seconds(0.05))
        #expect(willGetCount == 3)
        #expect(spy.publishedValues == [valueA1, valueB1, valueA1, valueA2])
    }

    @Test("Get overrides default strategy")
    func getOverridesDefaultStrategy() async throws {
        let delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
        ])
        let repo = await makeVariablesStoreRepository(queryStrategy: .always, delayedValues: delayedValues)

        var willGetCount = 0
        let willGet: @MainActor @Sendable () async -> Void = { willGetCount += 1 }
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: willGet)
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, queryStrategy: .never, willGet: willGet)

        #expect(willGetCount == 1)
    }

    @Test("Get with error intent")
    func getWithErrorIntent() async throws {
        let delayedValues = DelayedValues<String>(values: [
            .makeError(TestError(category: .failure), delay: 0.1),
            .makeError(TestError(category: .failure), delay: 0.1),
        ])
        let repo = await makeVariablesStoreRepository(queryStrategy: .always, delayedValues: delayedValues)
        let spy = PublisherSpy(await repo.publisher(for: id, setCurrent: keyA))

        await repo.get(queryId: id, variables: id, errorIntent: .dispensable, willGet: {})
        await repo.get(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        try await arbitraryWait()
        #expect((spy.publishedValues.first?.failure as? any AppError)?.intent == .dispensable)
        #expect((spy.publishedValues.last?.failure as? any AppError)?.intent == .indispensable)
    }

    @Test("Values with identical keys publish")
    func valuesWithIdenticalKeysPublish() async throws {
        let delayedValues = DelayedValues<String>(values: [
            .makeValue(valueA1, delay: 0.1),
            .makeValue(valueA2, delay: 0.1),
        ])
        let repo = await makeStoreRepository(queryStrategy: .always, delayedValues: delayedValues)
        let loadingController = LoadingController<String>()

        await repo.publisher(for: .unused, setCurrent: .unused)
            .receive(subscriber: loadingController.resultSubscriber)

        let spy = PublisherSpy(await repo.publisher(for: .unused, setCurrent: .unused).success())
        let loadingControllerSpy = PublisherSpy(loadingController.state)
        await repo.get(queryId: .unused, variables: .unused, errorIntent: .dispensable, willGet: {})
        await repo.get(queryId: .unused, variables: .unused, errorIntent: .indispensable, willGet: {})
        try await arbitraryWait()
        #expect(spy.publishedValues == [valueA1, valueA1, valueA2])
        #expect(loadingControllerSpy.publishedValues == [
            .loading(isHidden: false),
            .loaded(valueA1, nil, isUpdating: false),
            .loaded(valueA1, nil, isUpdating: false),
            .loaded(valueA2, nil, isUpdating: false)
        ])
    }

    // MARK: - getValue() API Tests

    @Test("getValue success with basic repository")
    func getValueSuccessBasic() async throws {
        let delayedValues = DelayedValues<String>(values: [.makeValue(valueA1, delay: 0)])
        let repo = await makeIDStoreRepository(delayedValues: delayedValues)
        
        let result = try await repo.getValue(
            queryId: id, 
            variables: id, 
            errorIntent: .indispensable,
            willGet: {}
        )
        
        #expect(result == valueA1)
    }

    @Test("getValue error handling") 
    func getValueErrorHandling() async throws {
        let delayedValues = DelayedValues<String>(values: [.makeError(TestError(category: .failure), delay: 0)])
        let repo = await makeIDStoreRepository(delayedValues: delayedValues)
        
        await #expect(throws: TestError.self) {
            try await repo.getValue(
                queryId: id, 
                variables: id, 
                errorIntent: .indispensable,
                willGet: {}
            )
        }
    }

    @Test("getValue with ModelResponse repository")
    func getValueWithModelResponse() async throws {
        let delayedValues = DelayedValues<TestModelResponse>(values: [.makeValue(responseA, delay: 0)])
        let (repo, _) = await makeModelResponseStoreRepository(delayedValues: delayedValues)
        
        let result = try await repo.getValue(
            queryId: id,
            variables: id, 
            errorIntent: .indispensable,
            willGet: {}
        )
        
        #expect(result == responseA.value)
    }

    @Test("getValue returns cached value")
    func getValueReturnsCachedValue() async throws {
        let delayedValues = DelayedValues<String>(values: [.makeValue(valueA1, delay: 0)])
        let repo = await makeIDStoreRepository(queryStrategy: .always, delayedValues: delayedValues)
        
        // First call to populate cache
        _ = try await repo.getValue(queryId: id, variables: id, errorIntent: .indispensable, willGet: {})
        
        // Second call with .never strategy should return cached value without making new query
        let result = try await repo.getValue(
            queryId: id, 
            variables: id, 
            errorIntent: .indispensable, 
            queryStrategy: .never,
            willGet: {}
        )
        
        #expect(result == valueA1)
    }

    // MARK: - Constants

    typealias QueryStoreKeyType = QueryStoreKey<String, String>
    private typealias Model = TestModelResponse.Model

    private struct TestModelResponse: ModelResponse {
        var value: String
        var models: [TestStoreModel]
        
        static func withValue(_ value: String) -> TestModelResponse {
            return TestModelResponse(value: value, models: [])
        }

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

    // MARK: - Helpers

    /// Makes a repository that stores a single value per unique query ID.
    private func makeIDStoreRepository(
        queryStrategy: QueryStrategy = .ifOlderThan(0.1),
        delayedValues: DelayedValues<String>
    ) async -> DefaultQueryRepository<String, String, String, String> {
        let observableStore = DefaultObservableStore<String, String, String>(
            store: DictionaryStore()
        )
        return DefaultQueryRepository(observableStore: observableStore, queryStrategy: queryStrategy) { _ in
            try await delayedValues.next()
        }
    }

    /// Makes a repository that stores a single value per unique query ID.
    private func makeStoreRepository(
        queryStrategy: QueryStrategy = .ifOlderThan(0.1),
        delayedValues: DelayedValues<String>
    ) async -> DefaultQueryRepository<Unused, Unused, Unused, String> {
        let observableStore = DefaultObservableStore<Unused, Unused, String>(
            store: DictionaryStore()
        )
        return DefaultQueryRepository(observableStore: observableStore, queryStrategy: queryStrategy) { _ in
            try await delayedValues.next()
        }
    }

    /// Makes a repository that stores a single value per unique query ID,
    /// and places ModelResponse values in a separate model store.
    private func makeModelResponseStoreRepository(
        mergeStrategy: ModelStoreMergeStrategy = .append,
        merge: @escaping @Sendable (_ existing: TestModelResponse.TestStoreModel, _ new: TestModelResponse.TestStoreModel) -> TestModelResponse.TestStoreModel = { _, newValue in newValue },
        queryStrategy: QueryStrategy = .ifOlderThan(0.1),
        delayedValues: DelayedValues<TestModelResponse>
    ) async -> (DefaultQueryRepository<String, String, String, TestModelResponse.Value>, any Store<UUID, TestModelResponse.TestStoreModel>) {
        let modelStore = DictionaryStore<UUID, TestModelResponse.TestStoreModel>(merge: merge)
        let repo = DefaultQueryRepository<String, String, String, TestModelResponse.Value>(
            observableStore: DefaultObservableStore<String, String, TestModelResponse.Value>(store: DictionaryStore()),
            modelStore: modelStore,
            mergeStrategy: mergeStrategy,
            query: DefaultQuery(queryOperation: { _ in
                try await delayedValues.next()
            }),
            queryStrategy: queryStrategy,
            valueVariablesFactory: nil
        ) { queryId, _ in queryId }
        return (repo, modelStore)
    }

    /// Makes a repository that stores a single value per unique query variable.
    private func makeVariablesStoreRepository(
        queryStrategy: QueryStrategy = .ifOlderThan(0.1),
        delayedValues: DelayedValues<String>
    ) async -> DefaultQueryRepository<String, String, QueryStoreKeyType, String> {
        let observableStore = DefaultObservableStore<QueryStoreKeyType, String, String>(
            store: DictionaryStore()
        )
        return DefaultQueryRepository(observableStore: observableStore, queryStrategy: queryStrategy) { _ in
            try await delayedValues.next()
        }
    }

    /// Waits for a somewhat arbitrary amount of time, giving the publisher a beat to update the state properly.
    /// If tests unexpectedly fail, first try bumping this value up a bit.
    private func arbitraryWait() async throws {
        try await Task.sleep(for: .seconds(0.1))
    }
}
