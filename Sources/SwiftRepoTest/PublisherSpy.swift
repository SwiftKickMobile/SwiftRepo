//
//  Created by Timothy Moose on 5/27/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Foundation
@preconcurrency import Combine

public class PublisherSpy<Value: Sendable> {
    // MARK: - API

    public var publishedValues: [Value] {
        publishedValuesSubject.value
    }

    public init(_ publisher: AnyPublisher<Value, Never>) {
        publisher
            .print()
            .sink { [weak self] value in
                guard let self = self else { return }
                var values = self.publishedValuesSubject.value
                values.append(value)
                self.publishedValuesSubject.send(values)
                if let continuation = self.singleValueContinuation {
                    continuation.resume(returning: value)
                    self.singleValueContinuation = nil
                }
                if self.expectedValuesCount > self.multiValueResult.count {
                    self.multiValueResult.append(value)
                }

                if self.expectedValuesCount == self.multiValueResult.count {
                    if let continuation = self.multiValueContinuation {
                        let result = self.multiValueResult
                        continuation.resume(returning: result)
                        self.multiValueContinuation = nil
                    }
                }
            }
            .store(in: &cancellables)
    }

    public convenience init(_ publisher: Published<Value>.Publisher) {
        self.init(publisher.eraseToAnyPublisher())
    }

    /// Executes the given `async` closure and waits for the publisher to emit a value before returning.
    ///
    /// Typical usage looks like:
    ///
    /// ````
    ///  let value = await spy.execute { await sut.someAsyncCall() }
    ///  XCTAssertEqual(someExpectedValue, value)
    /// ````
    ///
    /// This is preferable to the common pattern of using `sleep` to give time for the publisher to emit the value.
    ///
    /// ````
    /// await sut.someAsyncCall()
    /// Task.sleep(seconds: 0.1)
    /// XCTAssertEqual([someExpectedValue], spy.publishedValues)
    /// ````
    /// This later approach is subject to race conditions, resulting in flakey tests, and may needlessly extend test execution times.
    ///
    /// - Parameters:
    ///   - timeout: tolerance in seconds to resume before an error is thrown
    ///   - closure: an `async` closure that resumes after a single value being published
    /// - Returns: the first value published by executing the closure.
    ///
    /// - note: This function would return a single value at a time, but can be used as many times as you need.
    public func execute(timeout: Double = 10, closure: @escaping @Sendable () async -> Void) async throws -> Value {
        let value = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Value, any Error>) in
            self.singleValueContinuation = cont
            Task { @Sendable in
                await closure()
            }
            Task { @Sendable [cont] in
                try await Task.sleep(for: .seconds(timeout))
                let timeoutError = TimeoutError(duration: timeout)
                cont.resume(throwing: timeoutError)
            }
        }

        return value
    }

    /// Executes the given `async` closure and waits for the publisher to emit an expected number of values before returning.
    ///
    /// Typical usage looks like:
    ///
    /// ````
    ///  let values = await spy.execute { await sut.someAsyncCall() }
    ///  XCTAssertEqual([someExpectedValues], values)
    /// ````
    ///
    /// This is preferable to the common pattern of using `sleep` to give time for the publisher to emit the value.
    ///
    /// ````
    /// await sut.someAsyncCall()
    /// Task.sleep(seconds: 0.1)
    /// XCTAssertEqual(someExpectedValues, spy.publishedValues)
    /// ````
    /// This later approach is subject to race conditions, resulting in flakey tests, and may needlessly extend test execution times.
    ///
    /// - Parameters:
    ///   - timeout: tolerance in seconds to resume before an error is thrown
    ///   - expecting: the total number of values needed to be published for the function to resume
    ///   - closure: an `async` closure that resumes after `expecting` number of values have been published
    /// - Returns: an array formed by the published values after executing the closure.
    public func execute(timeout: Double = 30, expectedValuesCount: Int, closure: @escaping @Sendable () async -> Void) async throws -> [Value] {
        self.expectedValuesCount = expectedValuesCount
        multiValueResult = []
        let values = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Value], any Error>) in
            self.multiValueContinuation = cont
            Task { @Sendable in
                await closure()
            }
            Task { @Sendable [cont] in
                try await Task.sleep(for: .seconds(timeout))
                let timeoutError = TimeoutError(duration: timeout)
                cont.resume(throwing: timeoutError)
            }
        }

        return values
    }

    /// Waits for the publisher to emit the expected values within the timeout period.
    /// This is the Swift Testing equivalent of the old XCTest assertPublished function.
    ///
    /// - Parameters:
    ///   - expected: The expected values in order
    ///   - timeout: Maximum time to wait for values (default: 1.0 seconds)
    /// - Throws: TimeoutError if values don't match within timeout
    public func waitForValues(_ expected: [Value], timeout: Double = 1.0) async throws where Value: Equatable {
        // Check if we already have the expected values
        if publishedValues == expected {
            return
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let box = Box<(AnyCancellable?, Task<Void, Never>?)>((nil, nil))
            
            // Set up timeout
            box.value.1 = Task { @Sendable in
                try? await Task.sleep(for: .seconds(timeout))
                box.value.0?.cancel()
                continuation.resume(throwing: TimeoutError(duration: timeout))
            }
            
            // Subscribe to value changes
            box.value.0 = publishedValuesSubject
                .sink { @Sendable values in
                    if values == expected {
                        box.value.1?.cancel()
                        continuation.resume()
                    }
                }
            
            // Store the cancellable
            if let valueCancellable = box.value.0 {
                cancellables.insert(valueCancellable)
            }
        }
    }

    // MARK: - Constants

    public struct TimeoutError: Error {
        public var duration: Double
    }

    // MARK: - Variables

    private var expectedValuesCount: Int = 0
    private var multiValueResult = [Value]()
    public let publishedValuesSubject = CurrentValueSubject<[Value], Never>([])
    public var cancellables = Set<AnyCancellable>()
    private var singleValueContinuation: CheckedContinuation<Value, any Error>?
    private var multiValueContinuation: CheckedContinuation<[Value], any Error>?
}

private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
