//
//  LoadingControllerView+Extensions.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI
import SwiftRepo
import Core

public extension LoadingControllerView where LoadingContent == LoadingView, ErrorContent == LoadingErrorView, EmptyContent == LoadingEmptyView, UIErrorType == DemoUIError {
    /// Makes a `LoadingControllerView` using this app's standard standard loading, error and empty views.
    init(
        state: LoadingController<DataType>.State,
        refresh: (any Refreshable<UIErrorType>)?,
        @ViewBuilder content: @escaping (DataType, Binding<UIErrorType?>) -> Content
    ) {
        self.init(
            state: state,
            refresh: refresh,
            content: content,
            loadingContent: { LoadingView() },
            errorContent: { error in LoadingErrorView(error: error, retry: refresh) },
            emptyContent: { LoadingEmptyView(retry: refresh) }
        )
    }
}
