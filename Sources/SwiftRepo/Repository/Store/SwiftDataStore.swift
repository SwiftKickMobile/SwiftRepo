//
//  SwiftDataStore.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 9/27/24.
//

import Foundation
import Combine
import SwiftData
import Core

@MainActor
// An implementation of `Store` that uses `SwiftData` under the hood
public class SwiftDataStore<Model: StoreModel>: Store where Model: PersistentModel, Model.Key: Hashable {
    public typealias Key = Model.Key
    public typealias Value = Model
    
    public var keys: [Key] {
        get throws {
            try modelContext.fetch(FetchDescriptor<Model>()).map { $0.id }
        }
    }
    
    /// Creates a `SwiftData` store based on the provided `ModelContainer`
    /// - Parameter modelContainer: the `ModelContainer` to use when storing `Model`s
    public init(modelContainer: ModelContainer) {
        self.modelContext = ModelContext(modelContainer)
    }
    
    public func set(key: Key, value: Value?) throws -> Value? {
        guard let value else {
            try evict(for: key)
            return nil
        }
        
        if let existingValue = try get(key: key) {
            // If the store contains an existing value for this key,
            // merge the two as necessary and save the resulting value.
            let mergedValue = Value.merge(existing: existingValue, new: value)
            try evict(for: key)
            modelContext.insert(mergedValue)
        } else {
            modelContext.insert(value)
        }
        try modelContext.save()
        return value
    }
    
    public func get(key: Key) throws -> Value? {
        let result = try modelContext.fetch(FetchDescriptor(predicate: Value.predicate(key: key, olderThan: nil)))
        return result.first
    }
    
    public func age(of key: Key) throws -> TimeInterval? {
        let result = try modelContext.fetch(FetchDescriptor(predicate: Value.predicate(key: key, olderThan: nil)))
        guard let result = result.first else { return nil }
        return Date.now.timeIntervalSince(result.updatedAt)
    }
    
    public func clear() async throws {
        try modelContext.delete(model: Value.self)
        try modelContext.save()
    }
    
    // MARK: - Constants
    
    // MARK: - Variables
    
    private let modelContext: ModelContext
    
    // MARK: - Helpers
    
    private func evict(for key: Key) throws {
        let predicate = Value.predicate(key: key, olderThan: nil)
        try modelContext.delete(model: Value.self, where: predicate)
        try modelContext.save()
    }
}
