//
//  VideoCallController.swift
//  Popin
//
//  Created by Ashwin Nath on 15/03/24.
//

import Foundation
import UIKit
import LiveKit
import AVFAudio
import UIKit
import Combine
import LiveKitWebRTC
import SwiftUI
import LiveKitComponents


protocol VideoCallView: NSObjectProtocol {
    func startLoading()
    func finishLoading()
    func loadCall(call : TalkModel)
    func showMessage(title: String, message: String)
    func closeCall(message: String)
}

class PopinCallViewController: UIViewController {

    // PushKit call data
    var pushCallData: PushCallData?
    var callUUID : UUID? = nil;

    // Computed properties for backward compatibility
    private var _sdkCallId: Int?
    var callId: Int { _sdkCallId ?? pushCallData?.callId ?? 0 }
    var callComponentId: Int { pushCallData?.callComponentId ?? 0 }
    var callRole: Int { pushCallData?.role ?? 0 }
    var customerName: String { pushCallData?.displayName ?? "" }
    var artifact: String { pushCallData?.primaryProductInfo ?? "" }

    /// For outgoing calls: the queue ID used while waiting for acceptance
    var callQueueId: Int?

    /// Indicates this is an outgoing call (started by user via startCall)
    var isOutgoingCall: Bool = false

    var closedCall : Bool = false;
    var callConnected : Bool = false;
    
    // SwiftUI integration
    private var hostingController: UIHostingController<AnyView>?
    private let viewModel = VideoCallViewModel()
    
    private var darwinNotificationCenterObservation: DarwinNotificationObservation?
    private var timer: Timer?
    
    private let videoCallPresenter = VideoCallPresenter(videoCallInteractor: VideoCallInteractor())
    private let popinCallInteractor = PopinCallInteractor()
    var videoCall : VideoCall? = nil
    
    var onCallEnd: (() -> Void)?
    var onNetworkFailure: ((String) -> Void)?
    var onCallAbandoned: (() -> Void)?
    var onCallCancelled: ((Int?) -> Void)?
    var onPipStateChanged: ((Bool) -> Void)?
    var popinConfig: PopinConfig?

    var isAudioEnabled = true, isVideoEnabled = true, isScreenSharing = false
    
    var currentRemoteVideo = "";
    
    private var remoteParticipants = [RemoteParticipant]()
    
    private var cellReference = NSHashTable<ParticipantCell>.weakObjects()
    
    // Track if disconnection was initiated by app logic (button/room event) vs external (CallKit)
    private var isAppInitiatedDisconnect = false
    var shouldSkipEndApi = false
    
    @IBOutlet weak var productLabel: UILabel!
    @IBOutlet weak var callerNameLabel: UILabel!
    
    
    
    
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    @IBAction func acceptClick(_ sender: Any) {
        // Always go through CallKit for consistency
        CallManager.shared.answerCall()
    }

    @IBAction func rejectClick(_ sender: Any) {
        // Always go through CallKit for consistency
        CallManager.shared.endCall()
    }
    
