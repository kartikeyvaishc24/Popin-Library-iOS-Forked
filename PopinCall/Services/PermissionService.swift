//
//  PermissionService.swift
//  PopinCall
//

import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit

/// Handles microphone and camera permission requests.
/// Communicates upward via callbacks — never references Popin.shared.
class PermissionService {

    /// Request permissions for an outgoing call. Handles denied state by showing settings alert.
    func requestForOutgoingCall(
        audioOnly: Bool,
        onGranted: @escaping () -> Void,
        onDenied: @escaping () -> Void
    ) {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .denied {
            PopinLogger.shared.log("PermissionService: Microphone previously denied, showing settings alert")
            DispatchQueue.main.async { [weak self] in
                self?.showDeniedAlert(audioOnly: audioOnly, onCancel: onDenied)
            }
            return
        }

        if !audioOnly && AVCaptureDevice.authorizationStatus(for: .video) == .denied {
            PopinLogger.shared.log("PermissionService: Camera previously denied, showing settings alert")
            DispatchQueue.main.async { [weak self] in
                self?.showDeniedAlert(audioOnly: audioOnly, onCancel: onDenied)
            }
            return
        }

        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            if !micGranted {
                PopinLogger.shared.log("PermissionService: Microphone denied")
                DispatchQueue.main.async { onDenied() }
                return
            }
            if audioOnly {
                PopinLogger.shared.log("PermissionService: mic=granted, audioOnlyMode=true")
                DispatchQueue.main.async { onGranted() }
            } else {
                AVCaptureDevice.requestAccess(for: .video) { cameraGranted in
                    PopinLogger.shared.log("PermissionService: mic=granted, camera=\(cameraGranted)")
                    DispatchQueue.main.async {
                        cameraGranted ? onGranted() : onDenied()
                    }
                }
            }
        }
    }

    /// Request permissions for an incoming call. On denial, provides an error message.
    func requestForIncomingCall(
        audioOnly: Bool,
        onGranted: @escaping () -> Void,
        onDenied: @escaping (String) -> Void
    ) {
        AVCaptureDevice.requestAccess(for: .audio) { micGranted in
            if !micGranted {
                PopinLogger.shared.log("PermissionService: Incoming - Microphone denied")
                DispatchQueue.main.async {
                    onDenied("Microphone access is required for calls. Please enable it in Settings.")
                }
                return
            }
            if audioOnly {
                PopinLogger.shared.log("PermissionService: Incoming - mic=granted, audioOnlyMode=true")
                DispatchQueue.main.async { onGranted() }
            } else {
                AVCaptureDevice.requestAccess(for: .video) { cameraGranted in
                    PopinLogger.shared.log("PermissionService: Incoming - mic=granted, camera=\(cameraGranted)")
                    DispatchQueue.main.async {
                        if cameraGranted {
                            onGranted()
                        } else {
                            onDenied("Camera access is required for calls. Please enable it in Settings.")
                        }
                    }
                }
            }
        }
    }

    private func showDeniedAlert(audioOnly: Bool, onCancel: @escaping () -> Void) {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first else {
            onCancel()
            return
        }

        let topVC = topViewController(base: rootVC) ?? rootVC
        let needsCamera = !audioOnly
        let title = needsCamera ? "Permissions Required" : "Microphone Permission Required"
        let message = needsCamera
            ? "Microphone and camera access are required for calls. Please enable them in Settings."
            : "Microphone access is required for calls. Please enable it in Settings."

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            onCancel()
        })
        topVC.present(alert, animated: true)
    }

    private func topViewController(base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

#endif
