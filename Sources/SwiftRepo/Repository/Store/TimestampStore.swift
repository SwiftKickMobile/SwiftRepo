//
//  TimestampStore.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/2/24.
//

import Foundation
import SwiftData

/// A persistent `Store` implementation implementation using `SwiftData`.
class PersistentStore<Key: Codable & Hashable, Value: Codable>: Store {
    
    var keys: [Key] {
        get throws {
            try modelContext.fetch(FetchDescriptor<TimestampedValue>()).compactMap {
                guard let key = try? decoder.decode(Key.self, from: $0.key) else {
                    try? evict(for: $0.key)
                    return nil
                }
                return key
            }
        }
    }
    
    init<T: PersistentModel>(
        modelType: T.Type,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        let storeName: String = "TimestampStore-\(String(describing: modelType))"
        self.modelContainer = try! ModelContainer(
            for: TimestampedValue.self,
            configurations: .init(storeName)
        )
        self.encoder = encoder
        self.decoder = decoder
    }
    
    @MainActor
    func get(key: Key) throws -> Value? {
        let keyData = try encoder.encode(key)
        guard let valueData = try modelContext.fetch(
            FetchDescriptor(predicate: TimestampedValue.predicate(forKeyData: keyData))
        ).first else { return nil }
        return try decoder.decode(Value.self, from: valueData.value)
    }
    
    @discardableResult
    @MainActor
    func set(key: Key, value: Value?) throws -> Value? {
        if let value {
            try modelContext.insert(TimestampedValue(key: key, value: value, encoder: encoder))
            try modelContext.save()
        } else {
            let keyData = try encoder.encode(key)
            try evict(for: keyData)
        }
        return value
    }
    
    @MainActor
    func age(of key: Key) throws -> TimeInterval? {
        let keyData = try encoder.encode(key)
        let result = try modelContext.fetch(FetchDescriptor(predicate: TimestampedValue.predicate(forKeyData: keyData)))
        guard let result = result.first else { return nil }
        return Date.now.timeIntervalSince(result.timestamp)
    }
    
    @MainActor
    func clear() async throws {
        try modelContext.delete(model: TimestampedValue.self)
        try modelContext.save()
    }
    
    // MARK: - Constants
    
    @Model
    class TimestampedValue {
        #Index<TimestampedValue>([\.key])
        
        @Attribute(.unique)
        var key: Data
        var timestamp = Date()
        var value: Data
        
        init(key: Key, value: Value, encoder: JSONEncoder) throws {
            let key: Data = try encoder.encode(key)
            let value: Data = try encoder.encode(value)
            self.key = key
            self.value = value
        }
        
        static func predicate(forKeyData keyData: Data) throws -> Predicate<TimestampedValue> {
            return #Predicate { $0.key == keyData }
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
        try modelContext.delete(model: TimestampedValue.self, where: TimestampedValue.predicate(forKeyData: keyData))
        try modelContext.save()
    }
}
