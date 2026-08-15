//
//  BottomControls.swift
//  Popin
//
//  Created by Gemini on 28/01/2026.
//

import SwiftUI
import LiveKit
import LiveKitComponents

#if canImport(UIKit)
import ReplayKit

// Helper modifier for iOS 16+ sheet presentation
struct SheetPresentationModifier: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .presentationDetents([.height(height)])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

// MARK: - Button Priority System

enum ControlButtonID: Int, CaseIterable {
    case mic = 1
    case video = 2
    case flip = 3
    case invite = 4
    case chat = 5
}

struct BottomControls: View {
    @EnvironmentObject private var room: Room
    @EnvironmentObject private var configHolder: PopinConfigHolder
    @EnvironmentObject private var viewModel: VideoCallViewModel

    let onEndCall: () -> Void

    @State private var showOverflowMenu = false
    @State private var shareItems: [Any]? = nil
    @Binding var showChat: Bool
    @ObservedObject private var chatManager = ChatManager.shared

    private let videoCallInteractor = VideoCallInteractor()

    private var visibleButtons: [ControlButtonID] {
        let audioOnly = configHolder.config.audioOnlyMode
        var buttons: [ControlButtonID] = []
        if !configHolder.config.hideMuteAudioButton { buttons.append(.mic) }
        if !audioOnly && !configHolder.config.hideMuteVideoButton { buttons.append(.video) }
        if !audioOnly && !configHolder.config.hideFlipCameraButton { buttons.append(.flip) }
        buttons.append(.invite) // always visible
        if !configHolder.config.hideChatButton && viewModel.call?.id != nil { buttons.append(.chat) }
        return buttons.sorted { $0.rawValue < $1.rawValue }
    }

    private var needsOverflow: Bool { visibleButtons.count > 4 }
    private var directButtons: [ControlButtonID] { needsOverflow ? Array(visibleButtons.prefix(3)) : visibleButtons }
    private var overflowButtons: [ControlButtonID] { needsOverflow ? Array(visibleButtons.dropFirst(3)) : [] }

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            // 1. Overflow button (only if needed)
            if needsOverflow {
                ControlCircleButton(
                    iconName: "ellipsis",
                    backgroundColor: Color.black.opacity(0.5),
                    iconColor: .white,
                    action: { showOverflowMenu = true }
                )
                .sheet(isPresented: $showOverflowMenu) {
                    OverflowMenuSheet(
                        showOverflowMenu: $showOverflowMenu,
                        items: overflowButtons,
                        unreadCount: chatManager.unreadCount,
                        onInviteTapped: { generateInviteLink() },
                        onChatTapped: { showChat = true },
                        onFlipTapped: { flipCamera() },
                        onMicTapped: { toggleMic() },
                        onVideoTapped: { toggleVideo() }
                    )
                    .modifier(SheetPresentationModifier(height: CGFloat(80 + overflowButtons.count * 76)))
                }
                Spacer()
            }

            // 2. Direct buttons
            ForEach(directButtons, id: \.rawValue) { button in
                directButtonView(for: button)
                Spacer()
            }

            // 3. End call button
            if !configHolder.config.hideDisconnectButton {
                ControlCircleButton(
                    iconName: "phone.down.fill",
                    backgroundColor: Color(hex: "E53935"),
                    iconColor: .white,
                    action: onEndCall
                )
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .padding(.top, 12)
        .sheet(isPresented: Binding(
            get: { shareItems != nil },
            set: { if !$0 { shareItems = nil } }
        )) {
            if let items = shareItems {
                ShareSheet(activityItems: items, onCompletion: { shareItems = nil })
            }
        }
        .fullScreenCover(isPresented: $showChat) {
            if let callId = viewModel.call?.id {
                ChatView(callId: callId, onClose: { showChat = false })
            }
        }
    }

    // MARK: - Direct button rendering

