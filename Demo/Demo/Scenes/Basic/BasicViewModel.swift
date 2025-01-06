//
//  BasicViewModel.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI
import SwiftRepo
import Core
import Repo
import API

enum Route: Hashable, Identifiable {
    case content

    var id: String {
        switch self {
        case .content: return "content"
        }
    }
}

@MainActor
class BasicViewModel: ObservableObject {

    // MARK: - API

    @Published var route: Route?
    @Published var config = BasicRepoConfig()
    @Published var reseponseTime: Double = 0.5
    @Published var queryStrategy: QueryStrategy = .always
    @Published var useCase: UseCase = .happy
    let indefiniteDelay = 0.25

    enum UseCase {
        case happy
        case empty
        case error
        case refreshError
    }

    func showTapped() {
        route = .content
        updateConfig()
    }

    // MARK: - Constants

    // MARK: - Variables

    // MARK: - Helpers

    private func updateConfig() {
        config = BasicRepoConfig(
            strategy: .always,
            loadingBehavior: .init(delay: indefiniteDelay, minimumDuration: 2),
            responses: useCase.responses(reseponseTime: reseponseTime)
        )
    }
}

extension BasicViewModel.UseCase {
    func responses(reseponseTime: Double) -> BasicRepoConfig.Responses {
        switch self {
        case .happy:
            [
                .makeValue(BasicModel.Fixtures.model1, delay: reseponseTime),
                .makeValue(BasicModel.Fixtures.model2, delay: reseponseTime),
            ]
        case .empty:
            [
                .makeValue(BasicModel.Fixtures.model0, delay: reseponseTime),
                .makeValue(BasicModel.Fixtures.model1, delay: reseponseTime),
                .makeValue(BasicModel.Fixtures.model2, delay: reseponseTime),
            ]
        case .error:
            [
                .makeError(APIError(isNotable: false, isRetryable: true, intent: .indispensable), delay: reseponseTime),
                .makeValue(BasicModel.Fixtures.model1, delay: reseponseTime),
                .makeValue(BasicModel.Fixtures.model2, delay: reseponseTime),
            ]
        case .refreshError:
            [
                .makeValue(BasicModel.Fixtures.model1, delay: reseponseTime),
                .makeError(APIError(isNotable: false, isRetryable: true, intent: .indispensable), delay: reseponseTime),
                .makeValue(BasicModel.Fixtures.model2, delay: reseponseTime),
            ]
        }
    }
}
