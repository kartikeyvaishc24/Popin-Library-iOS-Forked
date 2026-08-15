//
//  ConnectView.swift
//  Popin
//
//  Created by Ashwin on 09/09/25.
//

import SwiftUI
#if canImport(UIKit)
import LiveKit
import LiveKitComponents
import AVKit
import AVFoundation

// Helper for cross-version onChange compatibility
extension View {
    @ViewBuilder
    func onChangeCompatible<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        if #available(iOS 17.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
}

struct PopinConnectedView: View {

    @EnvironmentObject private var _room: Room
    @Environment(\.liveKitUIOptions) private var _ui: UIOptions
    @Environment(\.scenePhase) private var scenePhase

    @State private var primaryParticipantId: String?
    @StateObject private var pipHandler = PiPHandler()
    @State private var pipSupported = AVPictureInPictureController.isPictureInPictureSupported()
    @State private var showChat = false

    // Maintain a persistent order of participant SIDs to prevents random shifting
    @State private var participantOrder: [String] = []

    // Track camera position for mirroring
    @State private var isFrontCamera = true  // Default to front camera

    // Get view model and config from environment
    @EnvironmentObject private var viewModel: VideoCallViewModel
    @EnvironmentObject private var configHolder: PopinConfigHolder

    // Chat toast state
    @ObservedObject private var chatManager = ChatManager.shared
    @State private var toastMessage: String? = nil
    @State private var toastTimer: Timer? = nil

    // Network state tracking (matches Android CallActivity)
    @State private var previousHasCustomerNetworkIssue: Bool = false
    @State private var previousHasSellerNetworkIssue: Bool = false
    @State private var participantCheckTimer: Timer? = nil
    
    
    private func enableHardware() async {
        // Camera and microphone are already enabled in VideoCallSwiftUIView
        // This function is kept for potential future hardware configuration
        // but currently does nothing to avoid re-enabling already active devices
    }

    private func updateCameraPosition() {
        // Check current camera position
        if let videoTrack = _room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
           let cameraCapturer = videoTrack.capturer as? CameraCapturer {
            // In LiveKit, front camera is typically position .front
            // We'll check the device's camera position
            if let device = cameraCapturer.captureSession.inputs.first as? AVCaptureDeviceInput {
                isFrontCamera = device.device.position == .front
            }
        }
    }
    
    private func syncParticipantOrder() {
        let allParticipants = _room.allParticipants.values
        var currentSids = Set<String>()
        
        // 1. Collect all valid SIDs from the room
        for p in allParticipants {
            if let sid = p.sid?.stringValue {
                currentSids.insert(sid)
            }
        }
        
        // 2. Remove stale SIDs from our order list
        var newOrder = participantOrder.filter { currentSids.contains($0) }
        
        // 3. Find new participants not yet in our order
        let existingSids = Set(newOrder)
        let newParticipants = allParticipants.filter { p in
            guard let sid = p.sid?.stringValue else { return false }
            return !existingSids.contains(sid)
        }
        
        // 4. Sort new participants - prioritize agent/seller (identity starts with 's')
        let sortedNew = newParticipants.sorted { p1, p2 in
            let identity1 = p1.identity?.stringValue ?? ""
            let identity2 = p2.identity?.stringValue ?? ""

            let isSeller1 = identity1.hasPrefix("s")
            let isSeller2 = identity2.hasPrefix("s")

            // Seller/agent comes first
            if isSeller1 && !isSeller2 { return true }
            if !isSeller1 && isSeller2 { return false }

            // If both are sellers or both are not, sort by joinedAt
            let date1 = p1.joinedAt ?? Date.distantPast
            let date2 = p2.joinedAt ?? Date.distantPast

            if date1 != date2 {
                return date1 < date2
            }
            return (p1.sid?.stringValue ?? "") < (p2.sid?.stringValue ?? "")
        }
        
        // 5. Append new SIDs - but prioritize sellers to the front if no seller is currently primary
        for p in sortedNew {
            if let sid = p.sid?.stringValue {
                let identity = p.identity?.stringValue ?? ""
                if identity.hasPrefix("s") && !newOrder.isEmpty {
                    // Check if the current primary is a seller
                    let firstSid = newOrder[0]
                    let firstParticipant = _room.allParticipants.values.first(where: { $0.sid?.stringValue == firstSid })
                    let firstIsSeller = firstParticipant?.identity?.stringValue.hasPrefix("s") ?? false
                    
                    if !firstIsSeller {
                        newOrder.insert(sid, at: 0)
                        continue
                    }
                }
                newOrder.append(sid)
            }
        }
        
        if participantOrder != newOrder {
            participantOrder = newOrder
        }
    }

