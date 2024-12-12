//
//  Created by Neha Thakore on 3/12/19.
//  Copyright © 2019 SwiftKick Mobile. All rights reserved.
//

import Foundation

public actor Throttle<T: Sendable> {
    // MARK: - API

    public init(rate: Duration, callback: @escaping (T) async -> Void) {
        self.rate = rate
        self.callback = callback
    }

    public private(set) var pendingValue: T? {
        didSet {
            Task {
                await dequeuePendingValue()
            }
        }
    }

    nonisolated public func update(value: T) {
        Task {
            await enqueue(value: value)
        }
    }

    // MARK: - Constants

    // MARK: - Variables

    private var waiting: Bool = false
    private let rate: Duration
    private let callback: (T) async -> Void

    // MARK: Queuing

    private func enqueue(value: T) {
        pendingValue = value
    }

    private func dequeuePendingValue() async {
        // 1. Check dependencies
        guard let pendingValue = pendingValue, !waiting else { return }
        // 2. Emit value
        await callback(pendingValue)
        // 3. Set up for next cycle
        self.pendingValue = nil
        waiting = true
        try? await Task.sleep(for: rate)
        waiting = false
        await dequeuePendingValue()
    }
}
