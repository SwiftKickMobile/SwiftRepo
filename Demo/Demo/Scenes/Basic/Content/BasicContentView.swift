//
//  BasicContentView.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI
import SwiftRepo
import SwiftMessages
import Repo
import API
import UI

struct BasicContentView: View {

    // MARK: - API

    init(config: BasicRepoConfig) {
        _viewModel = StateObject(wrappedValue: BasicContentViewModel(config: config))
    }

    // MARK: - Constants

    // MARK: - Variables

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BasicContentViewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            LoadingControllerView(state: viewModel.loadingState, refresh: viewModel) { model, error in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        Text("Pull-to-refresh to update content.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        LazyVStack {
                            ForEach(model.items) { item in
                                ItemView(item: item)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Basic Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .swiftMessage(message: $viewModel.error) { error in
                ErrorBannerView(error: error)
            }
            .task {
                await viewModel.appeared()
            }
        }
    }
}

#Preview {
    BasicContentView(
        config: BasicRepoConfig(
            strategy: .ifNotStored,
            loadingBehavior: .init(delay: 0, minimumDuration: 0),
            responses: [
                .makeValue(BasicModel.Fixtures.model1)
            ]
        )
    )
}
