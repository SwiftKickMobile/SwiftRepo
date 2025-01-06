//
//  ItemView.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import SwiftUI
import API

struct ItemView: View {

    // MARK: - API

    let item: Item

    // MARK: - Constants

    // MARK: - Variables

    // MARK: - Body

    var body: some View {
        Text(item.text)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.black.opacity(0.025))
            .cornerRadius(10)
    }
}

#Preview {
    ItemView(item: Item.Fixtures.item1)
}
