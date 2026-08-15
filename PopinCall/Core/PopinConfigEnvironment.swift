//
//  PopinConfigEnvironment.swift
//  PopinCall
//

import SwiftUI

/// Wraps PopinConfig for SwiftUI environment injection.
class PopinConfigHolder: ObservableObject {
    let config: PopinConfig

    init(config: PopinConfig) {
        self.config = config
    }
}
