import SwiftUI
import WebKit

@main
struct HelloAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        WebView()
            .ignoresSafeArea()
    }
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "proxyChecker")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url, url.scheme == "data" {
                saveAndOpenProfile(dataUrl: url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func saveAndOpenProfile(dataUrl: URL) {
            guard let data = try? Data(contentsOf: dataUrl) else { return }
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("ShadowVPN-\(Int(Date().timeIntervalSince1970)).mobileconfig")
            do {
                try data.write(to: fileURL)
                DispatchQueue.main.async {
                    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let rootVC = scene.windows.first?.rootViewController else { return }
                    let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                    rootVC.present(activityVC, animated: true)
                }
            } catch {
                print("Ошибка сохранения профиля: \(error)")
            }
        }

        // ===== Реальная проверка прокси =====
        // JS зовёт: window.webkit.messageHandlers.proxyChecker.postMessage({id, host, port})
        // Swift реально подключается через host:port как через HTTP/HTTPS прокси
        // и пробует дойти до тестового URL. Если ответ пришёл — прокси жив.
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "proxyChecker",
                  let dict = message.body as? [String: Any],
                  let id = dict["id"] as? String,
                  let host = dict["host"] as? String else {
                return
            }

            var port = 0
            if let p = dict["port"] as? Int {
                port = p
            } else if let p = dict["port"] as? String, let parsed = Int(p) {
                port = parsed
            }
            guard port > 0 else { return }

            checkProxy(host: host, port: port) { [weak self] alive, latencyMs in
                let escapedId = id.replacingOccurrences(of: "'", with: "\\'")
                let js = "window.onProxyCheckResult && window.onProxyCheckResult('\(escapedId)', \(alive), \(latencyMs));"
                DispatchQueue.main.async {
                    self?.webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }

        func checkProxy(host: String, port: Int, completion: @escaping (Bool, Int) -> Void) {
            let startTime = Date()
            let config = URLSessionConfiguration.ephemeral
            config.connectionProxyDictionary = [
                "HTTPEnable": true,
                "HTTPProxy": host,
                "HTTPPort": port,
                "HTTPSEnable": true,
                "HTTPSProxy": host,
                "HTTPSPort": port
            ]
            config.timeoutIntervalForRequest = 6
            config.timeoutIntervalForResource = 6

            let session = URLSession(configuration: config)
            guard let testUrl = URL(string: "http://www.gstatic.com/generate_204") else {
                completion(false, 0)
                return
            }
            var request = URLRequest(url: testUrl)
            request.timeoutInterval = 6

            let task = session.dataTask(with: request) { _, response, error in
                let elapsed = Int(Date().timeIntervalSince(startTime) * 1000)
                if let httpResponse = response as? HTTPURLResponse, error == nil {
                    completion(httpResponse.statusCode < 500, elapsed)
                } else {
                    completion(false, elapsed)
                }
            }
            task.resume()
        }
    }
}
