//
//  FileStore.swift
//  SwiftRepo
//
//  Created by Timothy Moose on 6/22/25.
//

import OSLog
import Foundation
import SwiftRepoCore

extension String: @retroactive RawRepresentable {

    public var rawValue: String {
        self
    }

    public init(rawValue: String) {
        self = rawValue
    }
}

/// A persistent store implementation that supports an optional 2nd-level storage for in-memory caching.
/// This store is useful for storing images and caching recently used ones in memory.
@MainActor
public final class FileStore<Key: Hashable, Value: Sendable>: Store where Key: RawRepresentable, Key.RawValue == String {

    // MARK: - API

//    /// The key is required to be a string so we can easily use it as the filename. Otherwise, we need to add a mapping from
//    /// filename to `Key` for the `keys` API.
//    public typealias Key = String

    /// A closure that knows how to load a file URL of type `Wrapped`.
    public typealias Load = @Sendable (URL) async throws -> Value

    /// A closure that knows how to save type `Wrapped` to a file URL.
    public typealias Save = @Sendable (Value, URL) async throws -> Void

    /// A second level of storage intended for in-memory faster retrieval. Typically this would be an `NSCacheStore`.
    public typealias SecondLevelStore = any Store<Key, Value>

    public enum Location: Sendable {
        case documents(subpath: [String])
        case cache(subpath: [String])
        case appGroup(identifier: String, subpath: [String])

        var directoryURL: URL {
            var url: URL
            switch self {
            case .documents: url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            case .cache: url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            case .appGroup(let identifier, _):
                url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)!
            }
            for component in subpath {
                url = url.appendingPathComponent(component)
            }
            return url
        }

        var subpath: [String] {
            switch self {
            case .cache(let subpath): subpath
            case .documents(let subpath): subpath
            case .appGroup(_, let subpath): subpath
            }
        }
    }

    // Create a `Data` store
    public convenience init(location: Location, secondLevelStore: SecondLevelStore? = nil) where Value == Data {
        self.init(
            load: { url in
                try Data(contentsOf: url)
            },
            save: { data, url in
                try data.write(to: url)
            },
            location: location,
            secondLevelStore: secondLevelStore
        )
    }

    // Create a `Codable` store with JSON encoding/decoding
    public convenience init(
        location: Location,
        secondLevelStore: SecondLevelStore? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) where Value: Codable {
        self.init(
            load: { url in
                let data = try Data(contentsOf: url)
                return try decoder.decode(Value.self, from: data)
            },
            save: { value, url in
                let data = try encoder.encode(value)
                try data.write(to: url)
            },
            location: location,
            secondLevelStore: secondLevelStore
        )
    }

    // Create a store.
    public init(
        load: @escaping Load,
        save: @escaping Save,
        location: Location,
        secondLevelStore: SecondLevelStore? = nil
    ) {
        print("FileStore location=\(location.directoryURL)")
        self.load = load
        self.save = save
        self.location = location
        self.secondLevelStore = secondLevelStore
        // Allowing this to fail silently to be DI-friendly. Load and save operations will throw downstream.
        try? FileManager.default.createDirectory(at: location.directoryURL, withIntermediateDirectories: true)
    }

    // MARK: - Constants

    // MARK: - Variables

    private let load: Load
    private let save: Save
    private let location: Location
    private let secondLevelStore: (any Store<Key, Value>)?

    // MARK: - Store

    @AsyncLocked
    public func set(key: Key, value: Value?) async throws -> Value? {
        switch value {
        case let value?:
            try await secondLevelStore?.set(key: key, value: value)
            let fileURL = url(for: key)
            try await save(value: value, url: fileURL)
            return value
        case .none:
            try await secondLevelStore?.set(key: key, value: nil)
            let url = url(for: key)
            try? FileManager.default.removeItem(atPath: url.path)
            return nil
        }
    }

    @AsyncLocked
    public func get(key: Key) async throws -> Value? {
        if let value = try await secondLevelStore?.get(key: key) { return value }
        let url = url(for: key)
        switch FileManager.default.fileExists(atPath: url.path) {
        case true: return try await load(url: url)
        case false: return nil
        }
    }

    @AsyncLocked
    public func age(of key: Key) async throws -> TimeInterval? {
        do {
            let url = url(for: key)
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let date = attr[FileAttributeKey.modificationDate] as? Date else { return nil }
            let age = Date().timeIntervalSince(date)
            return age
        } catch {
            return nil
        }
    }

    @AsyncLocked
    public func clear() async throws {
        try await secondLevelStore?.clear()
        try FileManager.default.removeItem(atPath: location.directoryURL.path)
    }

    public var keys: [Key] {
        (
            try? FileManager.default.contentsOfDirectory(atPath: location.directoryURL.path)
                .compactMap { Key(rawValue: $0) }
        ) ?? []
    }

    // MARK: - File management

    private func url(for key: Key) -> URL {
        let url = location.directoryURL
        return url.appendingPathComponent(key.rawValue)
    }

    @BackgroundFileActor
    private func load(url: URL) async throws -> Value {
        return try await self.load(url)
    }

    @BackgroundFileActor
    private func save(value: Value, url: URL) async throws {
        try await self.save(value, url)
    }
}

@globalActor
actor BackgroundFileActor {
    static let shared = BackgroundFileActor()

    private init() {}
}
