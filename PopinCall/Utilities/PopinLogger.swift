//
//  PopinLogger.swift
//  PopinCall
//
//  Created by Ashwin Nath.
//

import Foundation
import os

class PopinLogger {

    static let shared = PopinLogger()

    var isEnabled: Bool = false

    private init() {}

    func log(_ message: String) {
        guard isEnabled else { return }
        let logger = Logger(subsystem: "to.popin.PopinCall", category: "lifecycle")
        logger.notice("[Popin] \(message, privacy: .public)")
        print("[Popin Internal] \(message)")
       // NSLog("[Popin] \(message)")
    }
}
