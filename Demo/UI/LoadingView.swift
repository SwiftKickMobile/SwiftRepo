//
//  LoadingView.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI

public struct LoadingView: View {

    // MARK: - API

    public init() {}

    // MARK: - Constants

    // MARK: - Variables

    // MARK: - Body

    public var body: some View {
        ProgressView()
            .scaleEffect(CGSizeMake(1.5, 1.5))
    }
}

#Preview {
    LoadingView()
}
