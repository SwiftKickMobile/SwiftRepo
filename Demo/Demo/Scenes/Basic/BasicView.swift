//
//  BasicView.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI

struct BasicView: View {

    // MARK: - API

    // MARK: - Constants

    // MARK: - Variables

    @StateObject private var viewModel = BasicViewModel()

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Response time
                VStack(spacing: 10) {
                    Text("Response Time")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Select Time Interval", selection: $viewModel.reseponseTime) {
                        Text("0.2s").tag(0.2)
                        Text("0.5s").tag(0.5)
                    }
                    Text("Change response time to see effect of indefinite loading behavior. The indefinite delay is set to \(viewModel.indefiniteDelay.formatted(.number.precision(.fractionLength(2)))) seconds.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Use case
                VStack(spacing: 10) {
                    Text("Use Case")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Picker("Select a Use Case", selection: $viewModel.useCase) {
                        Text("Happy Path").tag(BasicViewModel.UseCase.happy)
                        Text("Empty State").tag(BasicViewModel.UseCase.empty)
                        Text("Error State").tag(BasicViewModel.UseCase.error)
                        Text("Error Banner").tag(BasicViewModel.UseCase.refreshError)
                    }
                    Text(viewModel.useCase.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                Button("Show", action: viewModel.showTapped)
                    .buttonStyle(.bordered)
            }
            .padding()
            .navigationTitle("Basic")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $viewModel.route) { route in
                switch route {
                case .content: BasicContentView(config: viewModel.config)
                }
            }
        }
    }
}

#Preview {
    BasicView()
}

extension BasicViewModel.UseCase {
    var description: String {
        switch self {
        case .happy:
            "Loads an initial result. Loads a different result on pull-to-refresh."
        case .empty:
            "Loads an empty result. Loads a non-empty result on retry."
        case .error:
            "Initially receives an error response. Loads a result on retry."
        case .refreshError:
            "Loads an initial result. Receives an error on pull-to-refresh. Loads a different result on second pull-to-refresh."
        }
    }
}
