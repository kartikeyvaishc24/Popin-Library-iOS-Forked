//
//  AudienceRow.swift
//  Popin
//
//  Created by Ashwin on 09/09/25.
//

import SwiftUI
import LiveKit
import LiveKitComponents

#if canImport(UIKit)
struct AudienceRow: View {
    let participants: [Participant]
    @Binding var primaryParticipantId: String?
    let localParticipantSid: String?
    let localDisplayName: String?
    let isFrontCamera: Bool

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(participants) { participant in
                    AudienceRowTile(
                        participant: participant,
                        primaryParticipantId: $primaryParticipantId,
                        localParticipantSid: localParticipantSid,
                        localDisplayName: localDisplayName,
                        isFrontCamera: isFrontCamera
                    )
                }
            }
            .padding(.top, 4)
            .padding(.trailing, 10)
        }
        // Fixed height: 2.5 tiles (80pt each) + spacing
        .frame(height: 216, alignment: .top)
    }
}

private struct AudienceRowTile: View {
    @ObservedObject var participant: Participant
    @Binding var primaryParticipantId: String?
    let localParticipantSid: String?
    let localDisplayName: String?
    let isFrontCamera: Bool

    private var isLocalParticipant: Bool {
        guard let localSid = localParticipantSid,
              let participantSid = participant.sid?.stringValue else {
            return false
        }
        return localSid == participantSid
    }

    // Mirror if this is local participant AND front camera is active AND showing camera (not screen share)
    private var shouldMirror: Bool {
        isLocalParticipant && isFrontCamera && participant.firstScreenShareVideoTrack == nil
    }

    var body: some View {


        Button(action: {
            let sid = participant.sid?.stringValue
            let identity = participant.identity?.stringValue
        
            if let sid = sid {
                withAnimation(.easeInOut(duration: 0.3)) {
                   
                    primaryParticipantId = sid
                }
            } 
        }) {
            ZStack(alignment: .bottom) {
                // Video view with mirroring support — fill square and crop
                MirroredParticipantView(participant: participant, shouldMirror: shouldMirror)
                    .frame(width: 80, height: 80)
                    .clipped()

                if !participant.isCameraEnabled() {
                    Rectangle()
                        .fill(Color.black.opacity(0.8))

                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }

                // Bottom Gradient Overlay
                LinearGradient(
                    gradient: Gradient(colors: [Color.black.opacity(0), Color(hex: "080060").opacity(0.5)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 35)

                // Participant name — use Popin-configured name for self
                Text(isLocalParticipant ? (localDisplayName ?? participant.name ?? "Unknown") : (participant.name ?? "Unknown"))
                    .font(.system(size: 10))
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 6)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Top Right Indicators
                VStack(spacing: 3) {
                    if !participant.isMicrophoneEnabled() {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
                                .frame(width: 16, height: 16)
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.white)
                        }
                    }
                    // ZStack {
                    //     Circle()
                    //         .fill(Color.black.opacity(0.7))
                    //         .frame(width: 16, height: 16)
                    //     SignalStrengthView(quality: participant.connectionQuality)
                    //         .scaleEffect(0.5)
                    // }
                }
                .padding(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "FFFFFF"), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SignalStrengthView: View {
    let quality: ConnectionQuality

    private var barCount: Int {
        switch quality {
        case .excellent: return 4
        case .good: return 3
        case .poor: return 2
        default: return 1
        }
    }

    private var barColor: Color {
        switch quality {
        case .excellent: return .green
        case .good: return .yellow
        case .poor: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(quality != .unknown && index < barCount ? barColor : Color.white.opacity(0.3))
                    .frame(width: 3, height: CGFloat(6 + index * 4))
            }
        }
    }
}
#endif