    private func showToast(message: String) {
        // Cancel any existing timer
        toastTimer?.invalidate()

        // Show the toast
        withAnimation {
            toastMessage = message
        }

        // Auto-dismiss after 4 seconds
        toastTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            dismissToast()
        }
    }

    private func dismissToast() {
        toastTimer?.invalidate()
        toastTimer = nil
        withAnimation {
            toastMessage = nil
        }
    }

    private var sortedParticipants: [Participant] {
        // Map the maintained order to actual Participant objects
        var ordered: [Participant] = []
        let allMap = _room.allParticipants
        
        for sid in participantOrder {
            // _room.allParticipants uses Sid object as key, not string.
            // We need to find the participant with this sid string.
            if let participant = allMap.values.first(where: { $0.sid?.stringValue == sid }) {
                ordered.append(participant)
            }
        }
        
        // Fallback: If for some reason the order list is desynced or empty but we have participants
        // (e.g. initial load), use the stable sort as backup - prioritize agent/seller (identity starts with 's')
        if ordered.isEmpty && !_room.allParticipants.isEmpty {
            return Array(_room.allParticipants.values).sorted { p1, p2 in
                let identity1 = p1.identity?.stringValue ?? ""
                let identity2 = p2.identity?.stringValue ?? ""

                let isSeller1 = identity1.hasPrefix("s")
                let isSeller2 = identity2.hasPrefix("s")

                // Seller/agent comes first
                if isSeller1 && !isSeller2 { return true }
                if !isSeller1 && isSeller2 { return false }

                let d1 = p1.joinedAt ?? Date.distantPast
                let d2 = p2.joinedAt ?? Date.distantPast
                return d1 < d2
            }
        }
        
        return ordered
    }

    // Computed product properties — prefer config (outgoing) then push data (incoming)
    private var pushProduct: Product? { PopinCallManager.shared.callData?.product }

    private var productId: String? {
        configHolder.config.product?.id ?? PopinCallManager.shared.callData?.productId ?? pushProduct?.id
    }

    private var productName: String? {
        configHolder.config.product?.name ?? PopinCallManager.shared.callData?.productName ?? pushProduct?.name
    }

    private var productImageUrl: String? {
        configHolder.config.product?.image ?? PopinCallManager.shared.callData?.productImage ?? pushProduct?.image
    }

    private var productUrl: String? {
        configHolder.config.product?.url ?? pushProduct?.url
    }

    private var productDescription: String? {
        configHolder.config.product?.description ?? pushProduct?.description
    }

    private var productExtra: String? {
        configHolder.config.product?.extra
    }

    /// Determines which network badge to show (only one at a time, by priority)
    @ViewBuilder
    private var networkBadge: some View {
        if viewModel.hasCustomerNetworkIssue && !viewModel.showCustomerBackOnlineMessage && !viewModel.showSellerRejoinedMessage {
            // Priority 1: Customer's own network lost
            NetworkToastView(text: "Your network lost", type: .warning)
                .transition(.opacity)
        } else if viewModel.hasSellerNetworkIssue && !viewModel.showCustomerBackOnlineMessage && !viewModel.showSellerRejoinedMessage && !viewModel.hasCustomerNetworkIssue {
            // Priority 2: Seller/agent network lost
            NetworkToastView(text: "Expert's network lost", type: .warning)
                .transition(.opacity)
        } else if viewModel.showCustomerBackOnlineMessage && !viewModel.showSellerRejoinedMessage {
            // Priority 3: Customer back online (temporary, 5 sec)
            NetworkToastView(text: "You're back online", type: .success)
                .transition(.opacity)
        } else if viewModel.showSellerRejoinedMessage {
            // Priority 4: Seller rejoined (temporary, 5 sec)
            NetworkToastView(text: "Expert rejoined", type: .success)
                .transition(.opacity)
        } else if viewModel.noQualifyingParticipantsTimer > 5000 && !viewModel.hasCustomerNetworkIssue && !viewModel.hasSellerNetworkIssue {
            // Priority 5: Trying to reconnect (no qualifying participants for > 5 sec)
            NetworkToastView(text: "Trying to reconnect...", type: .warning)
                .transition(.opacity)
        } else if !_room.localParticipant.isMicrophoneEnabled() && !showChat {
            // Priority 6 (lowest): You're on mute
            NetworkToastView(text: "You're on mute", type: .info)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var overlayControls: some View {
        VStack(spacing: 0) {
            // Top controls + audience row side by side
            TopControls(
                onPipClick: {
                    pipHandler.startPictureInPicture()
                },
                productId: productId,
                productName: productName,
                productUrl: productUrl,
                productImageUrl: productImageUrl,
                productDescription: productDescription,
                productExtra: productExtra
            )
            .overlay(
                // Network badge floats below TopControls without affecting layout
                networkBadge
                    .animation(.easeInOut(duration: 0.3), value: viewModel.hasCustomerNetworkIssue)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.hasSellerNetworkIssue)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.showCustomerBackOnlineMessage)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.showSellerRejoinedMessage)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.noQualifyingParticipantsTimer)
                    .alignmentGuide(.bottom) { d in d[.top] - 8 },
                alignment: .bottom
            )
            .overlay(
                // Audience tiles — top aligned with product details, trailing
                Group {
                    if sortedParticipants.count > 1 {
                        let audienceParticipants = Array(sortedParticipants.dropFirst())
                        AudienceRow(
                            participants: audienceParticipants,
                            primaryParticipantId: $primaryParticipantId,
                            localParticipantSid: _room.localParticipant.sid?.stringValue,
                            localDisplayName: Popin.shared?.config.userName,
                            isFrontCamera: isFrontCamera
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.top, 10)
                        .padding(.trailing, 8)
                    }
                },
                alignment: .topTrailing
            )
            .zIndex(1)

            Spacer()

            // Chat toast - appears when new message arrives
            if let message = toastMessage, !showChat {
                ChatDetailsToast(
                    message: message,
                    showBadge: chatManager.unreadCount > 0,
                    onTap: {
                        dismissToast()
                        showChat = true
                    }
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: toastMessage)
            }

            // Agent info bar + Bottom controls with shared gradient
            VStack(spacing: 0) {
                if let agent = viewModel.call?.agent {
                    let agentParticipant: Participant? = {
                        guard let agentId = agent.id else { return nil }
                        let idString = String(agentId)
                        // Exact match
                        if let exact = _room.allParticipants.values.first(where: {
                            let identity = $0.identity?.stringValue ?? ""
                            return identity == idString || identity == "s\(idString)"
                        }) { return exact }
                        // Prefix match (s{id}*)
                        return _room.allParticipants.values.first(where: {
                            ($0.identity?.stringValue ?? "").hasPrefix("s\(idString)")
                        })
                    }()

                    AgentInfoBar(
                        agent: agent,
                        expertDesignation: configHolder.config.expertDesignation,
                        participant: agentParticipant
                    )
                }

                BottomControls(onEndCall: {
                    PopinLogger.shared.log("PopinConnectedView: END CALL BUTTON tapped")
                    viewModel.isUserEndingCall = true
                    viewModel.onEndCall?()
                }, showChat: $showChat)
            }
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0), location: 0.0),
                        .init(color: Color.black.opacity(0), location: 0.3),
                        .init(color: Color.black.opacity(0.2), location: 0.5),
                        .init(color: Color.black.opacity(0.4), location: 0.7),
                        .init(color: Color.black.opacity(0.6), location: 0.85),
                        .init(color: Color.black.opacity(0.6), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false),
                alignment: .bottom
            )
        }
    }

    var body: some View {
        ZStack {
            // Primary participant view (full screen) with PiP support
            if let primaryParticipant = sortedParticipants.first {
                PrimaryParticipantView(
                    participant: primaryParticipant,
                    pipHandler: pipHandler,
                    pipSupported: pipSupported,
                    localParticipantSid: _room.localParticipant.sid?.stringValue,
                    isFrontCamera: isFrontCamera
                )
            } else {
                Color.black
            }

            // Overlay for remote participants and controls
            overlayControls
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            PopinLogger.shared.log("PopinConnectedView: onAppear")
        }
        .task {
            await enableHardware()
            // Initial sync
            syncParticipantOrder()
            // Check initial camera position
            updateCameraPosition()
        }
        // Watch for participant changes to sync order
        .onChange(of: _room.remoteParticipants.count) { _ in
            syncParticipantOrder()
        }
        // Also watch for local participant SID assignment
        .onChange(of: _room.localParticipant.sid) { _ in
            syncParticipantOrder()
        }
        .onChange(of: _room.connectionState) { newState in
            if newState == .connected {
                syncParticipantOrder()
                // Update camera position when connected
                updateCameraPosition()
            }

            // Handle room disconnection (when not user-initiated)
            if newState == .disconnected && !viewModel.isUserEndingCall {
                // If disconnected with an error, it's a network failure (not a clean hang-up)
                if let error = _room.disconnectError {
                    PopinLogger.shared.log("PopinConnectedView: room disconnected with error: \(error) — firing onNetworkFailure")
                    viewModel.onNetworkFailure?("user")
                } else {
                    PopinLogger.shared.log("PopinConnectedView: room disconnected cleanly (no error) — firing onRoomDisconnected")
                }
                viewModel.onRoomDisconnected?()
            }
        }
        // Periodically check camera position (in case it changes via flip button)
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if _room.connectionState == .connected {
                updateCameraPosition()
            }
        }
        // Handle Primary Participant Selection (Swap Logic)
        .onChange(of: primaryParticipantId) { newId in
             guard let newId = newId, !participantOrder.isEmpty else {
                 PopinLogger.shared.log("Swap: ignored — newId=\(newId ?? "nil"), orderEmpty=\(participantOrder.isEmpty)")
                 return
             }

             PopinLogger.shared.log("Swap: requested sid=\(newId), participantOrder=\(participantOrder)")

             if let targetIndex = participantOrder.firstIndex(of: newId) {
                 if targetIndex != 0 {
                     PopinLogger.shared.log("Swap: swapping index 0 (\(participantOrder[0])) with index \(targetIndex) (\(participantOrder[targetIndex]))")
                     // Perform the swap on the persistent state
                     withAnimation {
                         participantOrder.swapAt(0, targetIndex)
                     }
                     PopinLogger.shared.log("Swap: new order=\(participantOrder)")
                 } else {
                     PopinLogger.shared.log("Swap: already at index 0, no swap needed")
                 }
             } else {
                 PopinLogger.shared.log("Swap: sid \(newId) NOT found in participantOrder")
             }
        }
        .onChangeCompatible(of: scenePhase) { newPhase in
            // Automatically enable PiP when app goes to background
            if newPhase == .background && pipSupported {
                pipHandler.startPictureInPicture()
            }
        }
        .onChange(of: showChat) { show in
            if show {
                // Chat opened -> Start PiP if supported
                if pipSupported {
                    pipHandler.startPictureInPicture()
                }
                // Dismiss any active toast
                dismissToast()
            } else {
                 // Chat closed -> Stop PiP
                 pipHandler.stopPictureInPicture()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pipDidStop)) { _ in
            // PiP restored (user tapped fullscreen button)
            // If chat is open, close it to show full screen video
            if showChat {
                showChat = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pipDidClose)) { _ in
            // Ignore spurious .pipDidClose during the waiting→connected PiP transition.
            // The camera conflict can crash the PiP system, generating a false close event.
            guard !viewModel.suppressPipClose else {
                PopinLogger.shared.log("PopinConnectedView: ignoring .pipDidClose — suppressed during PiP transition")
                return
            }
            // PiP closed (user tapped X button) — disconnect the call
            PopinLogger.shared.log("PopinConnectedView: .pipDidClose — ending call")
            viewModel.isUserEndingCall = true
            viewModel.onEndCall?()
        }
        .onChange(of: chatManager.latestIncomingMessage) { newMessage in
            // Show toast when new incoming message arrives
            if let message = newMessage, let text = message.text, !text.isEmpty, !showChat {
                showToast(message: text)
            }
        }
        // MARK: - Network Monitoring

        // Listen for Pusher connection state changes (customer's own network)
        .onReceive(NotificationCenter.default.publisher(for: .pusherConnectionStateChanged)) { notification in
            if let isConnected = notification.userInfo?["isConnected"] as? Bool {
                viewModel.hasCustomerNetworkIssue = !isConnected
            }
        }
        // Track when customer network issue resolves -> show "You're back online" for 5 sec
        .onChange(of: viewModel.hasCustomerNetworkIssue) { newValue in
            if !previousHasCustomerNetworkIssue && newValue {
                // Customer just lost network — notify delegate
                viewModel.onNetworkFailure?("customer")
            } else if previousHasCustomerNetworkIssue && !newValue {
                viewModel.showCustomerBackOnlineMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    viewModel.showCustomerBackOnlineMessage = false
                }
            }
            previousHasCustomerNetworkIssue = newValue
        }
        // Track when seller network issue resolves -> show "Expert rejoined" for 5 sec
        .onChange(of: viewModel.hasSellerNetworkIssue) { newValue in
            if previousHasSellerNetworkIssue && !newValue {
                viewModel.showSellerRejoinedMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    viewModel.showSellerRejoinedMessage = false
                }
            }
            previousHasSellerNetworkIssue = newValue
        }
        // Monitor remote participant connection quality for seller network issues
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard _room.connectionState == .connected else { return }

            // Re-sync participant order if SIDs have changed (handles reconnects
            // where count stays the same but the participant gets a new SID)
            let currentSids = Set(_room.allParticipants.values.compactMap { $0.sid?.stringValue })
            let orderedSids = Set(participantOrder)
            if currentSids != orderedSids {
                syncParticipantOrder()
            }

            // Check connection quality for seller/agent participants
            for (_, participant) in _room.remoteParticipants {
                let identity = participant.identity?.stringValue ?? ""
                if identity.lowercased().hasPrefix("s") {
                    let hasNetworkIssue = participant.connectionQuality == .lost
                    if viewModel.hasSellerNetworkIssue != hasNetworkIssue {
                        viewModel.hasSellerNetworkIssue = hasNetworkIssue
                    }
                }
            }

            // Monitor no-qualifying-participants timer (matching Android 30-sec auto-end)
            var hasQualifyingParticipant = false
            for (_, participant) in _room.remoteParticipants {
                let identity = participant.identity?.stringValue ?? ""
                if identity.lowercased().hasPrefix("s") || identity.lowercased().hasPrefix("q") {
                    if !viewModel.hasCustomerNetworkIssue {
                        hasQualifyingParticipant = true
                    }
                }
            }

            if hasQualifyingParticipant {
                viewModel.noQualifyingParticipantsTimer = 0
            } else {
                viewModel.noQualifyingParticipantsTimer += 1000

                // End call if no qualifying participants for 30 seconds
                if viewModel.noQualifyingParticipantsTimer >= 30000 {
                    PopinLogger.shared.log("PopinConnectedView: 30s without qualifying participants — firing onNetworkFailure")
                    viewModel.onNetworkFailure?("agent")
                    viewModel.isUserEndingCall = true
                    viewModel.onRoomDisconnected?()
                    Task {
                        await _room.disconnect()
                    }
                }
            }
        }
    }
}

