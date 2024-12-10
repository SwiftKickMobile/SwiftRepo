//
//  PersistentStore.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/2/24.
//

import Foundation
import SwiftData

/// A persistent `Store` implementation implementation using `SwiftData`.
public class PersistentStore<Key: Codable & Hashable, Value: Codable>: Store {
    
    public var keys: [Key] {
        get throws {
            try modelContext.fetch(FetchDescriptor<TimestampedValue>()).compactMap {
                guard let key = try? decoder.decode(Key.self, from: $0.id) else {
                    try? evict(for: $0.id)
                    return nil
                }
                return key
            }
        }
    }
    
    public init(
        id: String,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        let storeName: String = "PersistentStore-\(id)"
        self.modelContainer = try! ModelContainer(
            for: TimestampedValue.self,
            configurations: .init(storeName)
        )
        self.encoder = encoder
        self.decoder = decoder
    }
    
    @MainActor
    public func get(key: Key) throws -> Value? {
        let keyData = try encoder.encode(key)
        guard let valueData = try modelContext.fetch(
            FetchDescriptor(predicate: TimestampedValue.predicate(key: keyData))
        ).first else { return nil }
        return try decoder.decode(Value.self, from: valueData.value)
    }
    
    @discardableResult
    @MainActor
    public func set(key: Key, value: Value?) throws -> Value? {
        if let value {
            try modelContext.insert(TimestampedValue(id: key, value: value, encoder: encoder))
        } else {
            let keyData = try encoder.encode(key)
            try evict(for: keyData)
        }
        // TODO: revisit whether this is actually needed or not. It seems we could rely on auto save
        try modelContext.save()
        return value
    }
    
    @MainActor
    public func age(of key: Key) throws -> TimeInterval? {
        let keyData = try encoder.encode(key)
        let result = try modelContext.fetch(FetchDescriptor(predicate: TimestampedValue.predicate(key: keyData)))
        guard let result = result.first else { return nil }
        return Date.now.timeIntervalSince(result.timestamp)
    }
    
    @MainActor
    public func clear() async throws {
        try modelContext.delete(model: TimestampedValue.self)
        try modelContext.save()
    }
    
    // MARK: - Constants
    
    @Model
    class TimestampedValue: StoreModel {
        #Index<TimestampedValue>([\.id])
        
        @Attribute(.unique)
        var id: Data
        var timestamp = Date()
        var value: Data
        
        init<ID: Codable>(id: ID, value: Value, encoder: JSONEncoder) throws {
            let id: Data = try encoder.encode(id)
            let value: Data = try encoder.encode(value)
            self.id = id
            self.value = value
        }
        
        static func predicate(key: Data) -> Predicate<TimestampedValue> {
            #Predicate<TimestampedValue> { $0.id == key }
        }
    }
    
    // MARK: - Variables
    
    private let modelContainer: ModelContainer
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var _modelContext: ModelContext?
    
    @MainActor
    private var modelContext: ModelContext {
        if let _modelContext {
            return _modelContext
        } else {
            let context = ModelContext(modelContainer)
            _modelContext = context
            return context
        }
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func evict(for keyData: Data) throws {
        try modelContext.delete(model: TimestampedValue.self, where: TimestampedValue.predicate(key: keyData))
        try modelContext.save()
    }
}
