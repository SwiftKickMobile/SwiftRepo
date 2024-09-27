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

    var uiError: (any UIError)? {
        // The compiler doesn't seem to be able to infer that
        // `appError.uiError` is a `UIError`, so cast it.
        guard let appError = error as? (any AppError) else { return nil }
        return appError.uiError as? any UIError
    }

    var loadedIndispensableUIError: (any UIError)? {
        switch self {
        case .loaded:
            // The compiler doesn't seem to be able to infer that
            // `appError.uiError` is a `UIError`, so cast it.
            guard let appError = error as? (any AppError),
                  appError.intent == .indispensable else { return nil }
            return appError.uiError as? any UIError
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
