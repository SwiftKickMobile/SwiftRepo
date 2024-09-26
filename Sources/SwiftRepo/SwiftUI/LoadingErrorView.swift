//
//  Created by Timothy Moose on 2/2/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import SwiftUI
import Core

/// The default error view to use with title, message and retry button.
public struct LoadingErrorView: View {
    // MARK: - API

    public typealias Retry = () async -> Void

    public init(error: UIError, retry: Retry?) {
        self.error = error
        self.retry = retry
    }

    // MARK: - Constants

    // MARK: - Variables

    private let error: UIError
    private let retry: Retry?

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 4) {
            Text("TODO REPO")
//            BodyLargeSemiboldText(viewModel.title)
//            BodyMediumRegularText(viewModel.message)
//                .padding(.bottom, 20)
//            if viewModel.isRetryable {
//                RetryButton(title: viewModel.buttonTitle) {
//                    Task {
//                        await viewModel.retryTapped()
//                    }
//                }
//            }
        }
        .multilineTextAlignment(.center)
        .padding(30)
        // Make the size greedy be default. The expected typical use case is that the view can take all of the available space and
        // we've run into cases where non-greedy behavior caused problems. If non-greedy behavior is needed, this frame setting
        // can be overridden by the host view.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Retry

    private func retryTapped() {
        Task {
            await retry?()
        }
    }
}

/// The retry button. This can be converted into a CoreUI button, but first we need a solution
/// for importing localization store into CoreUI.
private struct RetryButton: View {
    // MARK: - API

    public init(title: String, action: @escaping () -> Void) {
        self.action = action
        self.title = title
    }

    // MARK: - Constants

    // MARK: - Variables

    private let action: () -> Void
    private let title: String

    public var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Text("TODO REPO")
//                SymbolView(
//                    symbol: .arrowClockwise,
//                    fontSize: 20,
//                    frameSize: CGSize(width: 20, height: 20)
//                )
//                StyledText(title, typeStyle: .buttonLarge)
            }
        }
        .buttonStyle(RetryButtonStyle())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

private struct RetryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
// Text("TODO REPO")
//            .foregroundColor(
//                configuration.isPressed
//                    ? Color.peacePress
//                    : Color.peaceDefault
//            )
    }
}

struct LoadingErrorView_Previews: PreviewProvider {
    static var previews: some View {
        let error = UIError(
            message: "There was an error. Please tap the button to try again.",
            title: "Error Message Title",
            image: Image(""), // TODO REPO
            isRetryable: true
        )
        return LoadingErrorView(error: error) {}
    }
}
