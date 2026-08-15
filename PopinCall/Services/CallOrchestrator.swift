//
//  CallOrchestrator.swift
//  PopinCall
//

import Foundation

/// Owns the call lifecycle state machine for outgoing calls.
/// Communicates upward via closures — never references Popin.shared.
class CallOrchestrator: CallAcceptanceListener {

    private let popinPresenter: PopinPresenter
    private var waitHandler: CallAcceptanceWaitHandler?
    private(set) var callStarted: Bool = false

    // MARK: - Event callbacks (set by Popin facade)

    /// Called when the outgoing call API succeeds and the call is initiated.
    var onCallStart: ((Int) -> Void)?
    /// Called when the SDK successfully connects to the call room.
    var onCallConnected: (() -> Void)?
    /// Called when the call fails at any point.
    var onCallFailed: (() -> Void)?
    /// Called when the outgoing call is missed (timeout or rejected).
    var onCallWasMissed: (() -> Void)?
    /// Called with the updated queue position.
    var onQueuePositionDidChange: ((Int) -> Void)?

    // MARK: - UI callbacks (set by Popin facade, forwarded to CallUICoordinator)

    /// Called to present the outgoing call VC immediately (before the API returns).
    var onPresentOutgoingVC: (() -> Void)?
    /// Called with the callQueueId once the start-call API returns successfully.
    var onUpdateCallQueueId: ((Int) -> Void)?
    /// Called with TalkModel when an existing VC should load the call.
    var onLoadCallInExistingVC: ((TalkModel) -> Void)?
    /// Called with TalkModel when no VC exists and a new one must be presented.
    var onPresentNewCallVC: ((TalkModel) -> Void)?
    /// Called with an error message when the current VC should be closed.
    var onCloseCurrentVC: ((String) -> Void)?
    /// Called to update queue position label in the existing VC.
    var onUpdateQueuePosition: ((Int) -> Void)?
    /// Called when the call is missed and the VC should handle it.
    var onCallMissedInVC: (() -> Void)?
    /// Returns true if there is an active call VC currently displayed.
    var currentCallVCExists: (() -> Bool)?

    // MARK: - Init

    init(popinPresenter: PopinPresenter) {
        self.popinPresenter = popinPresenter
    }

    // MARK: - Outgoing Call

    func startCall(sellerToken: Int, meta: [String: String]) {
        callStarted = true
        PopinLogger.shared.log("CallOrchestrator.startCall()")

        // Show connecting screen immediately, in parallel with the network request
        DispatchQueue.main.async {
            self.onPresentOutgoingVC?()
        }

        popinPresenter.startConnection(seller_id: sellerToken, campaign: meta, onSuccess: { [weak self] callQueueId, callId in
            guard let self, self.callStarted else {
                PopinLogger.shared.log("CallOrchestrator.startCall: Cancelled before API returned")
                return
            }
            PopinLogger.shared.log("CallOrchestrator.startCall: API success, queueId=\(callQueueId), callId=\(callId)")
            if callId != 0 {
                self.onCallStart?(callId)
            }
            DispatchQueue.main.async {
                self.onUpdateCallQueueId?(callQueueId)
            }
            self.startWaiting(callQueueId: callQueueId)
        }, onFailure: { [weak self] in
            PopinLogger.shared.log("CallOrchestrator.startCall: API failed")
            self?.callStarted = false
            self?.onCallFailed?()
            DispatchQueue.main.async {
                self?.onCloseCurrentVC?("")
            }
        })
    }

    func cancelCall() {
        PopinLogger.shared.log("CallOrchestrator.cancelCall()")
        waitHandler?.stopWaitingForAcceptance()
        waitHandler = nil
        callStarted = false
    }

    func cleanUp() {
        callStarted = false
        waitHandler?.stopWaitingForAcceptance()
        waitHandler = nil
    }

    // MARK: - Connection

    func connectToCall(callId: Int) {
        PopinLogger.shared.log("CallOrchestrator.connectToCall: callId=\(callId)")
        popinPresenter.getCallDetails(callId: callId, onSuccess: { [weak self] talkModel in
            guard let self = self else { return }
            PopinLogger.shared.log("CallOrchestrator.connectToCall: Got details — talkModel.id=\(talkModel.id ?? -1), websocket=\(talkModel.websocket ?? "nil"), hasAccessToken=\(talkModel.access_token != nil)")
            self.onCallConnected?()
            DispatchQueue.main.async {
                let hasExistingVC = self.currentCallVCExists?() ?? false
                PopinLogger.shared.log("CallOrchestrator.connectToCall: hasExistingVC=\(hasExistingVC), onLoadCallInExistingVC=\(self.onLoadCallInExistingVC != nil), onPresentNewCallVC=\(self.onPresentNewCallVC != nil)")
                if hasExistingVC {
                    self.onLoadCallInExistingVC?(talkModel)
                } else {
                    self.onPresentNewCallVC?(talkModel)
                }
            }
        }, onFailure: { [weak self] in
            PopinLogger.shared.log("CallOrchestrator.connectToCall: Failed to get call details")
            self?.onCallFailed?()
            DispatchQueue.main.async {
                self?.onCloseCurrentVC?("Failed to connect to call")
            }
        })
    }

    // MARK: - Widget Call (direct connect via URL)

    func startWidgetCall(url: String) {
        callStarted = true
        PopinLogger.shared.log("CallOrchestrator.startWidgetCall(url: \(url))")

        popinPresenter.getWidgetCall(url: url, onSuccess: { [weak self] talkModel in
            guard let self, self.callStarted else {
                PopinLogger.shared.log("CallOrchestrator.startWidgetCall: Cancelled before API returned")
                return
            }
            PopinLogger.shared.log("CallOrchestrator.startWidgetCall: Got details — talkModel.id=\(talkModel.id ?? -1)")
            if let callId = talkModel.id, callId != 0 {
                self.onCallStart?(callId)
            }
            self.onCallConnected?()
            DispatchQueue.main.async {
                let hasExistingVC = self.currentCallVCExists?() ?? false
                if hasExistingVC {
                    self.onLoadCallInExistingVC?(talkModel)
                } else {
                    self.onPresentNewCallVC?(talkModel)
                }
            }
        }, onFailure: { [weak self] in
            PopinLogger.shared.log("CallOrchestrator.startWidgetCall: API failed")
            self?.callStarted = false
            self?.onCallFailed?()
        })
    }

    // MARK: - CallAcceptanceListener

    func onQueuePositionChange(position: Int) {
        onQueuePositionDidChange?(position)
        DispatchQueue.main.async { [weak self] in
            self?.onUpdateQueuePosition?(position)
        }
    }

    func onCallAccepted(callId: Int) {
        PopinLogger.shared.log("CallOrchestrator.onCallAccepted: callId=\(callId)")
        waitHandler = nil
        connectToCall(callId: callId)
    }

    func onCallMissed() {
        PopinLogger.shared.log("CallOrchestrator.onCallMissed() — onCallWasMissed=\(onCallWasMissed != nil ? "set" : "nil"), onCallMissedInVC=\(onCallMissedInVC != nil ? "set" : "nil")")
        waitHandler = nil
        onCallWasMissed?()
        DispatchQueue.main.async { [weak self] in
            self?.onCallMissedInVC?()
        }
    }

    // MARK: - Private

    private func startWaiting(callQueueId: Int) {
        waitHandler?.stopWaitingForAcceptance()
        waitHandler = CallAcceptanceWaitHandler(callQueueId: callQueueId, listener: self)
        waitHandler?.startWaitingForAcceptance()
    }
}
