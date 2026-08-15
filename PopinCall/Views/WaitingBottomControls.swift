//
//  WaitingBottomControls.swift
//  PopinCall
//

import SwiftUI

#if canImport(UIKit)

// MARK: - Waiting Bottom Controls

struct WaitingBottomControls: View {
    @ObservedObject var viewModel: VideoCallViewModel
    @EnvironmentObject private var configHolder: PopinConfigHolder
    @ObservedObject private var chatManager = ChatManager.shared
    let audioOnlyMode: Bool
    let onCancelCall: () -> Void

    private var visibleButtons: [ControlButtonID] {
        var buttons: [ControlButtonID] = []
        if !configHolder.config.hideMuteAudioButton { buttons.append(.mic) }
        if !audioOnlyMode && !configHolder.config.hideMuteVideoButton { buttons.append(.video) }
        if !audioOnlyMode && !configHolder.config.hideFlipCameraButton { buttons.append(.flip) }
        buttons.append(.invite)
        if !configHolder.config.hideChatButton { buttons.append(.chat) }
        return buttons.sorted { $0.rawValue < $1.rawValue }
    }

    private var needsOverflow: Bool { visibleButtons.count > 4 }
    private var directButtons: [ControlButtonID] { needsOverflow ? Array(visibleButtons.prefix(3)) : visibleButtons }

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            if needsOverflow {
                ControlCircleButtonView(
                    iconName: "ellipsis",
                    backgroundColor: Color.black.opacity(0.15),
                    iconColor: .white.opacity(0.2)
                )
                Spacer()
            }

            ForEach(directButtons, id: \.rawValue) { button in
                waitingButtonView(for: button)
                Spacer()
            }

            if !configHolder.config.hideDisconnectButton {
                ControlCircleButton(
                    iconName: "phone.down.fill",
                    backgroundColor: Color(hex: "E53935"),
                    iconColor: .white,
                    action: onCancelCall
                )
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func waitingButtonView(for button: ControlButtonID) -> some View {
        switch button {
        case .mic:
            ControlCircleButton(
                iconName: viewModel.preCallMicEnabled ? "mic.fill" : "mic.slash.fill",
                backgroundColor: viewModel.preCallMicEnabled ? Color.black.opacity(0.5) : .white,
                iconColor: viewModel.preCallMicEnabled ? .white : .black,
                action: { viewModel.preCallMicEnabled.toggle() }
            )
        case .video:
            if !audioOnlyMode {
                ControlCircleButton(
                    iconName: viewModel.preCallCameraEnabled ? "video.fill" : "video.slash.fill",
                    backgroundColor: viewModel.preCallCameraEnabled ? Color.black.opacity(0.5) : .white,
                    iconColor: viewModel.preCallCameraEnabled ? .white : .black,
                    action: { viewModel.preCallCameraEnabled.toggle() }
                )
            }
        case .flip:
            if !audioOnlyMode {
                ControlCircleButtonView(
                    iconName: "arrow.triangle.2.circlepath.camera.fill",
                    backgroundColor: Color.black.opacity(0.15),
                    iconColor: .white.opacity(0.2)
                )
            }
        case .invite:
            ControlCircleButtonView(
                iconName: "person.fill.badge.plus",
                backgroundColor: Color.black.opacity(0.15),
                iconColor: .white.opacity(0.2)
            )
        case .chat:
            ZStack(alignment: .topTrailing) {
                ControlCircleButtonView(
                    iconName: "text.bubble.fill",
                    backgroundColor: Color.black.opacity(0.15),
                    iconColor: .white.opacity(0.2)
                )
                if chatManager.unreadCount > 0 {
                    Text("\(chatManager.unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.red.opacity(0.5))
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
    }
}

#endif
