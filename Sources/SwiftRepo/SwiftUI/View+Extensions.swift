//
//  View+Extensions.swift
//  SwiftRepo
//
//  Created by Timothy Moose on 1/6/26.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<Transformed: View>(
        _ condition: Bool,
        transform: (Self) -> Transformed
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
