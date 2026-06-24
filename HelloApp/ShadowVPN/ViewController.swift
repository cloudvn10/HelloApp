import UIKit
import WebKit

final class ViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        loadHTML()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "proxyChecker")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false

        if #available(iOS 15.0, *) {
            webView.underPageBackgroundColor = .black
        }

        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func loadHTML() {
        guard let htmlURL = Bundle.main.url(forResource: "shadowvpn", withExtension: "html") else {
            webView.loadHTMLString(
                "<body style='background:#060606;color:red;padding:40px;font-family:sans-serif;'>shadowvpn.html не найден в бандле</body>",
                baseURL: nil
            )
            return
        }
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "proxyChecker",
              let body = message.body as? [String: Any],
              let id   = body["id"]   as? String,
              let host = body["host"]  as? String,
              let port = body["port"]  as? Int
        else { return }

        checkProxy(id: id, host: host, port: port)
    }

    // MARK: - Proxy Checker

    private func checkProxy(id: String, host: String, port: Int) {
        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [
            "HTTPEnable": NSNumber(value: 1),
            "HTTPProxy":  host as NSString,
            "HTTPPort":   NSNumber(value: port)
        ]
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8

        let session = URLSession(configuration: config)
        let url = URL(string: "http://example.com")!
        let startTime = Date()

        session.dataTask(with: url) { [weak self] _, response, error in
            let latency = Int(Date().timeIntervalSince(startTime) * 1000)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let alive = (error == nil) && (statusCode == 200)

            DispatchQueue.main.async {
                let safeId = id.replacingOccurrences(of: "\\", with: "\\\\")
                                  .replacingOccurrences(of: "'", with: "\\'")
                let js = "window.onProxyCheckResult('\(safeId)',\(alive),\(latency))"
                self?.webView.evaluateJavaScript(js, completionHandler: nil)
            }
        }.resume()
    }

    // MARK: - WKNavigationDelegate (перехват .mobileconfig)

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              url.scheme == "data",
              let base64Str = url.absoluteString.components(separatedBy: "base64,").last,
              let data = Data(base64Encoded: base64Str, options: .ignoreUnknownCharacters)
        else {
            decisionHandler(.allow)
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShadowVPN.mobileconfig")
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(
                x: view.bounds.midX, y: view.bounds.midY,
                width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        present(activityVC, animated: true)

        decisionHandler(.cancel)
    }
}
