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

class Coordinator: NSObject, WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mobileConfigHandler", let xmlString = message.body as? String else { return }
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("ShadowVPN.mobileconfig")
        
        do {
            try xmlString.write(to: tempFile, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                let docController = UIDocumentInteractionController(url: tempFile)
                docController.uti = "com.apple.mobileconfig"
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    docController.presentOpenInMenu(from: .zero, in: rootVC.view, animated: true)
                }
            }
        } catch {
            print("Ошибка: \(error)")
        }
    }
}

struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "mobileConfigHandler")
        let webView = WKWebView(frame: .zero, configuration: config)
        
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        WebView().ignoresSafeArea()
    }
}
