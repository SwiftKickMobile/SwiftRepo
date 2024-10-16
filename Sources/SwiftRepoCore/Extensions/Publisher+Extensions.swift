//
//  Created by Timothy Moose on 6/17/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine

public extension Publisher {
    /// Converts publisher of `Output` to publisher of `Output?`.
    func asOptional() -> AnyPublisher<Output?, Failure> {
        map { $0 as Output? }.eraseToAnyPublisher()
    }
}

public extension Publisher where Self.Failure == Never {
    /// An alternative to `assign(to:on:)` that doesn't cause a retain cycle.
    func assignWeak<Root>(
        to keyPath: ReferenceWritableKeyPath<Root, Self.Output>,
        on object: Root
    ) -> AnyCancellable where Root: AnyObject {
        sink { [weak object] value in object?[keyPath: keyPath] = value }
    }
}

public extension Publisher where Output: SuccessConvertible {
    /// Converts publisher of `Result<Success, Failure>` to publisher of `Success`.
    func success() -> AnyPublisher<Output.Success, Failure> {
        compactMap(\.success).eraseToAnyPublisher()
    }
}

public extension Publisher where Output: FailureConvertible {
    /// Converts publisher of `Result<Success, Failure>` to publisher of `Success`.
    func failure() -> AnyPublisher<Output.Failure, Failure> {
        compactMap(\.failure).eraseToAnyPublisher()
    }
}

public extension Publisher where Output: SuccessConvertible & FailureConvertible {
    /// Maps a result type to another result type. In other words, converts a publisher of  `Result<Success, Failure>`
    /// to publisher of `Result<MappedSuccess, Failure>`. This is useful when a view model needs to map
    /// the output of a repository to another data structure.
    func mapSuccess<MappedSuccess>(
        _ map: @escaping (Output.Success) -> MappedSuccess
    ) -> AnyPublisher<Result<MappedSuccess, Output.Failure>, Self.Failure> {
        compactMap { output in
            if let success = output.success {
                return .success(map(success))
            } else if let failure = output.failure {
                return .failure(failure)
            } else {
                return nil
            }
        }
        .eraseToAnyPublisher()
    }
}
