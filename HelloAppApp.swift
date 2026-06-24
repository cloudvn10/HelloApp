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

// Мостик для общения JS <-> Swift
class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    weak var webView: WKWebView?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String,
              action == "checkProxy",
              let host = body["host"] as? String,
              let portStr = body["port"] as? String,
              let port = Int(portStr) else { return }

        // Запускаем проверку в фоне, чтобы не вешать UI
        DispatchQueue.global(qos: .userInitiated).async {
            let isAlive = self.testProxy(host: host, port: port)
            let result: [String: Any] = [
                "action": "proxyResult",
                "host": host,
                "port": port,
                "alive": isAlive
            ]
            DispatchQueue.main.async {
                // Отправляем результат обратно в JS
                let js = "window.dispatchEvent(new CustomEvent('proxyResult', { detail: \(try! JSONSerialization.data(withJSONObject: result)) }))"
                self.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    // Реальная проверка прокси через нативный URLSession
    func testProxy(host: String, port: Int) -> Bool {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 5.0
        
        // Настраиваем прокси
        config.connectionProxyDictionary = [
            kCFNetworkProxiesHTTPEnable: true,
            kCFNetworkProxiesHTTPProxy: host,
            kCFNetworkProxiesHTTPPort: port,
            kCFNetworkProxiesHTTPSEnable: true,
            kCFNetworkProxiesHTTPSProxy: host,
            kCFNetworkProxiesHTTPSPort: port
        ]
        
        let session = URLSession(configuration: config)
        let semaphore = DispatchSemaphore(value: 0)
        var success = false
        
        // Пытаемся зайти на простой сайт через прокси
        let task = session.dataTask(with: URL(string: "https://www.google.com")!) { _, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, error == nil {
                success = true
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 6.0)
        
        return success
    }

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
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        // Добавляем обработчик сообщений из JS
        webView.configuration.userContentController.add(context.coordinator, name: "swiftProxyChecker")
        context.coordinator.webView = webView
        
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