// MARK: - Primary Participant View

struct PrimaryParticipantView: View {
    @ObservedObject var participant: Participant
    let pipHandler: PiPHandler
    let pipSupported: Bool
    let localParticipantSid: String?
    let isFrontCamera: Bool

    // Prefer screen share track over camera (matching Android PrimarySpeakerView)
    // Uses TrackReference for camera so the track resolves even when muted,
    // keeping the PiP controller alive in the view hierarchy
    private var preferredVideoTrack: VideoTrack? {
        if let screenTrack = participant.firstScreenShareVideoTrack {
            return screenTrack
        }
        let cameraRef = TrackReference(participant: participant, source: .camera)
        if let publication = cameraRef.resolve(),
           let videoTrack = publication.track as? VideoTrack {
            return videoTrack
        }
        return nil
    }

    // Check if this is the local participant and should be mirrored
    private var shouldMirror: Bool {
        guard let localSid = localParticipantSid,
              let participantSid = participant.sid?.stringValue else {
            return false
        }
        // Mirror if this is local participant AND front camera is active AND showing camera (not screen share)
        return localSid == participantSid && isFrontCamera && participant.firstScreenShareVideoTrack == nil
    }

    var body: some View {
        ZStack {
            if pipSupported, let track = preferredVideoTrack {
                PiPView(track: track, pipHandler: pipHandler, shouldMirror: shouldMirror, isCameraEnabled: participant.isCameraEnabled())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .ignoresSafeArea()
            } else {
                ParticipantView(showInformation: false)
                    .environmentObject(participant)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                    .scaleEffect(x: shouldMirror ? -1 : 1, y: 1)  // Mirror horizontally if front camera
            }

            // Black overlay with muted icon when camera is disabled
            if !participant.isCameraEnabled() && participant.firstScreenShareVideoTrack == nil {
                Color.black
                    .ignoresSafeArea()
                Image(systemName: "video.slash.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
#endif
