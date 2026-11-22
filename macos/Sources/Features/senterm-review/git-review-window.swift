import AppKit
import WebKit

@MainActor
final class GitReviewWindow: NSWindowController, NSWindowDelegate {
    private static var openWindows: Set<GitReviewWindow> = []

    static func open(directory: String, assets: URL? = Bundle.main.resourceURL?.appendingPathComponent("dist")) {
        guard let assets, FileManager.default.fileExists(atPath: assets.appendingPathComponent("index.html").path) else {
            let alert = NSAlert()
            alert.messageText = "git review resources are missing"
            alert.informativeText = "rebuild the app with macos/build.nu."
            alert.runModal()
            return
        }

        let review = ReviewPage(directory: directory, assets: assets)
        let window = NSWindow(contentViewController: review)
        window.title = "git changes"
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 25 / 255, green: 26 / 255, blue: 27 / 255, alpha: 1)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 1280, height: 790))
        window.contentMinSize = NSSize(width: 640, height: 360)
        window.center()
        let controller = GitReviewWindow(window: window)
        window.delegate = controller
        openWindows.insert(controller)
        controller.showWindow(nil)
    }

    func windowWillClose(_ notification: Notification) {
        (window?.contentViewController as? ReviewPage)?.disconnect()
        Self.openWindows.remove(self)
    }
}

@MainActor
private final class ReviewPage: NSViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private struct File: Encodable {
        let path: String
        let status: String
    }

    private struct Listing: Encodable {
        let files: [File]
        let revision: String?
        let additions: Int?
        let deletions: Int?
    }

    private struct Response: Encodable {
        let id: Int
        var list: Listing?
        var comparison: GitChanges.Comparison?
        var error: String?
    }

    private let directory: String
    private let assets: URL
    private var work: Task<Void, Never>?
    private var webView: WKWebView?

    init(directory: String, assets: URL) {
        self.directory = directory
        self.assets = assets
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(self, name: "review")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.underPageBackgroundColor = NSColor(srgbRed: 25 / 255, green: 26 / 255, blue: 27 / 255, alpha: 1)
        webView.navigationDelegate = self
        view = webView
        self.webView = webView
        webView.loadFileURL(pageURL, allowingReadAccessTo: pageURL.deletingLastPathComponent())
    }

    func disconnect() {
        work?.cancel()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "review")
        webView?.stopLoading()
    }

    private var pageURL: URL {
        assets.appendingPathComponent("index.html").standardizedFileURL.resolvingSymlinksInPath()
    }

    private func isReviewPage(_ url: URL?) -> Bool {
        guard let url, url.isFileURL, url.host == nil || url.host == "" || url.host == "localhost" else { return false }
        // WebKit can return a different representation of the same bundle file URL.
        return url.standardizedFileURL.resolvingSymlinksInPath().path == pageURL.path
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard navigationAction.targetFrame?.isMainFrame != false,
              isReviewPage(navigationAction.request.url) else { return .cancel }
        return .allow
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        showLoadFailure()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadFailure()
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showLoadFailure()
    }

    private func showLoadFailure() {
        let label = NSTextField(labelWithString: "could not load git changes. close this window and try again.")
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, isReviewPage(message.frameInfo.request.url),
              let request = message.body as? [String: Any], let id = request["id"] as? Int,
              let action = request["action"] as? String, action == "list" || action == "file",
              let value = request["scope"] as? String, let scope = GitChanges.Scope(rawValue: value) else { return }
        let path = request["path"] as? String
        let directory = self.directory
        work?.cancel()
        work = Task { [weak self] in
            let job = Task.detached(priority: .userInitiated) {
                Self.response(directory: directory, scope: scope, action: action, path: path, id: id)
            }
            let response = await withTaskCancellationHandler { await job.value } onCancel: { job.cancel() }
            guard !Task.isCancelled, let self, let webView,
                  let encoded = try? JSONEncoder().encode(response),
                  let data = try? JSONSerialization.jsonObject(with: encoded) else { return }
            _ = try? await webView.callAsyncJavaScript("window.renderReview(response)", arguments: ["response": data], in: nil, contentWorld: .page)
        }
    }

    nonisolated private static func response(
        directory: String, scope: GitChanges.Scope, action: String, path: String?, id: Int
    ) -> Response {
        do {
            let files = try GitChanges.files(in: directory, scope: scope)
            try Task.checkCancellation()
            if action == "file", let path {
                return Response(id: id, comparison: try GitChanges.comparison(in: files, path: path, scope: scope))
            }
            let totals = try? GitChanges.totals(in: files, scope: scope)
            let list = Listing(files: files.paths.map { File(path: $0, status: files.status[$0] ?? "") },
                               revision: files.revision, additions: totals?.additions, deletions: totals?.deletions)
            return Response(id: id, list: list)
        } catch {
            return Response(id: id, error: error.localizedDescription)
        }
    }
}
