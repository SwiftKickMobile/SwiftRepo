//
//  Created by Timothy Moose on 3/11/19.
//  Copyright © 2019 SwiftKick Mobile. All rights reserved.
//

import Foundation

public final actor Debounce<T: Sendable> {
    // MARK: - API

    public func send(_: T) async -> Bool {
        let updateID = UUID()
        self.updateID = updateID
        try? await Task.sleep(for: .seconds(rate))
        return self.updateID == updateID
    }

    public init(rate: TimeInterval) {
        self.rate = rate
    }

    // MARK: - Constants

    // MARK: - Variables

    private var updateID: UUID?
    private let rate: TimeInterval
}
