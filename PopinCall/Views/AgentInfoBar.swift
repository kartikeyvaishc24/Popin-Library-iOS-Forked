//
//  AgentInfoBar.swift
//  PopinCall
//

import SwiftUI
import LiveKit

#if canImport(UIKit)
struct AgentInfoBar: View {
    let agent: Agent
    let expertDesignation: String
    let participant: Participant?

    var body: some View {
        HStack(spacing: 12) {
            // Agent photo (left)
            if let imageUrl = agent.image, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        agentPlaceholder
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                agentPlaceholder
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            // Designation + name
            VStack(alignment: .leading, spacing: 2) {
                Text("Your \(expertDesignation)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))

                Text(agent.name ?? "Agent")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            Spacer()

            // Mute + signal indicators (right)
            if let participant = participant {
                AgentBarIndicators(participant: participant)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var agentPlaceholder: some View {
        Color.gray.opacity(0.3)
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
            )
    }
}

private struct AgentBarIndicators: View {
    @ObservedObject var participant: Participant

    var body: some View {
        HStack(spacing: 7) {
            // Mute indicator
            if !participant.isMicrophoneEnabled() {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 29, height: 29)
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
            }

            // Signal strength (hidden)
            // ZStack {
            //     Circle()
            //         .fill(Color.black.opacity(0.5))
            //         .frame(width: 29, height: 29)
            //     SignalStrengthView(quality: participant.connectionQuality)
            //         .scaleEffect(0.63)
            // }
        }
    }
}
#endif