    func handleRemoteCancel() {
        PopinLogger.shared.log("PopinCallVC: handleRemoteCancel: callConnected=\(callConnected), isOutgoingCall=\(isOutgoingCall), closedCall=\(closedCall)")
        shouldSkipEndApi = true
        // Close UI and end CallKit call
        closeViewController(shouldNotEndCX: false)
        DispatchQueue.main.async {
            self.dismiss(animated: true)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        // Delegate is now set in PopinCallManager.handleIncomingCall()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
        timer = nil
        
        // Clean up hosting controller
        if let hostingController = self.hostingController {
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .black

        // Initialize SwiftUI view
        setupSwiftUIView()

        // Keep original setup for compatibility
        videoCallPresenter.attachView(videoCallView: self)
       // callerNameLabel.text = customerName
       // productLabel.text = artifact
        setupNotifications()

        // Set self as CallManager delegate for CallKit callbacks
        CallManager.shared.delegate = self

        // Set up end call callback — captures presenter strongly so the /end
        // API fires even if the VC is deallocated before the closure runs.
        let presenter = self.videoCallPresenter
        viewModel.onEndCall = { [weak self] in
            let callId = self?.callId ?? 0
            PopinLogger.shared.log("PopinCallVC: onEndCall FIRED — callId=\(callId), callConnected=\(self?.callConnected ?? false)")
            self?.isAppInitiatedDisconnect = true
            self?.shouldSkipEndApi = true
            presenter.endCall(callId: callId, onSuccess: {
                DispatchQueue.main.async {
                    PopinLogger.shared.log("PopinCallVC: onEndCall /end API succeeded — cleaning up")
                    CallManager.shared.endCall()
                    self?.closeViewController(shouldNotEndCX: true)
                    self?.dismiss(animated: true)
                }
            }, onFailure: { error in
                DispatchQueue.main.async {
                    PopinLogger.shared.log("PopinCallVC: onEndCall /end API failed (\(error)) — cleaning up anyway")
                    CallManager.shared.endCall()
                    self?.closeViewController(shouldNotEndCX: true)
                    self?.dismiss(animated: true)
                }
            })
        }

        // Set up network failure callback (no qualifying participants for 30 sec)
        viewModel.onNetworkFailure = { [weak self] participant in
            PopinLogger.shared.log("PopinCallVC: onNetworkFailure received (participant=\(participant))")
            self?.onNetworkFailure?(participant)
        }

        // Set up room disconnected callback (room ended externally)
        viewModel.onRoomDisconnected = { [weak self] in
            guard let self = self else { return }
            PopinLogger.shared.log("PopinCallVC: onRoomDisconnected received — closing VC")
            self.isAppInitiatedDisconnect = true
            self.shouldSkipEndApi = true
            DispatchQueue.main.async {
                self.closeViewController(shouldNotEndCX: false)
                self.dismiss(animated: true)
            }
        }

        // Set up cancel call callback (for outgoing calls waiting for acceptance)
        viewModel.onCancelCall = { [weak self] in
            guard let self = self else { return }
            self.isAppInitiatedDisconnect = true

            self.onCallAbandoned?()
            self.onCallCancelled?(self.callQueueId)

            if let queueId = self.callQueueId {
                self.videoCallPresenter.closeScreen(callQueueId: queueId, onSuccess: {
                }, onFailure: { error in
                })
            }

            DispatchQueue.main.async {
                self.closeViewController(shouldNotEndCX: true)
                self.dismiss(animated: true)
            }
        }

        // If this is an outgoing call, set waiting state
        if isOutgoingCall {
            viewModel.isWaitingForAcceptance = true
        }

    }

    
    private func setupSwiftUIView() {
        if popinConfig == nil {
            PopinLogger.shared.log("⚠️ PopinCallVC.setupSwiftUIView: popinConfig is NIL — falling back to default config. hideFlipCameraButton will be false!")
        } else {
            PopinLogger.shared.log("PopinCallVC.setupSwiftUIView: popinConfig.hideFlipCameraButton=\(popinConfig!.hideFlipCameraButton), isOutgoingCall=\(isOutgoingCall)")
        }
        let configHolder = PopinConfigHolder(config: popinConfig ?? PopinConfig.Builder().build())

        let swiftUIView = VideoCallSwiftUIView(
            viewModel: viewModel,
            callId: callId,
            callComponentId: callComponentId,
            callUUID: callUUID,
            callRole: callRole,
            customerName: customerName,
            artifact: artifact
        )
        .environmentObject(configHolder)

        let wrapped = RoomScope(roomOptions: RoomOptions(
            defaultCameraCaptureOptions: CameraCaptureOptions(dimensions: .h720_169),
            defaultScreenShareCaptureOptions: ScreenShareCaptureOptions(dimensions: .h720_169, useBroadcastExtension: true),
            defaultAudioCaptureOptions: AudioCaptureOptions(
                echoCancellation: true,
                autoGainControl: true,
                noiseSuppression: true,
                highpassFilter: true,
                typingNoiseDetection: true
            ),
            defaultVideoPublishOptions: VideoPublishOptions(
                encoding: VideoEncoding(maxBitrate: 1_700_000, maxFps: 30),
                simulcast: true,
                simulcastLayers: [
                    VideoParameters(dimensions: .h180_169, encoding: VideoEncoding(maxBitrate: 160_000, maxFps: 15)),
                    VideoParameters(dimensions: .h360_169, encoding: VideoEncoding(maxBitrate: 450_000, maxFps: 20))
                ],
                screenShareSimulcastLayers: [
                    VideoParameters(dimensions: .h360_169, encoding: VideoEncoding(maxBitrate: 200_000, maxFps: 3))
                ]
            ),
            adaptiveStream: true,
            dynacast: true,
            suspendLocalVideoTracksInBackground: false  // Required for PiP to work
        )) {
            swiftUIView
        }

        hostingController = UIHostingController(rootView: AnyView(wrapped))
        
        guard let hostingController = self.hostingController else { return }
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
    }
    
    

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Disable idle timer to prevent screen from locking
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Re-enable idle timer to allow screen to lock again
        UIApplication.shared.isIdleTimerDisabled = false
    }
    

    
    
    
    
    func setupNotifications() {
        // We need to store the value in variable/state to keep notification active.
      /*  darwinNotificationCenterObservation = DarwinNotificationCenter.shared.addObserver(name: "iOS_BroadcastStopped", callback: notificationCallback) */

        // PiP notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePiPDidStart),
            name: .pipDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePiPDidStop),
            name: .pipDidStop,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePiPDidStop),
            name: .pipDidClose,
            object: nil
        )
    }

    @objc private func handlePiPDidStart() {
        // Hide the view and disable touch interception on all presentation
        // container views so the screen behind becomes interactive during PiP
        self.view.isHidden = true
        var v: UIView? = self.view
        while let current = v?.superview {
            if let window = current as? UIWindow {
                if let ptWindow = window as? PassthroughWindow {
                    // Enable passthrough so touches on empty areas fall
                    // through to the host app's window, while modals
                    // presented in this window (e.g. chat) stay interactive.
                    ptWindow.passthroughEnabled = true
                    // The root VC's view (containerVC) is not in callVC's
                    // superview chain, so the loop above doesn't disable it.
                    // Disable it explicitly so it doesn't claim hits.
                    ptWindow.rootViewController?.view.isUserInteractionEnabled = false
                }
                break
            }
            current.isUserInteractionEnabled = false
            v = current
        }
        onPipStateChanged?(true)
    }

    @objc private func handlePiPDidStop() {
        // Re-enable touch interception on presentation container views
        var v: UIView? = self.view
        while let current = v?.superview {
            if let window = current as? UIWindow {
                if let ptWindow = window as? PassthroughWindow {
                    ptWindow.passthroughEnabled = false
                    ptWindow.rootViewController?.view.isUserInteractionEnabled = true
                }
                break
            }
            current.isUserInteractionEnabled = true
            v = current
        }
        self.view.isHidden = false
        onPipStateChanged?(false)
    }
    
    func closeViewController(shouldNotEndCX: Bool) {
        PopinLogger.shared.log("PopinCallVC: closeViewController: shouldNotEndCX=\(shouldNotEndCX), closedCall=\(closedCall), callConnected=\(callConnected)")
        if closedCall {
            PopinLogger.shared.log("PopinCallVC: closeViewController: Already closed, returning")
            return
        }
        closedCall = true

        if !shouldNotEndCX {
            CallManager.shared.endCall()
        }

        // Unregister delegate to ensure no further callbacks
        if CallManager.shared.delegate === self {
            CallManager.shared.delegate = nil
        }

        CallManager.shared.clearCurrentCall()
        PopinCallManager.shared.clearCallState()

        // Clear chat messages for this call
        if let callId = viewModel.call?.id {
            ChatManager.shared.clearMessages(for: callId)
        }

        // Explicitly remove hosting controller to trigger RoomScope cleanup (LiveKit disconnect)
        if let hostingController = self.hostingController {
            hostingController.willMove(toParent: nil)
            hostingController.view.removeFromSuperview()
            hostingController.removeFromParent()
            self.hostingController = nil
        }

        // Notify that call has ended
        onCallEnd?()
    }
   
}



