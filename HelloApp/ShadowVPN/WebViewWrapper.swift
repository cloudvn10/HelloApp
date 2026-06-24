import SwiftUI
import WebKit

struct WebViewWrapper: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> ViewController {
        ViewController()
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // Ничего — WKWebView сам управляет контентом
    }
}
