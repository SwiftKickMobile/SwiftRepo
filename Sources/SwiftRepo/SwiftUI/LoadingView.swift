//
//  Created by Timothy Moose on 2/2/22.
//  Copyright © 2022 ZenBusiness PBC. All rights reserved.
//

import SwiftUI

/// The default loading card with circle loading indicator.
public struct LoadingView: View {
    
    // MARK: - API

    public init() {}

    // MARK: - Constants

    // MARK: - Variables

    // MARK: - Body

    public var body: some View {
        ProgressView()
            // Make the size greedy be default. The expected typical use case is that the view can take all of the available space and
            // we've run into cases where non-greedy behavior caused problems. If non-greedy behavior is needed, this frame setting
            // can be overridden by the host view.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
