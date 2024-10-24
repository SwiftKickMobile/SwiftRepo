//
//  SwiftDataStoreTests.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/2/24.
//

import XCTest
import SwiftData
@testable import SwiftRepo

@MainActor
class SwiftDataStoreTests: XCTestCase {
    
    // MARK: - Tests
    
    func test_merge() async throws {
        let store = makeStore()
        let uuid = UUID()
        let model = TestStoreModel(id: uuid)
        let _ = try store.set(key: model.id, value: model)
        let stored = try store.get(key: model.id)
        XCTAssertTrue(stored?.merged == false)
        
        let model2 = TestStoreModel(id: uuid)
        let _ = try store.set(key: model.id, value: model2)
        XCTAssertTrue(stored?.merged == true && stored?.updatedAt == model2.updatedAt)
    }
    
    func test_timestamp() async throws {
        let store = makeStore()
        let uuid = UUID()
        let model = TestStoreModel(id: uuid)
        let _ = try store.set(key: model.id, value: model)
        let stored = try store.get(key: model.id)
        XCTAssertTrue(stored?.merged == false)
        
        let updatedAt = try store.age(of: uuid)
        XCTAssertNotNil(updatedAt)
        
        let model2 = TestStoreModel(id: uuid)
        let _ = try store.set(key: model.id, value: model2)
        let updatedAt2 = try store.age(of: uuid)
        XCTAssertNotNil(updatedAt2)
        XCTAssertNotEqual(updatedAt, updatedAt2)
    }

    // MARK: - Constants
    
    @Model
    final class TestStoreModel: StoreModel, Equatable {
        var id: UUID
        var merged = false
        var updatedAt = Date()
        
        public init(id: UUID, updatedAt: Date = Date()) {
            self.id = id
            self.updatedAt = updatedAt
        }
    }

    // MARK: - Variables

    // MARK: - Lifecycle

    // MARK: - Helpers

    private func makeStore() -> SwiftDataStore<TestStoreModel> {
        let modelContainer = try! ModelContainer(
            for: TestStoreModel.self,
            configurations: .init("TestStore", isStoredInMemoryOnly: true)
        )
        return SwiftDataStore(modelContainer: modelContainer) { new, into in 
            into.merged = true
            into.updatedAt = new.updatedAt
        }
    }
}
