//
//  Utilities.swift
//  PopinCall
//
//  Created by Ashwin Nath on 17/11/22.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .noData:
            return "No data received from server."
        case .decodingError:
            return "Failed to decode server response."
        case .serverError(let statusCode):
            return "Server error (HTTP \(statusCode))."
        }
    }
}

class Utilities: NSObject {
    
    private override init() {
        // Can't initialize a singleton
    }
    
    // MARK:- Shared Instance
    static let shared = Utilities()
    
    func getHeaders() -> [String: String] {
        var headers: [String: String] = [:]

        headers["User-Agent"] = "PopinSDK/iOS/\(Popin.sdkVersion)"

        if let token = getUser()?.token {
            headers["Accept"] = "application/json"
            headers["Authorization"] = "Bearer" + " " + token
        }

        return headers
    }
    
    func saveUser(user: UserModel?) {
        let userDefaults = UserDefaults.standard
        do {
            try userDefaults.setObject(user, forKey: "authenticatedUser")
        } catch {
        }
    }
    
    func getUser() -> UserModel? {
        let userDefaults = UserDefaults.standard
        do {
            let user = try userDefaults.getObject(forKey: "authenticatedUser", castTo: UserModel.self)
            return user
        } catch {
        }
        return nil;
    }
    
    func getUserToken() -> String {
        return getUser()?.token ?? ""
    }
    
    func getChannel() -> String {
        return getUser()?.channel ?? ""
    }
    
    func savePushToken(token: String) {
        UserDefaults.standard.set(token, forKey: "push_token")
    }
    
    func getPushToken() -> String {
        return UserDefaults.standard.string(forKey: "push_token") ?? ""
    }
    
    func sendPushToken(token: String) {
        // Implementation stub or copied from working example if needed
        // Assuming serverURL is globally available
        let urlString = serverURL + "/user/fcm/update";
        let parameters: [String: Any] = ["mobile_token": token, "type" : 2];
        Task {
            do {
                let _: String? = try await request(urlString: urlString, method: "POST", parameters: parameters)
            } catch {
            }
        }
    }
    
    func saveSeller(seller_id: Int) {
        UserDefaults.standard.set(seller_id, forKey: "popinSeller")
    }
    
    func getSeller() -> Int {
        return UserDefaults.standard.integer(forKey: "popinSeller");
    }
    
    func isConnected() -> Bool {
        let dateDouble=UserDefaults.standard.double(forKey: "agent_connect");
        if (dateDouble > 0) {
            let captureDate = Date(timeIntervalSince1970: dateDouble)
            let difference = Int(Date().timeIntervalSince(captureDate))
            if (difference < 3600)  { // 1 hour
                return true;
            }
        }
        return false;
    }
    
    func saveConnected() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "agent_connect")
    }

    func clearConnected() {
        UserDefaults.standard.removeObject(forKey: "agent_connect")
    }
    
    // MARK: - Network Helper
    
    func request<T: Decodable>(urlString: String, method: String = "GET", parameters: [String: Any]? = nil, headers: [String: String]? = nil) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        let allHeaders = headers ?? getHeaders()
        for (key, value) in allHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let parameters = parameters {
            if method == "GET" {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                components?.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
                request.url = components?.url
            } else {
                // Form URL Encoded
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                let parameterArray = parameters.map { key, value -> String in
                    let percentEncodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? key
                    let percentEncodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "\(value)"
                    return "\(percentEncodedKey)=\(percentEncodedValue)"
                }
                request.httpBody = parameterArray.joined(separator: "&").data(using: .utf8)
            }
        }
        
        PopinLogger.shared.log("API Request: \(method) \(request.url?.absoluteString ?? urlString)")
        if let parameters = parameters {
            PopinLogger.shared.log("API Parameters: \(parameters)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            let responseText = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
            PopinLogger.shared.log("API Response: \(httpResponse.statusCode) \(responseText)")
            if !(200...299).contains(httpResponse.statusCode) {
                 throw NetworkError.serverError(statusCode: httpResponse.statusCode)
            }
        }
        
        if T.self == String.self {
             return String(data: data, encoding: .utf8) as! T
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
             // If decoding fails, it might be that the response is not what we expect or empty
             // Check for specific cases if needed
             throw error
        }
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let generalDelimitersToEncode = ":#[]@" // does not include "?" or "/" due to RFC 3986 - Section 3.4
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        return allowed
    }()
}

#if canImport(UIKit)
extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")
        
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }
}
extension UIViewController {
    func registerKeyboardTap() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func unregisterKeyboardTap() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if self.view.frame.origin.y == 0 {
                self.view.frame.origin.y -= keyboardSize.height
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        if self.view.frame.origin.y != 0 {
            self.view.frame.origin.y = 0
        }
    }
}
extension UITextField {
    @IBInspectable var placeholderColor: UIColor {
        get {
            return attributedPlaceholder?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor ?? .clear
        }
        set {
            guard let attributedPlaceholder = attributedPlaceholder else { return }
            let attributes: [NSAttributedString.Key: UIColor] = [.foregroundColor: newValue]
            self.attributedPlaceholder = NSAttributedString(string: attributedPlaceholder.string, attributes: attributes)
        }
    }
}
#endif
