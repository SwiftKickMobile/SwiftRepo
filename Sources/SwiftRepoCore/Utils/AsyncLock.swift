//
//  AsyncLock.swift
//  SwiftRepo
//
//  Created by Timothy Moose on 6/22/25.
//

/// A simple async lock implementation that suspends the caller without blocking the main thread.
public final actor AsyncLock: @unchecked Sendable {

    // MARK: - API

    /// Waits until the lock is available and then locks.
    public func lock() async {
        await withUnsafeContinuation { continuation in
            switch isLocked {
            case true:
                waiters.append(continuation)
            case false:
                isLocked = true
                continuation.resume()
            }
        }
    }

    /// Waits until the lock and then immediately unlocks.
    ///
    /// This is useful in actor-isolated contexts when a task needs to ensure that
    /// a critical section has finished before proceeding, without preventing others
    /// from acquiring the lock first.
    ///
    /// ⚠️ Note: This does *not* guarantee exclusive access after resumption.
    /// If exclusive access is needed, use `lock()` instead.
    public func waitUntilUnlocked() async {
        await lock()
        unlock()
    }

    /// Unlocks
    nonisolated public func unlock() {
        Task {
            await _unlock()
        }
    }

    public init() {}

    // MARK: - Constants

    // MARK: - Variables

    var isLocked = false
    var waiters: [UnsafeContinuation<Void, Never>] = []

    // MARK: - Helpers

    private func _unlock() {
        if let next = waiters.first {
            waiters.removeFirst()
            next.resume()
        } else {
            isLocked = false
        }
    }
}
