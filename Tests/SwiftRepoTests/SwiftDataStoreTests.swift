//
//  SwiftDataStoreTests.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/2/24.
//

import Foundation
import Testing
import SwiftData
@testable import SwiftRepo

@MainActor
struct SwiftDataStoreTests {
    
    // MARK: - Tests
    
    @Test("Merge functionality")
    func merge() async throws {
        let store = makeStore()
        let uuid = UUID()
        let model = TestStoreModel(id: uuid)
        _ = try store.set(key: model.id, value: model)
        let stored = try store.get(key: model.id)
        
        let model2 = TestStoreModel(id: uuid)
        _ = try store.set(key: model.id, value: model2)
        #expect(stored?.updatedAt == model2.updatedAt)
    }
    
    @Test("Timestamp functionality")
    func timestamp() async throws {
        let store = makeStore()
        let uuid = UUID()
        let model = TestStoreModel(id: uuid)
        _ = try store.set(key: model.id, value: model)
        
        let updatedAt = try await store.age(of: uuid)
        #expect(updatedAt != nil)
        
        let model2 = TestStoreModel(id: uuid)
        _ = try store.set(key: model.id, value: model2)
        let updatedAt2 = try await store.age(of: uuid)
        #expect(updatedAt2 != nil)
        #expect(updatedAt != updatedAt2)
    }

    // MARK: - Constants
    
    @Model
    final class TestStoreModel: StoreModel, Equatable {
        var id: UUID
        var updatedAt = Date()
        
        public init(id: UUID, updatedAt: Date = Date()) {
            self.id = id
            self.updatedAt = updatedAt
        }
        
        static func predicate(key: UUID) -> Predicate<TestStoreModel> {
            #Predicate<TestStoreModel> {
                $0.id == key
            }
        }
    }

    // MARK: - Helpers

    private func makeStore() -> SwiftDataStore<TestStoreModel> {
        let modelContainer = try! ModelContainer(
            for: TestStoreModel.self,
            configurations: .init("TestStore", isStoredInMemoryOnly: true)
        )
        return SwiftDataStore(modelContainer: modelContainer) { existing, into in
            into.updatedAt = existing.updatedAt
        }
    }
}
