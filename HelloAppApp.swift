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

// Делегат для перехвата сообщений от JavaScript
class Coordinator: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Проверяем, что пришло сообщение с нужным именем
        if message.name == "mobileConfigHandler", let xmlString = message.body as? String {
            // 1. Превращаем полученный текст XML в данные
            if let data = xmlString.data(using: .utf8) {
                // 2. Сохраняем во временный файл
                let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("ShadowVPN.mobileconfig")
                try? data.write(to: tempFile)
                
                // 3. Открываем файл в системе (появится окно установки профиля)
                DispatchQueue.main.async {
                    UIApplication.shared.open(tempFile, options: [:], completionHandler: nil)
                }
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // РЕГИСТРИРУЕМ ОБРАБОТЧИК СООБЩЕНИЙ ИЗ JS
        config.userContentController.add(context.coordinator, name: "mobileConfigHandler")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
