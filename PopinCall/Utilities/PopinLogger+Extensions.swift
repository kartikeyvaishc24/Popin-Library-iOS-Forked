//
//  PopinLogger+Extensions.swift
//  PopinCall
//

import Foundation

extension PopinLogger {
    static func debug(_ message: String) {
        PopinLogger.shared.log("DEBUG: \(message)")
    }
}
