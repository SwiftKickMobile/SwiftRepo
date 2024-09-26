//
//  Created by Timothy Moose on 5/27/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import XCTest
@testable import SwiftRepo

class DefaultQueryTests: XCTestCase {

    // MARK: - Unique scope query

    func testOneUniqueScopeQuery() async throws {
        let variable = "1"
        let query = DefaultQuery<String, String, String> { variables in
            try await Task.sleep(for: .seconds(0.1))
            return variables
        }
        let allSpy = PublisherSpy<TestErrorResultType>(query.publisher.testErrorFilter())
        let spy = PublisherSpy<TestErrorResultType>(query.publisher(for: variable).testErrorFilter())
        do {
            let value = try await query.get(id: variable, variables: variable)
            XCTAssertEqual(value, variable)
        }
        let success = TestErrorResultType(queryId: variable, variables: variable, success: variable)
        fatalError()
//        assertPublished([success], spy: allSpy)
//        assertPublished([success], spy: spy)
    }

    func testMultiUniqueScopeQuery() async throws {
        let variable1 = "1"
        let variable2 = "2"
        let query = DefaultQuery<String, String, String> { variables in
            try await Task.sleep(for: .seconds(0.1))
            return variables
        }
        let allSpy = PublisherSpy<TestErrorResultType>(query.publisher.testErrorFilter())
        let spy1 = PublisherSpy<TestErrorResultType>(query.publisher(for: variable1).testErrorFilter())
        let spy2 = PublisherSpy<TestErrorResultType>(query.publisher(for: variable2).testErrorFilter())
        // Don't wait for the first query
        Task {
            try await query.get(id: variable1, variables: variable1)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // Don't wait for the second query
        Task {
            try await query.get(id: variable2, variables: variable2)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // This one should test de-duplication
        try await query.get(id: variable1, variables: variable1)
        try await query.get(id: variable1, variables: variable1)
        let success1 = TestErrorResultType(queryId: variable1, variables: variable1, success: variable1)
        let success2 = TestErrorResultType(queryId: variable2, variables: variable2, success: variable2)
        fatalError()
//        assertPublished([success1, success2, success1], spy: allSpy)
//        assertPublished([success1, success1], spy: spy1)
//        assertPublished([success2], spy: spy2)
    }

    func testErrorUniqueScopeQuery() async throws {
        let variable1 = "1"
        let variable2 = "2"
        let query = DefaultQuery<String, String, String> { variables in
            if variables == variable1 {
                return variable1
            }
            throw TestError(category: .failure)
        }
        let spy = PublisherSpy<TestErrorResultType>(query.publisher.testErrorFilter())
        var expectedError: TestError?
        do {
            try await query.get(id: variable1, variables: variable1)
            try await query.get(id: variable2, variables: variable2)
        } catch {
            expectedError = error as? TestError
        }
        XCTAssertEqual(expectedError, TestError(category: .failure))
        let success1 = TestErrorResultType(queryId: variable1, variables: variable1, success: variable1)
        let failure2 = TestErrorResultType(queryId: variable2, variables: variable2, failure: TestError(category: .failure))
        fatalError()
//        assertPublished([success1, failure2], spy: spy)
    }

    // MARK: - Shared scope query

    func testMultiSharedQuery() async throws {
        let variable1 = "1"
        let variable2 = "2"
        let query = DefaultQuery<String, String, String> { variables in
            try await Task.sleep(for: .seconds(0.1))
            return variables
        }
        let allSpy = PublisherSpy<CancelResultType>(query.publisher.cancelFilter())
        let spy1 = PublisherSpy<CancelResultType>(query.publisher(for: variable1).cancelFilter())
        let spy2 = PublisherSpy<CancelResultType>(query.publisher(for: variable2).cancelFilter())
        // Don't wait for the first query. This one will get cancelled.
        Task {
            var expectedError: QueryError?
            do {
                try await query.get(id: variable1, variables: variable1)
            } catch {
                expectedError = error as? QueryError
            }
            XCTAssertEqual(expectedError, .cancelled)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // Don't wait for the second query. This one will cancel the first.
        Task {
            let value = try await query.get(id: variable1, variables: variable2)
            XCTAssertEqual(value, variable2)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // Start another query with a new ID before the previous queries have completed.
        Task {
            let value = try await query.get(id: variable2, variables: variable2)
            XCTAssertEqual(value, variable2)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        try await query.get(id: variable1, variables: variable2)
        try await query.get(id: variable1, variables: variable1)
        let success12 = CancelResultType(queryId: variable1, variables: variable2, success: variable2)
        let success11 = CancelResultType(queryId: variable1, variables: variable1, success: variable1)
        let success2 = CancelResultType(queryId: variable2, variables: variable2, success: variable2)
        fatalError()
//        assertPublished([success12, success2, success11], spy: allSpy)
//        assertPublished([success12, success11], spy: spy1)
//        assertPublished([success2], spy: spy2)
    }

    private typealias TestErrorResultType = QueryResult<String, String, String, TestError>
    private typealias CancelResultType = QueryResult<String, String, String, QueryError>
}

private extension Publisher where Output == QueryResult<String, String, String, Error>, Failure == Never {
    /// Filters result to `GraphQLClientError` concrete error type required for publisher spy
    func testErrorFilter() -> AnyPublisher<QueryResult<String, String, String, TestError>, Never> {
        errorFilter(errorType: TestError.self)
    }

    /// Filters result to `QueryError` concrete error type required for publisher spy
    func cancelFilter() -> AnyPublisher<QueryResult<String, String, String, QueryError>, Never> {
        errorFilter(errorType: QueryError.self)
    }

    func errorFilter<ErrorType: Error>(errorType _: ErrorType.Type) -> AnyPublisher<QueryResult<String, String, String, ErrorType>, Never> {
        compactMap {
            switch $0.result {
            case let .success(value): return .init(queryId: $0.queryId, variables: $0.variables, success: value)
            case let .failure(error as ErrorType): return .init(queryId: $0.queryId, variables: $0.variables, failure: error)
            default: return nil
            }
        }
        .eraseToAnyPublisher()
    }
}
