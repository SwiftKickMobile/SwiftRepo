//
//  SwiftDataStore.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 9/27/24.
//

import Foundation
import Combine
import SwiftData
import SwiftRepoCore

// An implementation of `Store` that uses `SwiftData` under the hood
public class SwiftDataStore<Model: StoreModel>: Store, Saveable where Model: PersistentModel, Model.Key: Hashable & Codable {
    public typealias Key = Model.Key
    public typealias Value = Model
    /// A closure that defines how existing values are merged into new values.
    public typealias Merge = (_ existing: Value, _ into: Value) -> Void
    
    @MainActor
    public var keys: [Key] {
        get throws {
            try modelContext.fetch(FetchDescriptor<Model>()).map { $0.id }
        }
    }
    
    /// Creates a `SwiftData` store based on the provided `ModelContainer`
    /// - Parameter modelContainer: the `ModelContainer` to use when storing `Model`s
    /// - Parameter merge: the optional operation to merge a new value into an existing value
    public init(modelContainer: ModelContainer, merge: Merge?) {
        self.modelContainer = modelContainer
        self.merge = merge
        self.timestampStore = PersistentStore<Key, UUID>(id: String(describing: Model.self))
    }
    
    @MainActor
    public func set(key: Key, value: Value?) throws -> Value? {
        guard let value else {
            try evict(for: key)
            return nil
        }
        
        if let existingValue = try get(key: key), let merge {
            // If the value already has a store id associated with it, don't
            // insert it in the context. This technique is based on a discovery
            // that upserting a single model into a context twice can result in
            // referenced models being unexpectedly deleted. It is unclear whether
            // this is intended behavior or a bug. The store identifier appears
            // to be a good proxy for whether the model has already been upserted.
            if value.persistentModelID.storeIdentifier == nil {
                merge(existingValue, value)
                modelContext.insert(value)
            }
        } else {
            try evict(for: key)
            modelContext.insert(value)
        }
        // Update the timestamp store when values are updated
        try timestampStore.set(key: key, value: UUID())
        return value
    }
    
    @MainActor
    public func get(key: Key) throws -> Value? {
        return try modelContext.fetch(FetchDescriptor(predicate: Value.predicate(key: key))).first
    }
    
    @MainActor
    public func age(of key: Key) throws -> TimeInterval? {
        try timestampStore.age(of: key)
    }
    
    @MainActor
    public func clear() async throws {
        try modelContext.delete(model: Value.self)
        try await timestampStore.clear()
    }
    
    @MainActor
    public func save() throws {
        try modelContext.save()
    }
    
    // MARK: - Constants
    
    // MARK: - Variables
    
    private let modelContainer: ModelContainer
    private let merge: Merge?
    private let timestampStore: PersistentStore<Model.Key, UUID>
    
    @MainActor
    private lazy var modelContext: ModelContext = {
        return modelContainer.mainContext
    }()
    
    // MARK: - Helpers
    
    @MainActor
    private func evict(for key: Key) throws {
        let predicate = Value.predicate(key: key)
        try modelContext.delete(model: Value.self, where: predicate)
        // Clear the timestamp when the value is cleared
        try timestampStore.set(key: key, value: nil)
    }
}
