//
//  TimestampStore.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/2/24.
//

import Foundation
import SwiftData

/// A `Store` implementation using `SwiftData` which can be used specifically to
/// track timestamps related to models persisted using the `SwiftDataStore`.
class TimestampStore<Key: Codable & Hashable>: Store {
    
    var keys: [Key] {
        get throws {
            try modelContext.fetch(FetchDescriptor<Timestamp>()).compactMap {
                guard let key = try? JSONDecoder().decode(Key.self, from: $0.key) else {
                    try? evict(for: $0.key)
                    return nil
                }
                return key
            }
        }
    }
    
    init<T: PersistentModel>(modelType: T.Type) {
        let storeName: String = "TimestampStore-\(String(describing: modelType))"
        let modelContainer = try! ModelContainer(
            for: Timestamp.self,
            configurations: .init(storeName)
        )
        modelContext = ModelContext(modelContainer)
    }
    
    func get(key: Key) throws -> Date? {
        let keyData = try JSONEncoder().encode(key)
        return try modelContext.fetch(
            FetchDescriptor(predicate: Timestamp.predicate(forKeyData: keyData))
        ).first?.timestamp
    }
    
    @discardableResult
    func set(key: Key, value: Value?) throws -> Value? {
        if let value {
            try modelContext.insert(Timestamp(key: key, timestamp: value))
            try modelContext.save()
        } else {
            let keyData = try JSONEncoder().encode(key)
            try evict(for: keyData)
        }
        return value
    }
    
    func age(of key: Key) throws -> TimeInterval? {
        let keyData = try JSONEncoder().encode(key)
        let result = try modelContext.fetch(FetchDescriptor(predicate: Timestamp.predicate(forKeyData: keyData)))
        guard let result = result.first else { return nil }
        return Date.now.timeIntervalSince(result.timestamp)
    }
    
    func clear() async throws {
        try modelContext.delete(model: Timestamp.self)
        try modelContext.save()
    }
    
    // MARK: - Constants
    
    @Model
    class Timestamp {
        #Index<Timestamp>([\.key])
        
        @Attribute(.unique)
        var key: Data
        var timestamp: Date
        
        init(key: Key, timestamp: Date) throws {
            let key: Data = try JSONEncoder().encode(key)
            self.key = key
            self.timestamp = timestamp
        }
        
        static func predicate(forKeyData keyData: Data) throws -> Predicate<Timestamp> {
            return #Predicate { $0.key == keyData }
        }
    }
    
    // MARK: - Variables
    
    private let modelContext: ModelContext
    
    // MARK: - Helpers
    
    private func evict(for keyData: Data) throws {
        try modelContext.delete(model: Timestamp.self, where: Timestamp.predicate(forKeyData: keyData))
        try modelContext.save()
    }
}
