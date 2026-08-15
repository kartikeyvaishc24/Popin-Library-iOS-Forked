//
//  ProductDetailsView.swift
//  Popin
//
//  Created for Product Details Display
//

import SwiftUI
import UIKit

#if canImport(UIKit)
// MARK: - Product Details View

struct ProductDetailsView: View {
    let productId: String?
    let productName: String?
    let productUrl: String?
    let productImageUrl: String?
    let productDescription: String?
    let productExtra: String?
    let onBackClick: (() -> Void)?
    let secondaryProductText: String

    private var primaryText: String {
        return productName ?? productId ?? ""
    }

    private var secondaryText: String {
        return secondaryProductText
    }

    private func openProductUrl() {
        guard let urlString = productUrl,
              let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }
        onBackClick?()
        UIApplication.shared.open(url)
    }

    var body: some View {
        if let id = productId, !id.isEmpty {
            Button(action: openProductUrl) {
                HStack(alignment: .center, spacing: 8) {
                    // Text content - two lines
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primaryText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(secondaryText)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)

                            // Right arrow in circle
                            ZStack {
                                Circle()
                                    .fill(Color(red: 2/255, green: 6/255, blue: 24/255).opacity(0.2))
                                    .frame(width: 14, height: 14)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 6, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Top Controls View

struct TopControls: View {
    @EnvironmentObject private var configHolder: PopinConfigHolder

    let onPipClick: () -> Void
    var leadingButtonIcon: String = "chevron.down"
    var productDetailsClickable: Bool = true

    // Product data
    let productId: String?
    let productName: String?
    let productUrl: String?
    let productImageUrl: String?
    let productDescription: String?
    let productExtra: String?

    var body: some View {
        // Controls content
        HStack(alignment: .center, spacing: 4) {
            // Close Button (Top Left)
            if !configHolder.config.hideBackButton {
                Button(action: onPipClick) {
                    Image(systemName: leadingButtonIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(hex: "433F40"))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Product Details
            Spacer().frame(width: 8)
            ProductDetailsView(
                productId: productId,
                productName: productName,
                productUrl: productUrl,
                productImageUrl: productImageUrl,
                productDescription: productDescription,
                productExtra: productExtra,
                onBackClick: productDetailsClickable ? onPipClick : nil,
                secondaryProductText: configHolder.config.secondaryProductText
            )
            .allowsHitTesting(productDetailsClickable)
            .truncationMode(.tail)

            Spacer(minLength: 96)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .background(
            // Gradient background - extends to top of screen
            VStack {
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.6), location: 0.0),
                        .init(color: Color.black.opacity(0.6), location: 0.15),
                        .init(color: Color.black.opacity(0.4), location: 0.3),
                        .init(color: Color.black.opacity(0.2), location: 0.5),
                        .init(color: Color.black.opacity(0), location: 0.7),
                        .init(color: Color.black.opacity(0), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 240)
            }
            .ignoresSafeArea(.all, edges: .top)
        )
    }
}
#endif
