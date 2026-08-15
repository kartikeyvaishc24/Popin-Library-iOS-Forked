//
//  PopinEventsListener.swift
//  PopinCall
//
//  Created by Ashwin Nath on 15/11/22.
//

import Foundation

public protocol PopinEventsListener: AnyObject {
    func onPermissionGiven()
    func onPermissionDenied()
    func onCallStart(callID: Int)
    func onCallAbandoned()
    func onQueuePositionChanged(position: Int)
    func onCallMissed()
    func onCallNetworkFailure(participant: String)
    func onCallConnected()
    func onCallFailed()
    func onCallEnd()
    func onPipStateChanged(isPipModeActive: Bool)
}

public extension PopinEventsListener {
    // Default no-op so existing conformers don't break when new events are added.
    func onPipStateChanged(isPipModeActive: Bool) {}
}
