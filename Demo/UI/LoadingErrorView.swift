//
//  LoadingErrorView.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI
import SwiftRepo
import Core

public struct LoadingErrorView: View {

    // MARK: - API

    public typealias Retry = any Refreshable<DemoUIError>

    public let error: DemoUIError
    public let retry: Retry?

    // MARK: - Constants

    // MARK: - Variables

    // MARK: - Body

    public var body: some View {
        VStack {
            Image(systemName: error.symbolName)
                .font(.title)
                .foregroundColor(.red)
            Text(error.title)
                .font(.title)
            Text(error.message)
                .font(.body)
            if error.isRetryable, let retry {
                Spacer().frame(height: 40)
                Button("Retry") {
                    Task {
                        await retry.refresh(retryError: error)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    LoadingErrorView(
        error: DemoUIError(
            symbolName: "exclamationmark.triangle.fill",
            title: "Oops!",
            message: "Something bad happened.",
            isRetryable: true
        ),
        retry: nil
    )
}
