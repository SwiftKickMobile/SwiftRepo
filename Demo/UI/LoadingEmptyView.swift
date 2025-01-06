//
//  EmptyView.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI
import SwiftRepo
import Core

public struct LoadingEmptyView: View {

    // MARK: - API

    public typealias Retry = any Refreshable<DemoUIError>

    public let retry: Retry?

    // MARK: - Constants

    // MARK: - Variables

    // MARK: - Body

    public var body: some View {
        VStack {
            Image(systemName: "tray")
                .font(.title)
                .foregroundStyle(.secondary)
            Text("No Content")
                .font(.title)
            Text("Please try again later.")
                .font(.body)
                .foregroundStyle(.secondary)
            if let retry {
                Spacer().frame(height: 40)
                Button("Retry") {
                    Task {
                        await retry.refresh(retryError: nil)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

#Preview {
    LoadingEmptyView(retry: nil)
}
