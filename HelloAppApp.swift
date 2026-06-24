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

class Coordinator: NSObject, WKScriptMessageHandler, UIDocumentInteractionControllerDelegate {
    // ВАЖНО: Храним контроллер здесь, чтобы он не удалялся из памяти
    var docInteractionController: UIDocumentInteractionController?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "mobileConfigHandler", let xmlString = message.body as? String else { return }
        
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("ShadowVPN.mobileconfig")
        
        do {
            try xmlString.write(to: tempFile, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                // Создаем и сохраняем контроллер в свойство класса
                self.docInteractionController = UIDocumentInteractionController(url: tempFile)
                self.docInteractionController?.delegate = self
                self.docInteractionController?.uti = "com.apple.mobileconfig"
                
                // Ищем текущее окно для отображения
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    
                    // Показываем меню
                    let success = self.docInteractionController?.presentOpenInMenu(from: .zero, in: rootVC.view, animated: true)
                    
                    if !success! {
                        print("Ошибка: Не удалось показать меню открытия")
                    }
                }
            }
        } catch {
            print("Ошибка записи файла: \(error)")
        }
    }
    
    // Делегат нужен для корректной работы UIDocumentInteractionController
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }.first!.rootViewController!
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
