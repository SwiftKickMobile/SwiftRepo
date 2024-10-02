//
//  RandomNumberGeneratorWithSeed.swift
//  BootstrapCore
//
//  Created by Timothy Moose on 11/22/23.
//  Copyright © 2023 SwiftKick Mobile. All rights reserved.
//

import Foundation
import GameplayKit

public struct RandomNumberGeneratorWithSeed: RandomNumberGenerator {
    public mutating func next() -> UInt64 {
        // GKRandom produces values in [INT32_MIN, INT32_MAX] range; hence we need two numbers to produce 64-bit value.
        let next1 = UInt64(bitPattern: Int64(gkrandom.nextInt()))
        let next2 = UInt64(bitPattern: Int64(gkrandom.nextInt()))
        return next1 ^ (next2 << 32)
    }

    public init(seed: UInt64) {
        gkrandom = GKMersenneTwisterRandomSource(seed: seed)
    }

    private let gkrandom: GKRandom
}
