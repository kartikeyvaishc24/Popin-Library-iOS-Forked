//
//  PopinPusherDelegate.swift
//  PopinCall
//
//  Created by Ashwin Nath on 19/11/22.
//

import Foundation
protocol PopinPusherDelegate {
    func onPusherConnected();
    func onAgentConnected();
    func onAllExpertsBusy();
    func onCallConnected();
    func onCallDisconnected();
    func onCallFail();
    func onIncomingCallCancelled(callId: Int);
}
