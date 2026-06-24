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

class Coordinator: NSObject, WKNavigationDelegate {
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
        
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