extension PopinCallViewController: VideoCallView {
    func closeCall(message: String) {
        guard !message.isEmpty else {
            closeViewController(shouldNotEndCX: false)
            dismiss(animated: true)
            return
        }

        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            self.callConnected = false
            self.closeViewController(shouldNotEndCX: false)
        }

        alert.addAction(okAction)

        self.present(alert, animated: true, completion: nil)
    }

    func loadCall(call: TalkModel) {
        PopinLogger.shared.log("PopinCallVC: loadCall — viewIsHidden=\(self.view.isHidden), posting .callWillConnect")
        // Tell the waiting-PiP coordinator to mark itself as "restoring" BEFORE
        // state changes trigger LiveKit's new CameraCapturer, which would
        // conflict with the waiting PiP capture session and forcefully stop PiP.
        NotificationCenter.default.post(name: .callWillConnect, object: nil)

        // Suppress .pipDidClose during the transition. The camera conflict
        // between the waiting PiP capture session and LiveKit's CameraCapturer
        // can crash the PiP system, causing a spurious .pipDidClose that would
        // otherwise disconnect the call.
        viewModel.suppressPipClose = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.viewModel.suppressPipClose = false
        }

        _sdkCallId = call.id
        callConnected = true
        viewModel.isWaitingForAcceptance = false
        viewModel.callAccepted = true
        PopinLogger.shared.log("PopinCallVC: loadCall — setting viewModel.call, id=\(call.id ?? -1), websocket=\(call.websocket ?? "nil"), hasAccessToken=\(call.access_token != nil)")
        viewModel.call = call

        // Safety net: if PiP had hidden the VC view, restore it now.
        // The PiP delegate callback may never fire if the coordinator is
        // deallocated before the async stop completes.
        if self.view.isHidden {
            PopinLogger.shared.log("PopinCallVC: loadCall — restoring hidden VC view")
            handlePiPDidStop()
        }
    }

    /// Update queue position for outgoing calls
    func updateQueuePosition(_ position: Int) {
        viewModel.queuePosition = position
    }

    /// Called when the call is missed while waiting
    func handleCallMissed() {
        viewModel.isWaitingForAcceptance = false
        DispatchQueue.main.async {
            self.closeViewController(shouldNotEndCX: true)
            self.dismiss(animated: true)
        }
    }
    
    func startLoading() {
        //self.startIndicatingActivity()
    }
    
    func finishLoading() {
        //self.stopIndicatingActivity()
    }
    
    func showMessage(title: String, message: String) {
        
    }
    
}

