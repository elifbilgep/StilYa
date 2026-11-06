//
//  WebView.swift
//  StilYa
//
//  Created by Elif Bilge Parlak on 23/12/2024.
//

import SwiftUI
import WebKit

// MARK: - WebView UIViewRepresentable

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Load URL only once when creating the view
        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if URL actually changed
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

// MARK: - Full Screen WebView Sheet

struct WebViewSheet: View {
    let title: String
    let url: URL
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                WebView(url: url, isLoading: $isLoading)

                if isLoading {
                    LoadingView(message: L10n.commonLoading)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Present a web view sheet
    func webViewSheet(
        isPresented: Binding<Bool>,
        title: String,
        url: URL
    ) -> some View {
        sheet(isPresented: isPresented) {
            WebViewSheet(title: title, url: url)
        }
    }
}

// MARK: - Constants for Legal URLs

struct LegalURLs {
    static let privacyPolicy = URL(string: "https://stilya.app/privacy")!
    static let termsOfUse = URL(string: "https://stilya.app/terms")!
}