    @ViewBuilder
    private func directButtonView(for button: ControlButtonID) -> some View {
        switch button {
        case .mic:
            MicrophoneToggleButton(
                label: {
                    ControlCircleButtonView(
                        iconName: "mic.slash.fill",
                        backgroundColor: .white,
                        iconColor: .black
                    )
                },
                published: {
                    ControlCircleButtonView(
                        iconName: "mic.fill",
                        backgroundColor: Color.black.opacity(0.5),
                        iconColor: .white
                    )
                }
            )
            .buttonStyle(PlainButtonStyle())
        case .video:
            CameraToggleButton(
                label: {
                    ControlCircleButtonView(
                        iconName: "video.slash.fill",
                        backgroundColor: .white,
                        iconColor: .black
                    )
                },
                published: {
                    ControlCircleButtonView(
                        iconName: "video.fill",
                        backgroundColor: Color.black.opacity(0.5),
                        iconColor: .white
                    )
                }
            )
            .buttonStyle(PlainButtonStyle())
        case .flip:
            ControlCircleButton(
                iconName: "arrow.triangle.2.circlepath.camera.fill",
                backgroundColor: Color.black.opacity(0.5),
                iconColor: .white,
                action: { flipCamera() }
            )
        case .invite:
            ControlCircleButton(
                iconName: "person.fill.badge.plus",
                backgroundColor: Color.black.opacity(0.5),
                iconColor: .white,
                action: { generateInviteLink() }
            )
        case .chat:
            ZStack(alignment: .topTrailing) {
                ControlCircleButton(
                    iconName: "text.bubble.fill",
                    backgroundColor: Color.black.opacity(0.5),
                    iconColor: .white,
                    action: { showChat = true }
                )
                if chatManager.unreadCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: -9, y: 8)
                }
            }
        }
    }

    // MARK: - Actions

    private func flipCamera() {
        Task {
            let videoTrack = room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack
            let cameraCapturer = videoTrack?.capturer as? CameraCapturer
            try? await cameraCapturer?.switchCameraPosition()
        }
    }

    private func toggleMic() {
        Task {
            let micTrack = room.localParticipant.firstAudioTrack as? LocalAudioTrack
            if let track = micTrack {
                try? await room.localParticipant.setMicrophone(enabled: track.isMuted)
            }
        }
    }

    private func toggleVideo() {
        Task {
            let videoTrack = room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack
            if let track = videoTrack {
                try? await room.localParticipant.setCamera(enabled: track.isMuted)
            }
        }
    }


    private func generateInviteLink() {
        guard let callId = viewModel.call?.id else { return }

        Task {
            do {
                let url = try await videoCallInteractor.inviteParticipant(callId: callId)
                await MainActor.run {
                    let agentName = viewModel.call?.agent?.name ?? viewModel.call?.agents?.first?.name ?? "an agent"
                    let productName = configHolder.config.product?.name ?? PopinCallManager.shared.callData?.productName ?? "a product"
                    shareItems = ["Hey,\nI'm on a live video call with \(agentName) checking out \(productName)\nJoin in and see it with me 👇\n\n\(url)"]
                }
            } catch {
                print("Failed to generate invite link: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Helper Views

struct ControlCircleButton: View {
    let iconName: String
    let backgroundColor: Color
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ControlCircleButtonView(
                iconName: iconName,
                backgroundColor: backgroundColor,
                iconColor: iconColor
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ControlCircleButtonView: View {
    let iconName: String
    let backgroundColor: Color
    let iconColor: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 56, height: 56)
            
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
        }
    }
}

struct OverflowMenuSheet: View {
    @Binding var showOverflowMenu: Bool
    var items: [ControlButtonID]
    var unreadCount: Int = 0
    var onInviteTapped: () -> Void
    var onChatTapped: () -> Void
    var onFlipTapped: () -> Void
    var onMicTapped: () -> Void
    var onVideoTapped: () -> Void

    var body: some View {
        ZStack {
            Color(hex: "2A2F33").ignoresSafeArea()

            VStack(spacing: 16) {
                ForEach(items, id: \.rawValue) { item in
                    overflowRow(for: item)
                }
                Spacer()
            }
            .padding(.top, 32)
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func overflowRow(for item: ControlButtonID) -> some View {
        switch item {
        case .invite:
            overflowButton(
                title: "Invite a friend",
                icon: "person.fill.badge.plus",
                action: { showOverflowMenu = false; onInviteTapped() }
            )
        case .chat:
            Button(action: {
                showOverflowMenu = false
                onChatTapped()
            }) {
                HStack {
                    Text("Chat")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.white)
                    Spacer()
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "text.bubble.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                        if unreadCount > 0 {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 5, y: -5)
                        }
                    }
                }
                .padding(20)
                .background(Color(hex: "3E4347"))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        case .flip:
            overflowButton(
                title: "Flip camera",
                icon: "arrow.triangle.2.circlepath.camera.fill",
                action: { showOverflowMenu = false; onFlipTapped() }
            )
        case .mic:
            overflowButton(
                title: "Mute / Unmute",
                icon: "mic.fill",
                action: { showOverflowMenu = false; onMicTapped() }
            )
        case .video:
            overflowButton(
                title: "Turn off / on video",
                icon: "video.fill",
                action: { showOverflowMenu = false; onVideoTapped() }
            )
        }
    }

    private func overflowButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            .padding(20)
            .background(Color(hex: "3E4347"))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onCompletion: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            onCompletion?()
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#if DEBUG
private struct BottomControlsPreviewWrapper: View {
    let configHolder: PopinConfigHolder
    let unreadCount: Int

    @StateObject private var viewModel = VideoCallViewModel()
    @State private var showChat = false

    var body: some View {
        BottomControls(onEndCall: {}, showChat: $showChat)
            .environmentObject(Room())
            .environmentObject(configHolder)
            .environmentObject(viewModel)
            .onAppear {
                viewModel.call = try? JSONDecoder().decode(
                    TalkModel.self,
                    from: #"{"id":123,"status":1}"#.data(using: .utf8)!
                )
                ChatManager.shared.unreadCount = unreadCount
            }
    }
}

struct BottomControls_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {
                    Spacer()
                    BottomControlsPreviewWrapper(
                        configHolder: PopinConfigHolder(config: PopinConfig.Builder().build()),
                        unreadCount: 0
                    )
                }
            }
            .previewDisplayName("All buttons")

            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {
                    Spacer()
                    BottomControlsPreviewWrapper(
                        configHolder: PopinConfigHolder(config: PopinConfig.Builder().build()),
                        unreadCount: 3
                    )
                }
            }
            .previewDisplayName("Unread dot")

            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {
                    Spacer()
                    BottomControlsPreviewWrapper(
                        configHolder: PopinConfigHolder(config: PopinConfig.Builder().audioOnlyMode(true).build()),
                        unreadCount: 0
                    )
                }
            }
            .previewDisplayName("Audio only")

            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {
                    Spacer()
                    BottomControlsPreviewWrapper(
                        configHolder: PopinConfigHolder(config: PopinConfig.Builder().hideMuteAudioButton(false).hideMuteVideoButton(false).hideFlipCameraButton(false).build()),
                        unreadCount: 1
                    )
                }
            }
            .previewDisplayName("Overflow (5 buttons)")

            ZStack {
                Color.gray.ignoresSafeArea()
                VStack {
                    Spacer()
                    BottomControlsPreviewWrapper(
                        configHolder: PopinConfigHolder(config: PopinConfig.Builder().hideFlipCameraButton(true).build()),
                        unreadCount: 3
                    )
                }
            }
            .previewDisplayName("No flip camera")
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif

struct BroadcastPickerRowWrapper: UIViewRepresentable {
    var extensionBundleIdentifier: String {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "to.popin.seller.broadcast"
        }
        return bundleID + ".broadcast"
    }
    
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: .zero)
        picker.preferredExtension = extensionBundleIdentifier
        picker.showsMicrophoneButton = false
        
        // Hide the default button image so it's transparent
        for view in picker.subviews {
            if let button = view as? UIButton {
                button.imageView?.image = nil
                button.setImage(nil, for: .normal)
                button.setImage(nil, for: .highlighted)
                // Make the button fill the view
                button.frame = picker.bounds
                button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        if uiView.preferredExtension != extensionBundleIdentifier {
            uiView.preferredExtension = extensionBundleIdentifier
        }
    }
}
#endif
