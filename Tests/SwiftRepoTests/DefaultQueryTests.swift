//
//  Created by Timothy Moose on 5/27/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

@preconcurrency import Combine
import Testing
import SwiftRepoCore
import SwiftRepoTest
@testable import SwiftRepo

@MainActor
struct DefaultQueryTests {

    // MARK: - Unique scope query

    @Test("Single unique scope query")
    func oneUniqueScopeQuery() async throws {
        let variable = "1"
        let query = DefaultQuery<String, String, String> { variables in
            try await Task.sleep(for: .seconds(0.1))
            return variables
        }
        let allSpy = PublisherSpy<TestErrorResultType>(query.publisher.testErrorFilter())
        let spy = PublisherSpy<TestErrorResultType>(query.publisher(for: variable).testErrorFilter())
        
        let value = try await query.get(id: variable, variables: variable)
        #expect(value == variable)
        
        let success = TestErrorResultType(queryId: variable, variables: variable, success: variable)
        try await allSpy.waitForValues([success])
        try await spy.waitForValues([success])
    }

    @Test("Two unique scope queries")
    func twoUniqueScopeQueries() async throws {
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
            _ = try await query.get(id: variable1, variables: variable1)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // Don't wait for the second query
        Task {
            _ = try await query.get(id: variable2, variables: variable2)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // This one should test de-duplication
        let value1a = try await query.get(id: variable1, variables: variable1)
        let value1b = try await query.get(id: variable1, variables: variable1)
        #expect(value1a == variable1)
        #expect(value1b == variable1)
        
        let success1 = TestErrorResultType(queryId: variable1, variables: variable1, success: variable1)
        let success2 = TestErrorResultType(queryId: variable2, variables: variable2, success: variable2)
        try await allSpy.waitForValues([success1, success2, success1])
        try await spy1.waitForValues([success1, success1])
        try await spy2.waitForValues([success2])
    }

    @Test("Query error handling")
    func queryError() async throws {
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
            _ = try await query.get(id: variable1, variables: variable1)
            _ = try await query.get(id: variable2, variables: variable2)
        } catch {
            expectedError = error as? TestError
        }
        #expect(expectedError?.category == .failure)
        let success1 = TestErrorResultType(queryId: variable1, variables: variable1, success: variable1)
        let failure2 = TestErrorResultType(queryId: variable2, variables: variable2, failure: TestError(category: .failure))
        try await spy.waitForValues([success1, failure2])
    }

    @Test("Query cancellation")
    func queryCancel() async throws {
        let queryId = "1"
        let variables1 = "variables1"
        let variables2 = "variables2"
        let query = DefaultQuery<String, String, String> { variables in
            try await Task.sleep(for: .seconds(0.1))
            return variables
        }
        let allSpy = PublisherSpy<CancelResultType>(query.publisher.cancelFilter())
        let spy = PublisherSpy<CancelResultType>(query.publisher(for: queryId).cancelFilter())
        
        // Start first query with queryId and variables1 - this will get cancelled
        Task {
            _ = try await query.get(id: queryId, variables: variables1)
        }
        // Pause briefly to let first query start
        try await Task.sleep(for: .seconds(0.05))
        
        // Start second query with same queryId but different variables - this should cancel the first
        Task {
            _ = try await query.get(id: queryId, variables: variables2)
        }
        // Wait for second query to complete
        try await Task.sleep(for: .seconds(0.15))
        
        // Start third query with same queryId and original variables - this should succeed
        let value = try await query.get(id: queryId, variables: variables1)
        #expect(value == variables1)
        
        // Expected results:
        // 1. First query gets cancelled (not published to subject)
        // 2. Second query succeeds (published)
        // 3. Third query succeeds (published)
        let success2 = CancelResultType(queryId: queryId, variables: variables2, success: variables2)
        let success3 = CancelResultType(queryId: queryId, variables: variables1, success: variables1)
        try await allSpy.waitForValues([success2, success3])
        try await spy.waitForValues([success2, success3])
    }

    // MARK: - Shared scope query

    @Test("Multi shared query")
    func multiSharedQuery() async throws {
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
                _ = try await query.get(id: variable1, variables: variable1)
            } catch {
                expectedError = error as? QueryError
            }
            #expect(expectedError == .cancelled)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // Don't wait for the second query. This one will cancel the first.
        Task {
            let value = try await query.get(id: variable1, variables: variable2)
            #expect(value == variable2)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        // Start another query with a new ID before the previous queries have completed.
        Task {
            let value = try await query.get(id: variable2, variables: variable2)
            #expect(value == variable2)
        }
        // Pause briefly to avoid race conditions
        try await Task.sleep(for: .seconds(0.025))
        _ = try await query.get(id: variable1, variables: variable2)
        _ = try await query.get(id: variable1, variables: variable1)
        let success12 = CancelResultType(queryId: variable1, variables: variable2, success: variable2)
        let success11 = CancelResultType(queryId: variable1, variables: variable1, success: variable1)
        let success2 = CancelResultType(queryId: variable2, variables: variable2, success: variable2)
        try await allSpy.waitForValues([success12, success2, success11])
        try await spy1.waitForValues([success12, success11])
        try await spy2.waitForValues([success2])
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
