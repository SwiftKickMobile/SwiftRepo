//
//  Created by Timothy Moose on 2/10/24.
//

import OSLog
import Foundation

// TODO there are a lot of things in here that should be done async and should throw but we need to modify the `Store` API
// and there are probably massive ripple effects. For now, we use the `PersistentValue` type to defer async loading.
// and any filed save operations will not be handled properly.

/// A persistent store implementation that supports an optional 2nd-level storage for in-memory caching.
public final actor PersistentStore<Wrapped>: Store {

    // MARK: - API

    /// The key is required to be a string so we can easily use it as the filename. Otherwise, we need to add a mapping from
    /// filename to `Key` for the `keys` API.
    public typealias Key = String

    /// A closure that knows how to load a file URL of type `Wrapped`.
    public typealias Load = (URL) async throws -> Wrapped

    /// A closure that knows how to save type `Wrapped` to a file URL.
    public typealias Save = (Wrapped, URL) async throws -> Void

    /// A second level of storage intended for in-memory faster retrieval. Typically this would be an `NSCacheStore`.
    public typealias SecondLevelStore = any Store<Key, Wrapped>

    public enum Location {
        case documents(subpath: [String])
        case cache(subpath: [String])

        var directoryURL: URL {
            var url: URL
            switch self {
            case .documents: url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            case .cache: url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
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
            }
        }
    }

    // Create a `Data` store
    public init(location: Location, secondLevelStore: SecondLevelStore? = nil) where Wrapped == Data {
        print("PersistentStore location=\(location.directoryURL)")
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

    // Create a store.
    public init(
        load: @escaping Load,
        save: @escaping Save,
        location: Location,
        secondLevelStore: SecondLevelStore? = nil
    ) {
        self.load = load
        self.save = save
        self.location = location
        self.secondLevelStore = secondLevelStore
        do {
            try FileManager.default.createDirectory(at: location.directoryURL, withIntermediateDirectories: true)
        } catch {
            self.logger.error("\(error)")
        }
    }

    // MARK: - Constants

    // MARK: - Variables

    private let load: Load
    private let save: Save
    private let location: Location
    private let secondLevelStore: (any Store<Key, Wrapped>)?
    private let logger = Logger(subsystem: "SwiftRepo", category: "PersistentStore")

    // MARK: - Store

    public typealias Value = PersistentValue<Wrapped>

    @MainActor
    public func set(key: Key, value: Value?) -> Value? {
        switch value {
        case let value?:
            guard let wrapped = value.wrapped else { return nil }
            secondLevelStore?.set(key: key, value: wrapped)
            try? save(wrapped: wrapped, url: url(for: key))
            return value
        case .none:
            secondLevelStore?.set(key: key, value: nil)
            let url = url(for: key)
            try? FileManager.default.removeItem(atPath: url.path)
            return nil
        }
    }

    @MainActor
    public func get(key: Key) -> Value? {
        if let wrapped = secondLevelStore?.get(key: key) { return PersistentValue(initial: .wrapped(wrapped)) }
        let url = url(for: key)
        switch FileManager.default.fileExists(atPath: url.path) {
        case true: return load(url: url)
        case false: return nil
        }
    }

    @MainActor
    public func age(of key: Key) -> TimeInterval? {
        do {
            let url = url(for: key)
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let date = attr[FileAttributeKey.modificationDate] as? Date else { return nil }
            return Date().timeIntervalSince(date)
        } catch {
            return nil
        }
    }

    public func clear() async {
        await secondLevelStore?.clear()
        try? FileManager.default.removeItem(atPath: location.directoryURL.path)
        fatalError("TODO delete the directory")
    }

    @MainActor
    public var keys: [Key] {
        (try? FileManager.default.contentsOfDirectory(atPath: location.directoryURL.path)) ?? []
    }

    // MARK: - File management

    @MainActor
    private func url(for key: Key) -> URL {
        let url = location.directoryURL
        return url.appendingPathComponent(key)
    }

    @MainActor
    private func load(url: URL) -> Value {
        PersistentValue(initial: .load {
            do {
                return try await withUnsafeThrowingContinuation { continuation in
                    Task.detached(priority: .medium) {
                        let value = try await self.load(url)
                        continuation.resume(returning: value)
                    }
                }
            } catch {
                self.logger.error("\(error)")
                throw error
            }
        })
    }

    @MainActor
    private func save(wrapped: Wrapped, url: URL) {
        Task.detached(priority: .medium) {
            do {
                try await self.save(wrapped, url)
            } catch {
                self.logger.error("\(error)")
                throw error
            }
        }
    }
}

@globalActor
struct MediaActor {
  actor ActorType { }

  static let shared: ActorType = ActorType()
}
