//
//  ModelStoreMergeStrategy.swift
//  SwiftRepo
//
//  Created by Carter Foughty on 10/16/24.
//

import Foundation

public enum ModelStoreMergeStrategy {
    /// Adds or updates models. Existing models that aren't in the current result set remain untouched.
    /// Use this strategy when the result set represents an incremental update, such as new and modified records.
    case upsertAppend

    /// Adds or updates models. Removes any models that aren't in the current result set.
    /// Use this option when the result set represents the entire data set.
    case upsertTrim
}
