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
public class SwiftDataStore<Model: StoreModel>: Store where Model: PersistentModel, Model.Key: Hashable & Codable {
    public typealias Key = Model.Key
    public typealias Value = Model
    /// A closure that defines how new values are merged into existing values.
    public typealias Merge = (_ new: Value, _ into: Value) -> Void
    
    public var keys: [Key] {
        get throws {
            try modelContext.fetch(FetchDescriptor<Model>()).map { $0.id }
        }
    }
    
    /// Creates a `SwiftData` store based on the provided `ModelContainer`
    /// - Parameter modelContainer: the `ModelContainer` to use when storing `Model`s
    /// - Parameter merge: the optional operation to merge a new value into an existing value
    public init(modelContainer: ModelContainer, merge: Merge?) {
        self.modelContext = ModelContext(modelContainer)
        self.merge = merge
        self.timestampStore = TimestampStore(url: modelContainer.configurations.first?.url, modelType: Model.self)
    }
    
    public func set(key: Key, value: Value?) throws -> Value? {
        guard let value else {
            try evict(for: key)
            return nil
        }
        
        if let existingValue = try get(key: key), let merge {
            // If the store contains an existing value for this key,
            // merge the two as necessary and save the resulting value.
            merge(value, existingValue)
        } else {
            try evict(for: key)
            modelContext.insert(value)
        }
        try modelContext.save()
        // Update the timestamp store when values are updated
        try timestampStore.set(key: key, value: Date())
        return value
    }
    
    public func get(key: Key) throws -> Value? {
        return try modelContext.fetch(FetchDescriptor(predicate: Value.predicate(key: key))).first
    }
    
    public func age(of key: Key) throws -> TimeInterval? {
        guard let updatedAt = try timestampStore.get(key: key) else { return nil }
        return Date.now.timeIntervalSince(updatedAt)
    }
    
    public func clear() async throws {
        try modelContext.delete(model: Value.self)
        try modelContext.save()
    }
    
    // MARK: - Constants
    
    // MARK: - Variables
    
    private let modelContext: ModelContext
    private let merge: Merge?
    private let timestampStore: TimestampStore<Model.Key>
    
    // MARK: - Helpers
    
    private func evict(for key: Key) throws {
        let predicate = Value.predicate(key: key)
        try modelContext.delete(model: Value.self, where: predicate)
        try modelContext.save()
        // Clear the timestamp when the value is cleared
        try timestampStore.set(key: key, value: nil)
    }
}
