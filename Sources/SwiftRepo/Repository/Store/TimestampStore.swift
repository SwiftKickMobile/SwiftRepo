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
            try modelContext.fetch(FetchDescriptor<Timestamp>()).map { $0.key }
        }
    }
    
    init<T: PersistentModel>(url: URL?, modelType: T.Type) {
        let storeName: String = "TimestampStore-\(String(describing: modelType))"
        if let url {
            let modelContainer = try! ModelContainer(
                for: Timestamp.self,
                configurations: .init(storeName, url: url)
            )
            modelContext = ModelContext(modelContainer)
        } else {
            let modelContainer = try! ModelContainer(
                for: Timestamp.self,
                configurations: .init(storeName)
            )
            modelContext = ModelContext(modelContainer)
        }
    }
    
    func get(key: Key) throws -> Date? {
        return try modelContext.fetch(FetchDescriptor(predicate: Timestamp.predicate(forKey: key))).first?.timestamp
    }
    
    @discardableResult
    func set(key: Key, value: Value?) throws -> Value? {
        if let value {
            modelContext.insert(Timestamp(key: key, timestamp: value))
            try modelContext.save()
        } else {
            try evict(for: key)
        }
        return value
    }
    
    func age(of key: Key) throws -> TimeInterval? {
        let result = try modelContext.fetch(FetchDescriptor(predicate: Timestamp.predicate(forKey: key)))
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
        var key: Key
        var timestamp: Date
        
        init(key: Key, timestamp: Date) {
            self.key = key
            self.timestamp = timestamp
        }
        
        static func predicate(forKey key: Key) -> Predicate<Timestamp> {
            #Predicate { $0.key == key }
        }
    }
    
    // MARK: - Variables
    
    private let modelContext: ModelContext
    
    // MARK: - Helpers
    
    private func evict(for key: Key) throws {
        try modelContext.delete(model: Timestamp.self, where: Timestamp.predicate(forKey: key))
        try modelContext.save()
    }
}
