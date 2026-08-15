//
//  VideoCallSwiftUIView.swift
//  Popin
//
//  Created by VideoCall Migration
//

import SwiftUI
#if canImport(UIKit)
import LiveKit
import LiveKitComponents
import Combine
import UIKit
import AVFAudio
import Foundation
// MARK: - SwiftUI VideoCall View

struct VideoCallSwiftUIView: View {
    @EnvironmentObject private var _room: Room
    @EnvironmentObject private var configHolder: PopinConfigHolder
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: VideoCallViewModel

    let callId: Int
    let callComponentId: Int
    let callUUID: UUID?
    let callRole: Int
    let customerName: String
    let artifact: String

    @State private var videoCallId: Int?
    @State private var videoUserId: Int?
    /// Tracks the call ID we've already started connecting to, preventing duplicate room.connect() calls
    @State private var connectingCallId: Int?

    init(viewModel: VideoCallViewModel,
         callId: Int,
         callComponentId: Int,
         callUUID: UUID?,
         callRole: Int,
         customerName: String,
         artifact: String) {
        self.viewModel = viewModel
        self.callId = callId
        self.callComponentId = callComponentId
        self.callUUID = callUUID
        self.callRole = callRole
        self.customerName = customerName
        self.artifact = artifact
    }
    
    var body: some View {
        PopinCallStateView(callId: videoCallId, userId: videoUserId)
            .environmentObject(viewModel)
            .onReceive(viewModel.$call.compactMap { $0 }) { call in
                // Update call data for the UI
                videoCallId = call.id
                videoUserId = call.user_id

                // Configure ChatManager for this call
                if let callId = call.id {
                    ChatManager.shared.configure(callId: callId, sellerId: Utilities.shared.getSeller())
                }

                // Prevent duplicate connect — onReceive can re-fire when @State mutations trigger re-renders
                guard connectingCallId != call.id else {
                    PopinLogger.shared.log("VideoCallSwiftUIView: skipping duplicate onReceive for callId=\(call.id ?? -1)")
                    return
                }
                connectingCallId = call.id
                PopinLogger.shared.log("VideoCallSwiftUIView: call received — id=\(call.id ?? -1), userId=\(call.user_id ?? -1), websocket=\(call.websocket ?? "nil"), hasAccessToken=\(call.access_token != nil)")

                Task {
                    guard let websocket = call.websocket,
                          let token = call.access_token else {
                        PopinLogger.shared.log("VideoCallSwiftUIView: MISSING websocket or access_token — cannot connect to room. websocket=\(call.websocket ?? "nil"), token=\(call.access_token ?? "nil")")
                        return
                    }
                    PopinLogger.shared.log("VideoCallSwiftUIView: connecting to LiveKit room — url=\(websocket), roomState=\(_room.connectionState)")

                    // Step 1: Connect to room
                    do {
                        try await _room.connect(url: websocket, token: token)
                        PopinLogger.shared.log("VideoCallSwiftUIView: room.connect() SUCCESS — connectionState=\(_room.connectionState), localParticipantSid=\(_room.localParticipant.sid?.stringValue ?? "nil")")
                    } catch {
                        PopinLogger.shared.log("VideoCallSwiftUIView: room.connect() FAILED — error=\(error)")
                        return
                    }

                    // Step 2: Enable microphone (non-fatal — call continues if this fails)
                    do {
                        try await _room.localParticipant.setMicrophone(enabled: viewModel.preCallMicEnabled)
                        PopinLogger.shared.log("VideoCallSwiftUIView: microphone enabled=\(viewModel.preCallMicEnabled)")
                    } catch {
                        PopinLogger.shared.log("VideoCallSwiftUIView: setMicrophone FAILED — error=\(error)")
                    }

                    // Step 3: Enable camera (non-fatal — call continues with audio if this fails)
                    do {
                        let cameraEnabled = configHolder.config.audioOnlyMode ? false : viewModel.preCallCameraEnabled
                        try await _room.localParticipant.setCamera(enabled: cameraEnabled)
                        PopinLogger.shared.log("VideoCallSwiftUIView: camera enabled=\(cameraEnabled), audioOnlyMode=\(configHolder.config.audioOnlyMode)")
                    } catch {
                        PopinLogger.shared.log("VideoCallSwiftUIView: setCamera FAILED — error=\(error), roomState=\(_room.connectionState)")
                    }

                    // Step 4: Enable multitasking camera access for PiP
                    if let localVideoTrack = _room.localParticipant.trackPublications.first(where: {
                        $0.value.kind == Track.Kind.video
                    })?.value.track as? LocalVideoTrack  {

                        if let cameraCapturer = localVideoTrack.capturer as? CameraCapturer {
                            if #available(iOS 16.0, *) {
                                if cameraCapturer.captureSession.isMultitaskingCameraAccessSupported {
                                    cameraCapturer.captureSession.beginConfiguration()
                                    cameraCapturer.captureSession.isMultitaskingCameraAccessEnabled = true
                                    cameraCapturer.captureSession.commitConfiguration()
                                    PopinLogger.shared.log("VideoCallSwiftUIView: multitasking camera access enabled")
                                }
                            }
                        }
                    }

                    PopinLogger.shared.log("VideoCallSwiftUIView: room setup complete — remoteParticipants=\(_room.remoteParticipants.count), roomState=\(_room.connectionState)")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DataShared"))) { notification in
                guard let userInfo = notification.userInfo,
                      let data = userInfo["data"] as? [String: Any] else {
                    return
                }
                
                Task {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
                        try await _room.localParticipant.publish(data: jsonData)
                    } catch {
                    }
                }
            }
            .onReceive(viewModel.$isOnHold) { isOnHold in
                Task {
                    do {
                        // Toggle camera and microphone based on hold status
                        // If on hold, disable (mute). If not on hold, enable (unmute).
                        let shouldEnable = !isOnHold

                        if !configHolder.config.audioOnlyMode {
                            if _room.localParticipant.firstCameraVideoTrack != nil || shouldEnable {
                                 try await _room.localParticipant.setCamera(enabled: shouldEnable)
                            }
                        }

                        if _room.localParticipant.firstAudioTrack != nil || shouldEnable {
                            try await _room.localParticipant.setMicrophone(enabled: shouldEnable)
                        }

                    } catch {
                    }
                }
            }
    }
}


#if DEBUG
#Preview("Disconnected") {
    RoomScope(roomOptions: RoomOptions(
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
        dynacast: true
    )) {
        VideoCallSwiftUIView(
            viewModel: VideoCallViewModel(),
            callId: 0,
            callComponentId: 0,
            callUUID: nil,
            callRole: 0,
            customerName: "Preview User",
            artifact: "Sample"
        )
    }
}
#endif
#endif

