//
//  ErrorBanner.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import Core
import SwiftUI
import API

public struct ErrorBannerView: View {

    // MARK: - API

    public init(error: DemoUIError) {
        self.error = error
    }

    // MARK: - Constants

    // MARK: - Variables

    private let error: DemoUIError

    // MARK: - Body

    public var body: some View {
        VStack {
            HStack {
                Image(systemName: error.symbolName)
                    .font(.title)
                    .foregroundColor(.red)
                Text(error.title)
                    .font(.title)
            }
            Text(error.message)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 10).fill(.white)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 2)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ErrorBannerView(
        error: DemoUIError(
            symbolName: "exclamationmark.triangle.fill",
            title: "Oops!",
            message: "Something bad happened.",
            isRetryable: true
        )
    )
}
