import SwiftUI
import WebKit

struct TikZPreviewView: View {
    let tikzCode: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            WebView(htmlContent: generateHTML(for: tikzCode))
                .navigationTitle("TikZ Live Preview")
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Chiudi") { dismiss() } } }
        }
    }
    
    private func generateHTML(for code: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://tikzjax.com/v1/tikzjax.js"></script>
            <style>body { display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; background-color: white; }</style>
        </head>
        <body><script type="text/tikz">\(code)</script></body>
        </html>
        """
    }
}

struct WebView: UIViewRepresentable {
    let htmlContent: String
    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ uiView: WKWebView, context: Context) { uiView.loadHTMLString(htmlContent, baseURL: nil) }
}
