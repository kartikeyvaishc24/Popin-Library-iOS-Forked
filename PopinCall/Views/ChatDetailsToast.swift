//
//  ChatDetailsToast.swift
//  PopinCall
//
//  Created by Assistant on 05/02/26.
//

import SwiftUI

#if canImport(UIKit)

/// A chat message toast that appears when new messages arrive
/// Tapping on it opens the chat window
struct ChatDetailsToast: View {
    let message: String
    let showBadge: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background with blur effect (frosted glass)
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                // Foreground content - left aligned
                HStack(spacing: 8) {
                    // Message bubble icon with badge
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)

                        // Unread badge (red dot)
                        if showBadge {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }

                    // Message text
                    Text(message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ZStack {
        Color.gray
        VStack(spacing: 20) {
            ChatDetailsToast(
                message: "Hello, I am not able to hear you",
                showBadge: true,
                onTap: {}
            )
            .padding(.horizontal, 40)

            ChatDetailsToast(
                message: "How can I help you today?",
                showBadge: false,
                onTap: {}
            )
            .padding(.horizontal, 40)

            ChatDetailsToast(
                message: "This is a very long message that should be truncated with ellipsis when it exceeds the available space",
                showBadge: true,
                onTap: {}
            )
            .padding(.horizontal, 40)
        }
    }
}

#endif
