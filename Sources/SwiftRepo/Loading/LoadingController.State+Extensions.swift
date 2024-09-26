//
//  LoadingController.State+Extensions.swift
//  BootstrapRepository
//
//  Created by Timothy Moose on 4/14/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Core

public extension LoadingController.State {
    
    var isLoading: Bool {
        switch self {
        case .loading: return true
        default: return false
        }
    }

    var isEmpty: Bool {
        switch self {
        case .empty: return true
        default: return false
        }
    }

    var data: DataType? {
        switch self {
        case let .loaded(data, _, _): return data
        case .loading, .empty: return nil
        }
    }

    var error: Error? {
        switch self {
        case let .loaded(_, error, _): return error
        case let .empty(error): return error
        default: return nil
        }
    }

    var uiError: UIError? {
        guard let appError = error as? (any AppError),
              let uiError = appError.uiError else {
            return nil
        }
        return uiError
    }

    var loadedIndispensableUIError: UIError? {
        switch self {
        case .loaded:
            guard let appError = error as? any AppError,
                  appError.intent == .indispensable,
                  let uiError = appError.uiError else {
                return nil
            }
            return uiError
        default: return nil
        }
    }

    var isHidden: Bool {
        switch self {
        case let .loading(isHidden): return isHidden
        default: return false
        }
    }

    /// Convenience property which allows us to ignore the associated values in all conditionals.
    var isLoaded: Bool {
        switch self {
        case .loaded(_, _, isUpdating: _): return true
        default: return false
        }
    }

    /// Convenience property to determine if `LoadingController` is updating.
    var isUpdating: Bool {
        switch self {
        case let .loaded(_, _, isUpdating): return isUpdating
        default: return false
        }
    }
}
