//
//  NetworkToastView.swift
//  PopinCall
//
//  Created by Assistant on 10/02/26.
//

import SwiftUI

#if canImport(UIKit)

/// Badge type matching Android's BadgeWithIcon types
enum NetworkToastType {
    case warning    // type 0: yellow icon (exclamationmark.triangle.fill)
    case success    // type 1: green icon (checkmark.circle.fill)
    case info       // type 2: white icon (info.circle.fill)
}

/// A network status badge that appears at the top of the call screen.
/// Matches Android's BadgeWithIcon composable - capsule shape with blur background,
/// icon and text.
struct NetworkToastView: View {
    let text: String
    let type: NetworkToastType

    private var iconName: String {
        switch type {
        case .warning: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch type {
        case .warning: return Color(red: 0.973, green: 0.843, blue: 0.459) // #F8D775
        case .success: return .green
        case .info:    return .white
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        VStack(spacing: 16) {
            NetworkToastView(text: "Your network lost", type: .warning)
            NetworkToastView(text: "Expert's network lost", type: .warning)
            NetworkToastView(text: "You're back online", type: .success)
            NetworkToastView(text: "Expert rejoined", type: .success)
            NetworkToastView(text: "Trying to reconnect...", type: .warning)
            NetworkToastView(text: "You're on mute", type: .info)
        }
    }
}

#endif