// MARK: - CallKit Integration

extension PopinCallViewController {

    /// Update camera permission state (called after permission request for incoming calls)
    /// Called when CallKit answers the call (from PopinCallManager delegation)
    func handleCallKitAnswerCall() {
        // Guard against double calls (CallKit delegate + Popin.onIncomingCallAnswered)
        guard !viewModel.callAccepted else { return }
        callConnected = true
        viewModel.callAccepted = true
    }
}

// MARK: - CallManagerDelegate

extension PopinCallViewController: CallManagerDelegate {

    func callManager(_ manager: CallManager, didReceiveIncomingCall callUUID: UUID, callerName: String) {
        // Call is already being displayed, no action needed
    }

    func callManager(_ manager: CallManager, didAnswerCall callUUID: UUID) {
        // Notify PopinCallManager that call was answered to stop status checks and update state
        PopinCallManager.shared.callAnswered()

        // Mark call as accepted in VC (idempotent — also called by Popin.onIncomingCallAnswered)
        handleCallKitAnswerCall()
    }

    func callManager(_ manager: CallManager, didHoldCall callUUID: UUID, isOnHold: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.viewModel.isOnHold = isOnHold
        }
    }

    func callManager(_ manager: CallManager, didEndCall callUUID: UUID) {

        // Ensure status checking is stopped in case it was still running
        PopinCallManager.shared.stopStatusChecking()

        // Capture flag NOW — clearCurrentCall() in CXEndCallAction resets it
        // before the async block below runs (same main-queue run loop).
        let endedByTimeout = CallManager.shared.callEndedByTimeout
        PopinLogger.shared.log("PopinCallVC: didEndCall: shouldSkipEndApi=\(shouldSkipEndApi), callEndedByTimeout=\(endedByTimeout), callConnected=\(callConnected), callAccepted=\(viewModel.callAccepted)")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // /end API is only called from the end-call button / PiP close path (viewModel.onEndCall).
            // Reject API is still called here for calls that were never accepted.
            if self.shouldSkipEndApi || endedByTimeout {
                PopinLogger.shared.log("PopinCallVC: didEndCall: Skipping API call (shouldSkipEndApi=\(self.shouldSkipEndApi), endedByTimeout=\(endedByTimeout))")
            } else if self.callConnected || self.viewModel.callAccepted {
                // Call was connected — /end API is handled by onEndCall, skip here
                PopinLogger.shared.log("PopinCallVC: didEndCall: Call was connected, /end API not called from this path")
            } else {
                self.videoCallPresenter.rejectCall(callId: self.callId)
            }

            self.closeViewController(shouldNotEndCX: true)
            self.dismiss(animated: true)
        }
    }

    func callManager(_ manager: CallManager, didActivateAudioSession session: AVAudioSession) {
        // Audio session is already configured in CallManager
        // LiveKit audio session is already activated
    }

    func callManager(_ manager: CallManager, didDeactivateAudioSession session: AVAudioSession) {
        // Audio session is already handled in CallManager
        // LiveKit audio session is already deactivated
    }
}

