import UIKit
import WebKit
import SafariServices
import AuthenticationServices

/// Giữ yếu tham chiếu tới controller để tránh vòng lặp bộ nhớ với WKUserContentController.
final class ScriptProxy: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

final class WebViewController: UIViewController,
                               WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate,
                               WKScriptMessageHandler, ASWebAuthenticationPresentationContextProviding {

    private var web: WKWebView!
    private var authSession: ASWebAuthenticationSession?
    private var errorView: UIView!
    private var errorLabel: UILabel!
    private var lastDownload: URL?
    private let bg = UIColor(red: 15.0 / 255.0, green: 23.0 / 255.0, blue: 42.0 / 255.0, alpha: 1)

    // MARK: - Vòng đời

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bg

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Website nhận biết app qua "HiStudioApp" trong User-Agent (đăng nhập Google, menu app...).
        config.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1 HiStudioApp/1.0"

        let bridge = """
        window.HiStudioApp = {
          version: '1.0',
          menu: function () { window.webkit.messageHandlers.histudio.postMessage({a: 'menu'}); },
          reload: function () { window.webkit.messageHandlers.histudio.postMessage({a: 'reload'}); }
        };
        """
        let script = WKUserScript(source: bridge, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.userContentController.add(ScriptProxy(self), name: "histudio")

        web = WKWebView(frame: .zero, configuration: config)
        web.translatesAutoresizingMaskIntoConstraints = false
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isOpaque = false
        web.backgroundColor = bg
        web.scrollView.backgroundColor = bg
        view.addSubview(web)
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: view.topAnchor),
            web.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            web.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        buildErrorView()

        NotificationCenter.default.addObserver(forName: .hsShake, object: nil, queue: .main) { [weak self] _ in
            self?.showMenu()
        }
        NotificationCenter.default.addObserver(forName: .hsOpenURL, object: nil, queue: .main) { [weak self] note in
            if let url = note.object as? URL { self?.handleAuth(url) }
        }

        load()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Tải trang

    private func load() {
        errorView.isHidden = true
        web.load(URLRequest(url: Site.page("index.php?app=1")))
    }

    private func buildErrorView() {
        errorView = UIView()
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = bg
        errorView.isHidden = true

        let title = UILabel()
        title.text = "Không kết nối được"
        title.textColor = .white
        title.font = UIFont.boldSystemFont(ofSize: 20)
        title.textAlignment = .center

        errorLabel = UILabel()
        errorLabel.textColor = UIColor(white: 1, alpha: 0.7)
        errorLabel.font = UIFont.systemFont(ofSize: 14)
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center

        let retry = UIButton(type: .system)
        retry.setTitle("Thử lại", for: .normal)
        retry.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        retry.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        let change = UIButton(type: .system)
        change.setTitle("Đổi địa chỉ website", for: .normal)
        change.addTarget(self, action: #selector(changeTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, errorLabel, retry, change])
        stack.axis = .vertical
        stack.spacing = 14
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        errorView.addSubview(stack)
        view.addSubview(errorView)

        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -32)
        ])
    }

    @objc private func retryTapped() { load() }
    @objc private func changeTapped() { askAddress() }

    private func showError(_ message: String) {
        errorLabel.text = message + "\n\n" + Site.base.absoluteString
        errorView.isHidden = false
    }

    private func handleFailure(_ error: Error) {
        let e = error as NSError
        if e.domain == NSURLErrorDomain && e.code == NSURLErrorCancelled { return }
        if e.domain == "WebKitErrorDomain" && e.code == 102 { return } // tải xuống thay cho mở trang
        showError(e.localizedDescription)
    }

    // MARK: - Menu ứng dụng

    private func showMenu() {
        guard presentedViewController == nil else { return }
        let sheet = UIAlertController(title: "Hi. Studio", message: Site.base.absoluteString, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Tải lại trang", style: .default) { [weak self] _ in
            self?.web.reload()
        })
        sheet.addAction(UIAlertAction(title: "Về trang chủ", style: .default) { [weak self] _ in
            self?.load()
        })
        sheet.addAction(UIAlertAction(title: "Đổi địa chỉ website", style: .default) { [weak self] _ in
            self?.askAddress()
        })
        sheet.addAction(UIAlertAction(title: "Dùng địa chỉ mặc định", style: .default) { [weak self] _ in
            Site.save(nil)
            self?.load()
        })
        sheet.addAction(UIAlertAction(title: "Xóa dữ liệu lưu trên máy (đăng xuất)", style: .destructive) { [weak self] _ in
            let store = WKWebsiteDataStore.default()
            store.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                    DispatchQueue.main.async { self?.load() }
                }
            }
        })
        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel, handler: nil))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        present(sheet, animated: true)
    }

    private func askAddress() {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Địa chỉ website",
                                      message: "Nhập tên miền nơi bạn cài đặt Hi. Studio, ví dụ studioz.vn",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.text = Site.base.absoluteString
            field.keyboardType = .URL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Lưu", style: .default) { [weak self, weak alert] _ in
            let text = alert?.textFields?.first?.text ?? ""
            if Site.save(text) {
                self?.load()
            } else {
                self?.info("Địa chỉ không hợp lệ", "Hãy nhập một tên miền, ví dụ studioz.vn")
            }
        })
        present(alert, animated: true)
    }

    private func info(_ title: String, _ message: String) {
        guard presentedViewController == nil else { return }
        let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(a, animated: true)
    }

    // MARK: - Cầu nối JavaScript

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let action = body["a"] as? String else { return }
        DispatchQueue.main.async { [weak self] in
            if action == "menu" { self?.showMenu() }
            if action == "reload" { self?.web.reload() }
        }
    }

    // MARK: - Đăng nhập Google (trình duyệt hệ thống)

    private func startGoogleAuth(_ url: URL) {
        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "histudio") { [weak self] callback, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.authSession = nil
                if let callback = callback {
                    self.handleAuth(callback)
                } else {
                    self.load() // người dùng hủy: quay về màn hình đăng nhập
                }
            }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        authSession = session
        if !session.start() {
            authSession = nil
            UIApplication.shared.open(url)
        }
    }

    /// histudio://auth?code=XXXX  → web nhận phiên đăng nhập; ?err=... → báo lỗi.
    private func handleAuth(_ url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            let enc = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? code
            web.load(URLRequest(url: Site.page("api.php?applogin=" + enc)))
        } else {
            let msg = items.first(where: { $0.name == "err" })?.value ?? "Đăng nhập Google không thành công."
            let enc = msg.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            web.load(URLRequest(url: Site.page("index.php?app=1&glogin=err&gm=" + enc)))
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window ?? ASPresentationAnchor()
    }

    private func openInSafari(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            UIApplication.shared.open(url)
            return
        }
        if presentedViewController != nil {
            UIApplication.shared.open(url)
            return
        }
        present(SFSafariViewController(url: url), animated: true)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()

        if scheme == "histudio" {
            handleAuth(url)
            decisionHandler(.cancel)
            return
        }
        if ["tel", "mailto", "sms", "facetime", "maps"].contains(scheme) {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        if scheme == "http" || scheme == "https" {
            if navigationAction.shouldPerformDownload {
                decisionHandler(.download)
                return
            }
            let topLevel = navigationAction.targetFrame?.isMainFrame ?? false
            if topLevel && !Site.isOwn(url) {
                let host = (url.host ?? "").lowercased()
                if host == "accounts.google.com" {
                    startGoogleAuth(url)
                } else {
                    openInSafari(url)
                }
                decisionHandler(.cancel)
                return
            }
        } else if navigationAction.shouldPerformDownload {
            decisionHandler(.download) // blob: tải xuống từ trang
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
            return
        }
        if let http = navigationResponse.response as? HTTPURLResponse,
           let disp = http.value(forHTTPHeaderField: "Content-Disposition"),
           disp.lowercased().hasPrefix("attachment") {
            decisionHandler(.download)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        errorView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // MARK: - WKUIDelegate

    /// Liên kết mở cửa sổ mới (target=_blank, window.open) → mở bằng Safari trong app.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            let scheme = (url.scheme ?? "").lowercased()
            if scheme == "http" || scheme == "https" {
                openInSafari(url)
            }
        }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        guard presentedViewController == nil else { completionHandler(); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        guard presentedViewController == nil else { completionHandler(false); return }
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard presentedViewController == nil else { completionHandler(nil); return }
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(a.textFields?.first?.text)
        })
        present(a, animated: true)
    }

    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        let host = origin.host.lowercased()
        decisionHandler(host == (Site.base.host ?? "").lowercased() ? .grant : .prompt)
    }

    // MARK: - WKDownloadDelegate (tải tệp: PDF, ảnh, ZIP... → bảng chia sẻ/lưu của iOS)

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var name = suggestedFilename.replacingOccurrences(of: "/", with: "-")
        if name.isEmpty { name = "tep-tai-xuong" }
        let dest = dir.appendingPathComponent(name)
        lastDownload = dest
        completionHandler(dest)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = lastDownload else { return }
        lastDownload = nil
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            if let pop = share.popoverPresentationController {
                pop.sourceView = self.view
                pop.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
                pop.permittedArrowDirections = []
            }
            if self.presentedViewController == nil {
                self.present(share, animated: true)
            }
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        lastDownload = nil
        DispatchQueue.main.async { [weak self] in
            self?.info("Không tải được tệp", error.localizedDescription)
        }
    }
}
