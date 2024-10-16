//
//  Created by Timothy Moose on 2/2/22.
//

import Foundation

public actor DelayedValues<T> {
    // MARK: - API

    /// A data structure representing a delayed value or error.
    public struct Value: Sendable {
        public var delay: TimeInterval
        public var result: Result<T, Error>

        public static func makeValue(_ value: T, delay: TimeInterval = 0) -> Value {
            Value(value: value, delay: delay)
        }

        public static func makeError(_ error: Error, delay: TimeInterval = 0) -> Value {
            Value(error: error, delay: delay)
        }

        public init(value: T, delay: TimeInterval = 0) {
            self.delay = delay
            result = .success(value)
        }

        public init(error: Error, delay: TimeInterval = 0) {
            self.delay = delay
            result = .failure(error)
        }
    }

    public func set(_ values: [Value]) async {
        self.values = values
    }

    /// The sequence of delayed values to emit as `next()` is called. This property can be updated at any time.
    public private(set) var values: [Value] = []

    /// Pops the next value off of the array of `values` and either returns the value or throws
    /// the error after sleeping for the specified `delay`
    public func next() async throws -> T {
        guard !values.isEmpty else { throw NextError.noValues }
        let next = values.count == 1 ? values[0] : values.removeFirst()
        try await Task.sleep(nanoseconds: UInt64(next.delay * 1_000_000_000))
        switch next.result {
        case let .success(value): return value
        case let .failure(error): throw error
        }
    }

    public init(values: [Value]) {
        self.values = values
    }

    // MARK: - Constants

    private enum NextError: Error {
        case noValues
    }

    // MARK: - Variables
}
