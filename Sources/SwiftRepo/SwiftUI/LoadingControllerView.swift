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

    public typealias Refresh = () async -> Void

    /// Create a loading controller view with custom content, loading, error and empty views.
    public init(
        state: LoadingController<DataType>.State,
        shouldPresentAlert: Bool = true,
        refresh: Refresh?,
        @ViewBuilder content: @escaping (DataType, Binding<(any UIError)?>) -> Content,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder errorContent: @escaping (any UIError) -> ErrorContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) {
        self.state = state
        self.shouldPresentAlert = shouldPresentAlert
        self.refresh = refresh
        self.content = content
        self.loadingContent = loadingContent
        self.errorContent = errorContent
        self.emptyContent = emptyContent
    }

    // MARK: - Constants

    // MARK: - Variables

    private let state: LoadingController<DataType>.State
    private let shouldPresentAlert: Bool
    private let refresh: Refresh?
    @ViewBuilder private let content: (DataType, Binding<(any UIError)?>) -> Content
    @ViewBuilder private let errorContent: (any UIError) -> ErrorContent
    @ViewBuilder private let emptyContent: () -> EmptyContent
    @ViewBuilder private let loadingContent: () -> LoadingContent
    @State private var loadedErrorData: (any UIError)?

    // MARK: - Body

    public var body: some View {
        loadingControllerView
            .onChange(of: state) { loadedErrorData = state.loadedIndispensableUIError }
    }

    private var loadingControllerView: some View {
        ZStack {
            switch state {
            case let .loading(isHidden):
                loadingContent().opacity(isHidden ? 0 : 1)
            case let .loaded(data, _, _):
                content(data, $loadedErrorData)
            case .empty:
                switch state.uiError {
                case let data?: errorContent(data)
                case .none: emptyContent()
                }
            }
        }
        // Make this view greedy so that it occupies the same space across all loading states.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // This keeps animations together if new animations are created while other animations are in progress.
        .geometryGroup()
        .animation(.default, value: state)
        .refreshable {
            await refresh?()
        }
    }
}

struct LoadingControllerView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingControllerView(
            state: .loaded("Loaded", nil, isUpdating: false),
            refresh: {},
            content: { data, _ in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { _ in Text("Error!") },
            emptyContent: { EmptyView() }
        )
        LoadingControllerView(
            state: .loading(isHidden: false),
            refresh: {},
            content: { (data: String, _) in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { _ in Text("Error!") },
            emptyContent: { EmptyView() }
        )
        LoadingControllerView(
            state: .empty(nil),
            refresh: {},
            content: { (data: String, _) in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { _ in Text("Error!") },
            emptyContent: { EmptyView() }
        )
        LoadingControllerView(
            state: .empty(NSError(domain: "foo", code: URLError.Code.timedOut.rawValue, userInfo: nil)),
            refresh: {},
            content: { (data: String, _) in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { _ in Text("Error!") },
            emptyContent: { EmptyView() }
        )
    }
}
