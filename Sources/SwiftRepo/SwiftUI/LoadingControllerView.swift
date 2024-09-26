//
//  Created by Timothy Moose on 2/2/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import SwiftUI
import Core

/// A compaining view to be used with `LoadingController` that provides default loading, error and empty
/// states and state transitions. The loading, error and empty states may be customized if needed.
public struct LoadingControllerView<DataType, Content, LoadingContent, ErrorContent, EmptyContent>: View
    where DataType: Emptyable & Equatable, Content: View, LoadingContent: View, ErrorContent: View, EmptyContent: View {
    
    // MARK: - API

    public typealias Retry = () async -> Void
    public typealias ContentClosure = (DataType, UIError?, Bool) -> Content

    /// Create a loading controller view with custom content. Uses default loading, error, and empty views.
    public init(
        state: LoadingController<DataType>.State,
        shouldPresentAlert: Bool = true,
        retry: Retry?,
        @ViewBuilder content: @escaping ContentClosure
    ) where LoadingContent == LoadingView, ErrorContent == LoadingErrorView, EmptyContent == EmptyView {
        self.state = state
        self.shouldPresentAlert = shouldPresentAlert
        self.content = content
        loadingContent = { LoadingView() }
        errorContent = { LoadingErrorView(error: $0, retry: retry) }
        emptyContent = { EmptyView() }
    }

    /// Create a loading controller view with custom content and empty view. Uses default loading and error views.
    public init(
        state: LoadingController<DataType>.State,
        shouldPresentAlert: Bool = true,
        retry: Retry?,
        @ViewBuilder content: @escaping ContentClosure,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) where LoadingContent == LoadingView, ErrorContent == LoadingErrorView {
        self.state = state
        self.shouldPresentAlert = shouldPresentAlert
        self.content = content
        self.emptyContent = emptyContent
        loadingContent = { LoadingView() }
        errorContent = { LoadingErrorView(error: $0, retry: retry) }
    }

    /// Create a loading controller view with custom content and loading view. Uses default error and empty views.
    public init(
        state: LoadingController<DataType>.State,
        shouldPresentAlert: Bool = true,
        retry: Retry?,
        @ViewBuilder content: @escaping ContentClosure,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent
    ) where ErrorContent == LoadingErrorView, EmptyContent == EmptyView {
        self.state = state
        self.shouldPresentAlert = shouldPresentAlert
        self.content = content
        self.loadingContent = loadingContent
        errorContent = { LoadingErrorView(error: $0, retry: retry) }
        emptyContent = { EmptyView() }
    }

    /// Create a loading controller view with custom content, loading, error and empty views.
    public init(
        state: LoadingController<DataType>.State,
        shouldPresentAlert: Bool = true,
        retry: Retry?,
        @ViewBuilder content: @escaping ContentClosure,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) where ErrorContent == LoadingErrorView {
        self.state = state
        self.shouldPresentAlert = shouldPresentAlert
        self.content = content
        self.loadingContent = loadingContent
        errorContent = { LoadingErrorView(error: $0, retry: retry) }
        self.emptyContent = emptyContent
    }

    /// Create a loading controller view with custom content, loading, error and empty views.
    public init(
        state: LoadingController<DataType>.State,
        shouldPresentAlert: Bool = true,
        @ViewBuilder content: @escaping ContentClosure,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder errorContent: @escaping (UIError) -> ErrorContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) {
        self.state = state
        self.shouldPresentAlert = shouldPresentAlert
        self.content = content
        self.loadingContent = loadingContent
        self.errorContent = errorContent
        self.emptyContent = emptyContent
    }

    // MARK: - Constants

    // MARK: - Variables

    private let state: LoadingController<DataType>.State
    private let shouldPresentAlert: Bool
    @ViewBuilder private let content: ContentClosure
    @ViewBuilder private let errorContent: (UIError) -> ErrorContent
    @ViewBuilder private let emptyContent: () -> EmptyContent
    @ViewBuilder private let loadingContent: () -> LoadingContent

    // MARK: - Body

    public var body: some View {
        loadingControllerView
//            .if(shouldPresentAlert) { view in
//            Text("TODO REPO")
// Need a solution for this that doesn't explicitly depend on SwiftMessages
//            view.loadedAlert(state: state)
//        }
    }

    private var loadingControllerView: some View {
        ZStack {
            switch state {
            case let .loading(isHidden):
                loadingContent().opacity(isHidden ? 0 : 1)
            case let .loaded(data, error, isUpdating):
                content(data, state.uiError, isUpdating)
            case .empty:
                switch state.uiError {
                case let data?: errorContent(data)
                case .none: emptyContent()
                }
            }
        }
        // This resolves a SwiftUI bug (still around as of iOS 17) with async animations by effectively
        // forcing the content view to be nested in a `UIView` in the UIKit rendering engine.
        .transformEffect(/*@START_MENU_TOKEN@*/.identity/*@END_MENU_TOKEN@*/)
        .animation(.default, value: state)
    }
}

struct LoadingControllerView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingControllerView(
            state: .loaded("Loaded", nil, isUpdating: false),
            retry: {},
            content: { data, error, isUpdating in
                Text(data)
            }
        )
        LoadingControllerView(
            state: .loading(isHidden: false),
            retry: {},
            content: { (data: String, error, isUpdating) in
                Text(data)
            }
        )
        LoadingControllerView(
            state: .empty(nil),
            retry: {},
            content: { (data: String, error, isUpdating) in
                Text(data)
            }
        )
        LoadingControllerView(
            state: .empty(
                UIError(message: "Houston, we have a problem.", title: "Error", image: nil, isRetryable: true)
            ),
            retry: {},
            content: { (data: String, error, isUpdating) in
                Text(data)
            }
        )
    }
}
