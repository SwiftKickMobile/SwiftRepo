//
//  Created by Timothy Moose on 5/27/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
//#if canImport(XCTest)
//import XCTest
//#endif

public class PublisherSpy<Value> {
    // MARK: - API

    public var publishedValues: [Value] {
        publishedValuesSubject.value
    }

    public init(_ publisher: AnyPublisher<Value, Never>) {
        publisher
            .sink { [weak self] value in
                guard let self = self else { return }
                var values = self.publishedValuesSubject.value
                values.append(value)
                self.publishedValuesSubject.send(values)
                self.singleValueContinuation?.resume(returning: value)
                self.singleValueContinuation = nil
                if self.expectedValuesCount > self.multiValueResult.count {
                    self.multiValueResult.append(value)
                }

                if self.expectedValuesCount == self.multiValueResult.count {
                    self.multiValueContinuation?.resume(
                        returning: self.multiValueResult
                    )
                    self.multiValueContinuation = nil
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
    public func execute(timeout: Double = 10, closure: @escaping () async -> Void) async throws -> Value {
        let value = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Value, any Error>) in
            self.singleValueContinuation = cont
            Task {
                await closure()
            }
            Task {
                try await Task.sleep(for: .seconds(timeout))
                let timeoutError = TimeoutError(duration: timeout)
                self.singleValueContinuation?.resume(throwing: timeoutError)
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
    public func execute(timeout: Double = 30, expectedValuesCount: Int, closure: @escaping () async -> Void) async throws -> [Value] {
        self.expectedValuesCount = expectedValuesCount
        multiValueResult = []
        let values = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Value], any Error>) in
            self.multiValueContinuation = cont
            Task {
                await closure()
            }
            Task {
                try await Task.sleep(for: .seconds(timeout))
                let timeoutError = TimeoutError(duration: timeout)
                self.multiValueContinuation?.resume(throwing: timeoutError)
            }
        }

        return values
    }

    // MARK: - Constants

    struct TimeoutError: Error {
        var duration: Double
    }

    // MARK: - Variables

    private var expectedValuesCount: Int = 0
    private var multiValueResult = [Value]()
    fileprivate let publishedValuesSubject = CurrentValueSubject<[Value], Never>([])
    fileprivate var cancellables = Set<AnyCancellable>()
    private var singleValueContinuation: CheckedContinuation<Value, any Error>?
    private var multiValueContinuation: CheckedContinuation<[Value], any Error>?
}

//#if canImport(XCTest)
//public extension XCTestCase {
//    func assertPublished<PublishedValue>(
//        _ expected: [PublishedValue],
//        spy: PublisherSpy<PublishedValue>,
//        timeout: Double = 1.0
//    ) where PublishedValue: Equatable {
//        let expectation = XCTestExpectation(description: "assertPublished")
//        spy.publishedValuesSubject
//            .sink { values in
//                if values == expected {
//                    expectation.fulfill()
//                }
//            }
//            .store(in: &spy.cancellables)
//        wait(for: [expectation], timeout: timeout)
//    }
//}
//#endif
