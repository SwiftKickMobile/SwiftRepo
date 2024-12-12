//
//  Created by Timothy Moose on 2/2/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import Combine
import SwiftUI
import SwiftRepoCore

/// Pairs with `LoadingController` to display loading, error and empty states.
public struct LoadingControllerView<DataType, Content, LoadingContent, ErrorContent, EmptyContent, UIErrorType: UIError>: View
where DataType: SyncEmptyable & Equatable, Content: View, LoadingContent: View, ErrorContent: View, EmptyContent: View {

    // MARK: - API

    public init(
        state: LoadingController<DataType>.State,
        refresh: (any Refreshable<UIErrorType>)?,
        @ViewBuilder content: @escaping (DataType, Binding<UIErrorType?>) -> Content,
        @ViewBuilder loadingContent: @escaping () -> LoadingContent,
        @ViewBuilder errorContent: @escaping (UIErrorType) -> ErrorContent,
        @ViewBuilder emptyContent: @escaping () -> EmptyContent
    ) {
        self.state = state
        self.refresh = refresh
        self.content = content
        self.loadingContent = loadingContent
        self.errorContent = errorContent
        self.emptyContent = emptyContent
    }

    // MARK: - Constants

    // MARK: - Variables

    private let state: LoadingController<DataType>.State
    private let refresh: (any Refreshable<UIErrorType>)?
    @ViewBuilder private let content: (DataType, Binding<UIErrorType?>) -> Content
    @ViewBuilder private let errorContent: (UIErrorType) -> ErrorContent
    @ViewBuilder private let emptyContent: () -> EmptyContent
    @ViewBuilder private let loadingContent: () -> LoadingContent
    @State private var loadedErrorData: (UIErrorType)?

    // MARK: - Body

    public var body: some View {
        loadingControllerView
            .onChange(of: state) { _ in
                loadedErrorData = state.loadedIndispensableUIError as? UIErrorType }
    }

    private var loadingControllerView: some View {
        ZStack {
            switch state {
            case let .loading(isHidden):
                loadingContent().opacity(isHidden ? 0 : 1)
            case let .loaded(data, _, _):
                content(data, $loadedErrorData)
            case .empty:
                if let error = state.uiError as? UIErrorType {
                    errorContent(error)
                } else {
                    emptyContent()
                }
            }
        }
        // Make this view greedy so that it occupies the same space across all loading states.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .map { view in
            if #available(iOS 17, *) {
                // This keeps animations together if new animations are created while other animations are in progress.
                view.geometryGroup()
            } else {
                view.transformEffect(.identity)
            }
        }
        .animation(.default, value: state)
        .refreshable { [weak refresh] in
            await refresh?.refresh(retryError: nil)
        }
    }
}

struct LoadingControllerView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingControllerView(
            state: .loaded("Loaded", nil, isUpdating: false),
            refresh: nil,
            content: { data, _ in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { (_: DefaultUIError) in Text("Error!") },
            emptyContent: { EmptyView() }
        )
        LoadingControllerView(
            state: .loading(isHidden: false),
            refresh: nil,
            content: { (data: String, _) in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { (_: DefaultUIError) in Text("Error!") },
            emptyContent: { EmptyView() }
        )
        LoadingControllerView(
            state: .empty(nil),
            refresh: nil,
            content: { (data: String, _) in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { (_: DefaultUIError) in Text("Error!") },
            emptyContent: { EmptyView() }
        )
        LoadingControllerView(
            state: .empty(NSError(domain: "foo", code: URLError.Code.timedOut.rawValue, userInfo: nil)),
            refresh: nil,
            content: { (data: String, _) in
                Text(data)
            },
            loadingContent: { Text("Loading") },
            errorContent: { (_: DefaultUIError) in Text("Error!") },
            emptyContent: { EmptyView() }
        )
    }
}
