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

// Делегат, который перехватывает data: и превращает в реальный файл
class Coordinator: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        // Перехватываем ссылку data:
        if let url = navigationAction.request.url, url.scheme == "data" {
            // 1. Сохраняем содержимое data: во временный файл
            if let data = try? Data(contentsOf: url) {
                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("ShadowVPN.mobileconfig")
                try? data.write(to: tempFile)
                
                // 2. Открываем ЭТОТ файл в Safari (iOS сама выкинет окно профиля)
                UIApplication.shared.open(tempFile, options: [:], completionHandler: nil)
            }
            
            // 3. Блокируем загрузку в WebView
            decisionHandler(.cancel)
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
