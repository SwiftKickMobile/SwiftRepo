//
//  AsyncLocked.swift
//  SwiftRepo
//
//  Created by Timothy Moose on 6/22/25.
//

@attached(peer, names: arbitrary)
public macro AsyncLocked() = #externalMacro(module: "SwiftRepoMacros", type: "AsyncLockedMacro")
