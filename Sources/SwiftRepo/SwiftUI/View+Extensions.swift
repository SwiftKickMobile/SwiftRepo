//
//  View+Extensions.swift
//  SwiftRepo
//
//  Created by Carlos De La Mora on 12/4/24.
//

import SwiftUI

extension View {
    func viewAsArgument(@ViewBuilder modifier:(Self) -> some View) -> some View {
        modifier(self)
    }
}
