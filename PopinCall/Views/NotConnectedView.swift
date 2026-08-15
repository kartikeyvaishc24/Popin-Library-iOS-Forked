//
//  NotConnectedView.swift
//  Popin
//
//  Created by Ashwin on 02/12/25.
//
import SwiftUI

#if canImport(UIKit)
struct NotConnectedView: View {
    // Call information
    let callerName: String
    let callId: Int
    let callComponentId: Int
    let callUUID: UUID
    let artifact: String
    let callRole: Int

    // Actions
    let onAccept: () -> Void
    let onReject: () -> Void

    // Pulse animation state
    @State private var pulse = false

    // Access to config
    @EnvironmentObject private var configHolder: PopinConfigHolder

    init(
        callerName: String = "Unknown Caller",
        callId: Int = 0,
        callComponentId: Int = 0,
        callUUID: UUID = UUID(),
        artifact: String = "",
        callRole: Int = 0,
        onAccept: @escaping () -> Void = {},
        onReject: @escaping () -> Void = {}
    ) {
        self.callerName = callerName
        self.callId = callId
        self.callComponentId = callComponentId
        self.callUUID = callUUID
        self.artifact = artifact
        self.callRole = callRole
        self.onAccept = onAccept
        self.onReject = onReject
    }

    private var callTypeLabel: String {
        configHolder.config.audioOnlyMode ? "Popin Audio" : "Popin Video"
    }

    var body: some View {
        ZStack {
            // Background — dark blue-grey gradient matching CallKit
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.13, blue: 0.20),
                    Color(red: 0.06, green: 0.07, blue: 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top section ──────────────────────────────────────────
                Spacer()

                // Pulse rings behind avatar
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: pulse ? 160 : 120, height: pulse ? 160 : 120)
                        .animation(
                            Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                            value: pulse
                        )

                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        .frame(width: pulse ? 200 : 150, height: pulse ? 200 : 150)
                        .animation(
                            Animation.easeInOut(duration: 1.4).delay(0.2).repeatForever(autoreverses: true),
                            value: pulse
                        )

                    // Avatar circle
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 104, height: 104)

                        Image(systemName: "person.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.bottom, 28)

                // Call type label  (e.g. "Popin Video")
                Text(callTypeLabel)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.bottom, 10)

                // Caller name
                Text(callerName)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                // ── Bottom buttons ────────────────────────────────────────
                HStack(spacing: 0) {
                    // Decline
                    CallActionButton(
                        icon: "phone.down.fill",
                        label: "Decline",
                        color: Color(red: 0.92, green: 0.22, blue: 0.22),
                        action: {
                            onReject()
                        }
                    )

                    Spacer()

                    // Accept
                    CallActionButton(
                        icon: configHolder.config.audioOnlyMode ? "phone.fill" : "video.fill",
                        label: "Accept",
                        color: Color(red: 0.18, green: 0.74, blue: 0.30),
                        action: {
                            onAccept()
                        }
                    )
                }
                .padding(.horizontal, 34)
                .padding(.bottom, 64)
            }
        }
        .onAppear {
            pulse = true
        }
    }
}

// MARK: - CallActionButton

private struct CallActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 76, height: 76)
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
                Text(label)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Preview
struct NotConnectedView_Previews: PreviewProvider {
    static var previews: some View {
        let config = PopinConfig.Builder().build()
        NotConnectedView(
            callerName: "John Doe",
            callId: 12345,
            callComponentId: 67890,
            callUUID: UUID(),
            artifact: "Premium Widget",
            callRole: 1,
            onAccept: { },
            onReject: { }
        )
        .environmentObject(PopinConfigHolder(config: config))
    }
}
#endif
