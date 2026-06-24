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

// Делегат для обработки кликов и открытия профиля
class Coordinator: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Если ссылка начинается с "data:", значит это наш сгенерированный профиль
        if let url = navigationAction.request.url, url.scheme == "data" {
            // Открываем этот профиль в системном Safari (iOS сама предложит его установить)
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel) // Не загружаем в WebView, а отправляем в браузер
            return
        }
        decisionHandler(.allow)
    }
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
