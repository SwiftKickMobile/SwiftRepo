//
//  DemoUIError+Extensions.swift
//  Demo
//
//  Created by Timothy Moose on 1/5/25.
//

import Core
import SwiftMessages

/// Conforms to SwiftMessage.Identifiable (sorry, this type existed before the one in Foundation).
extension DemoUIError: @retroactive Identifiable {}
