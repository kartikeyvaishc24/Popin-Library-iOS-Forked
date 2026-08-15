//
//  ParticipantTile.swift
//  Popin
//
//  Created by Ashwin on 09/09/25.
//

import SwiftUI
import LiveKit
import LiveKitComponents

struct ParticipantTile: View {
    @ObservedObject var participant: Participant
    @Binding var primaryParticipantId: String?

    var body: some View {
        VStack(spacing: 4) {
            // Participant video view with mute indicator
            ZStack(alignment: .bottomLeading) {
                // Video view or no video placeholder
                ZStack {
                    ParticipantView(showInformation: false)
                        .environmentObject(participant)
                        .frame(width: 90, height: 120)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )

                    // Show background and icon when no video
                    if !participant.isCameraEnabled() {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.8))
                            .frame(width: 90, height: 120)

                        Image(systemName: "video.slash.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                // Muted icon in bottom left (only shown when muted)
                if !participant.isMicrophoneEnabled() {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 24, height: 24)

                        Image(systemName: "mic.slash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                    }
                    .padding(6)
                }
            }

            // Participant name below
            Text(participant.name ?? "Unknown")
                .font(.system(size: 12))
                .fontWeight(Font.Weight.medium)
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 90)
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.3)) {
                primaryParticipantId = participant.sid?.stringValue
            }
        }
    }
}
