#if canImport(UIKit)
//
//  BroadcastPickerWrapper.swift
//  Popin
//
//  Created for Broadcast Extension Support
//

import SwiftUI
import ReplayKit

struct BroadcastPickerWrapper: UIViewRepresentable {
    var extensionBundleIdentifier: String {
        guard let bundleID = Bundle.main.bundleIdentifier else {
            return "to.popin.seller.broadcast"
        }
        return bundleID + ".broadcast"
    }
    
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let identifier = extensionBundleIdentifier
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        picker.preferredExtension = identifier
        picker.showsMicrophoneButton = false
        
        // Remove default image from the internal button
        for view in picker.subviews {
            if let button = view as? UIButton {
                button.imageView?.image = nil
                button.setImage(nil, for: .normal)
                button.setImage(nil, for: .highlighted)
            }
        }
        
        // Add our custom look
        let customView = UIHostingController(rootView:
            ZStack {
                Circle()
                    .fill(Color(hex: "433F40").opacity(0.8))
                    .frame(width: 44, height: 44)

                Image(systemName: "rectangle.on.rectangle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
        )
        customView.view.backgroundColor = .clear
        customView.view.isUserInteractionEnabled = false // Let touches pass to the picker
        customView.view.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        
        picker.addSubview(customView.view)
        
        // Center the custom view within the picker
        customView.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customView.view.centerXAnchor.constraint(equalTo: picker.centerXAnchor),
            customView.view.centerYAnchor.constraint(equalTo: picker.centerYAnchor),
            customView.view.widthAnchor.constraint(equalToConstant: 44),
            customView.view.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        let identifier = extensionBundleIdentifier
        if uiView.preferredExtension != identifier {
            uiView.preferredExtension = identifier
        }
    }
}
#endif
