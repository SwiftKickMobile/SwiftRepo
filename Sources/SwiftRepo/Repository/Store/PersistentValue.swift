//
//  Created by Timothy Moose on 2/10/24.
//

import Foundation

// Wraps a persistent value that may be in memory on disk
public class PersistentValue<Wrapped> {

    // MARK: - API

    public func wrapped() async throws -> Wrapped {
        if let wrapped { return wrapped }
        switch initial {
        case .wrapped(let wrapped):
            self.wrapped = wrapped
            return wrapped
        case .load(let load):
            let wrapped = try await load()
            self.wrapped = wrapped
            return wrapped
        }
    }

    public init(wrapped: Wrapped) {
        self.initial = .wrapped(wrapped)
        self.wrapped = wrapped
    }

    enum Initial {
        case wrapped(Wrapped)
        case load(() async throws -> Wrapped)
    }

    init(initial: Initial) {
        self.initial = initial
    }

    private(set) var wrapped: Wrapped?

    // MARK: - Constants

    // MARK: - Variables

    private let initial: Initial
}
