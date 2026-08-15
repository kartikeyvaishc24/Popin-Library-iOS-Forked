//
//  VideoCallViewModel.swift
//  Popin
//
//  Created by Assistant on 10/09/25.
//

import Foundation
import Combine

final class VideoCallViewModel: ObservableObject {
    @Published var call: TalkModel?
    @Published var callAccepted: Bool = false
    @Published var isUserEndingCall: Bool = false
    @Published var isOnHold: Bool = false

    /// For outgoing calls: true when waiting for the call to be accepted
    @Published var isWaitingForAcceptance: Bool = false

    /// Queue position for outgoing calls (0 means position not yet known)
    @Published var queuePosition: Int = 0

    /// Pre-call microphone state (set during waiting screen, applied when call connects)
    @Published var preCallMicEnabled: Bool = true

    /// Pre-call camera state (set during waiting screen, applied when call connects)
    @Published var preCallCameraEnabled: Bool = true

    // MARK: - Network state tracking (matches Android CallActivity)

    /// Customer's own network issue (tracked via Pusher connection state)
    @Published var hasCustomerNetworkIssue: Bool = false

    /// Seller/agent network issue (tracked via LiveKit connection quality)
    @Published var hasSellerNetworkIssue: Bool = false

    /// Temporarily show "You're back online" when customer network recovers
    @Published var showCustomerBackOnlineMessage: Bool = false

    /// Temporarily show "Expert rejoined" when seller network recovers
    @Published var showSellerRejoinedMessage: Bool = false

    /// Timer tracking how long without qualifying participants (in ms)
    @Published var noQualifyingParticipantsTimer: Int = 0

    var onEndCall: (() -> Void)?
    var onRoomDisconnected: (() -> Void)?
    var onNetworkFailure: ((String) -> Void)?

    /// Called when user cancels during the "Connecting..." phase
    var onCancelCall: (() -> Void)?

    /// Temporarily suppresses .pipDidClose from ending the call during the
    /// waiting-to-connected PiP transition (camera conflict can crash PiP).
    var suppressPipClose = false
}


