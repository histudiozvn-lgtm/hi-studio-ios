import Foundation
import UIKit

extension Notification.Name {
    static let hsShake = Notification.Name("hs.shake")
    static let hsOpenURL = Notification.Name("hs.openurl")
}

/// Lắc máy để mở menu ứng dụng (tải lại, đổi địa chỉ website...).
extension UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .hsShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}

/// Địa chỉ website mà app mở. Mặc định là studioz.vn; có thể đổi trong menu (lắc máy).
enum Site {
    static let defaultAddress = "https://studioz.vn"
    private static let key = "hs_site_url"

    static var base: URL {
        if let saved = UserDefaults.standard.string(forKey: key), let url = parse(saved) {
            return url
        }
        return URL(string: defaultAddress)!
    }

    /// Chuẩn hóa chuỗi người dùng nhập thành https://host/đường-dẫn/
    static func parse(_ raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var comps = URLComponents(string: text),
              let host = comps.host, host.contains(".") else { return nil }
        comps.scheme = "https"
        comps.query = nil
        comps.fragment = nil
        var path = comps.path
        if let r = path.range(of: "index.php") {
            path = String(path[path.startIndex..<r.lowerBound])
        }
        if !path.hasSuffix("/") { path += "/" }
        comps.path = path
        return comps.url
    }

    /// Lưu địa chỉ mới; truyền nil để quay về mặc định.
    @discardableResult
    static func save(_ raw: String?) -> Bool {
        guard let raw = raw else {
            UserDefaults.standard.removeObject(forKey: key)
            return true
        }
        guard let url = parse(raw) else { return false }
        UserDefaults.standard.set(url.absoluteString, forKey: key)
        return true
    }

    static func page(_ relative: String) -> URL {
        return URL(string: relative, relativeTo: base)!.absoluteURL
    }

    static func isOwn(_ url: URL) -> Bool {
        guard let h = url.host?.lowercased(), let b = base.host?.lowercased() else { return false }
        return h == b
    }
}
