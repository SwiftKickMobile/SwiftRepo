//
//  Created by Timothy Moose on 5/27/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

@preconcurrency import Combine
import Foundation

/// The default `Query` implementation.
@MainActor
public final class DefaultQuery<QueryId: Hashable & Sendable, Variables: Hashable & Sendable, Value: Sendable>: Query {
    // MARK: - API

    public typealias ResultType = QueryResult<QueryId, Variables, Value, Error>

    /// Create a `DefaultQuery` given a remote operation.
    /// - Parameters:
    ///   - queryOperation: a closure that performs the query operation, typically making a service call and returning the data.
    public init(queryOperation: @escaping @Sendable (Variables) async throws -> Value) {
        self.queryOperation = queryOperation
    }

    @discardableResult
    public func get(id: QueryId, variables: Variables) async throws -> Value {
        #if DEV || DEBUG
            try await withCheckedThrowingContinuation { continuation in
                get(id: id, variables: variables, continuation: continuation)
            }
        #else
            try await withUnsafeThrowingContinuation { continuation in
                get(id: id, variables: variables, continuation: continuation)
            }
        #endif
    }

    public func cancel(id: QueryId) async {
        taskCollateral[id]?.cancel()
        taskCollateral[id] = nil
    }

    public var publisher: AnyPublisher<ResultType, Never> {
        subject.eraseToAnyPublisher()
    }

    public func publisher(for id: QueryId) -> AnyPublisher<ResultType, Never> {
        subject
            .filter { $0.queryId == id }
            .eraseToAnyPublisher()
    }

    public func latestVariables(for id: QueryId) async -> Variables? {
        lastVariables[id]
    }

    // MARK: - Constants

    #if DEV || DEBUG
        private typealias ContinuationType = CheckedContinuation<Value, Error>
    #else
        private typealias ContinuationType = UnsafeContinuation<Value, Error>
    #endif

    /// A structure for keeping track of data required to perform a `get(variables:)` task.
    private struct TaskCollateral: Sendable {
        var variables: Variables
        var task: Task<Void, Never>
        var continuations: [ContinuationType]

        func cancel() {
            for continuation in continuations {
                continuation.resume(throwing: QueryError.cancelled)
            }
            task.cancel()
        }
    }

    // MARK: - Variables

    private let queryOperation: @Sendable (Variables) async throws -> Value
    private let subject = PassthroughSubject<ResultType, Never>()
    private var taskCollateral: [QueryId: TaskCollateral] = [:]
    private var lastVariables: [QueryId: Variables] = [:]

    // MARK: - Managing continuations

    private func get(id: QueryId, variables: Variables, continuation: ContinuationType) {
        // Cancel ongoing requets in this ID-scope if the variables have changed.
        if let collateral = taskCollateral[id], variables != collateral.variables {
            collateral.cancel()
            taskCollateral[id] = nil
        }
        if var collateral = taskCollateral[id] {
            // There is an ongoing task. We only need to add our continuation to the list.
            collateral.continuations.append(continuation)
            taskCollateral[id] = collateral
        } else {
            let task = Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let value = try await self.queryOperation(variables)
                    self.resume(for: id, with: .success(value))
                } catch {
                    self.resume(for: id, with: .failure(error))
                }
            }
            taskCollateral[id] = TaskCollateral(variables: variables, task: task, continuations: [continuation])
        }
    }

    /// Resumes the continuations associated with the given variables and cleans up.
    private func resume(for id: QueryId, with result: Result<Value, Error>) {
        guard !Task.isCancelled else { return }
        guard let collateral = taskCollateral[id] else {
            assertionFailure("The collateral went missing for id=\(id)")
            return
        }
        taskCollateral[id] = nil
        switch result {
        case let .success(value):
            lastVariables[id] = collateral.variables
            subject.send(QueryResult(queryId: id, variables: collateral.variables, result: .success(value)))
        case let .failure(error):
            subject.send(QueryResult(queryId: id, variables: collateral.variables, result: .failure(error)))
        }
        for continuation in collateral.continuations {
            switch result {
            case let .success(value): continuation.resume(returning: value)
            case let .failure(error): continuation.resume(throwing: error)
            }
        }
    }
}
