import SwiftUI

/// Điểm vào của ứng dụng: một WKWebView toàn màn hình chạy website Hi. Studio.
@main
struct HiStudioApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(red: 15.0 / 255.0, green: 23.0 / 255.0, blue: 42.0 / 255.0)
                    .ignoresSafeArea()
                WebContainer()
                    .ignoresSafeArea()
            }
            .onOpenURL { url in
                // histudio://auth?code=... (đăng nhập Google xong, hệ thống mở lại app)
                NotificationCenter.default.post(name: .hsOpenURL, object: url)
            }
        }
    }
}

struct WebContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController {
        return WebViewController()
    }

    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {}
}
