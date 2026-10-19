import AppKit
import WebKit

@main
@MainActor
final class MailDesk: NSObject, NSApplicationDelegate, NSWindowDelegate,
                      WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, NSToolbarDelegate {
    static func main() {
        let app = NSApplication.shared
        let delegate = MailDesk()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }

    private var window: NSWindow!
    private var webView: WKWebView!
    private var progress: NSProgressIndicator!
    private var observations: [NSKeyValueObservation] = []
    private var downloads: [WKDownload: (temporary: URL, directory: URL, destination: URL)] = [:]
    private let homeURL = URL(string: "https://mail.proton.me/")!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenus()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.setAccessibilityLabel("Proton Mail")

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "MailDesk"
        window.subtitle = "mail.proton.me"
        window.minSize = NSSize(width: 780, height: 540)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setFrameAutosaveName("MailDeskWindow")
        window.center()
        let toolbar = NSToolbar(identifier: "MailDeskToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unified

        let content = NSView()
        progress = NSProgressIndicator()
        progress.style = .bar
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.isHidden = true
        for view in [webView!, progress!] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            progress.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            progress.topAnchor.constraint(equalTo: content.topAnchor),
            progress.heightAnchor.constraint(equalToConstant: 3),
        ])
        window.contentView = content
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.progress.doubleValue = view.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.progress.isHidden = !view.isLoading }
            },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.window.subtitle = view.url?.host ?? "MailDesk" }
            },
        ]
        showWindow()
        webView.load(URLRequest(url: homeURL))
    }

    @objc private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }
    @objc private func goHome() { webView.load(URLRequest(url: homeURL)) }
    @objc private func reload() { webView.reload() }
    @objc private func back() { webView.goBack() }
    @objc private func forward() { webView.goForward() }
    @objc private func zoomIn() { webView.pageZoom = min(2.0, webView.pageZoom + 0.1) }
    @objc private func zoomOut() { webView.pageZoom = max(0.6, webView.pageZoom - 0.1) }
    @objc private func actualSize() { webView.pageZoom = 1 }
    @objc private func openInBrowser() {
        let url = webView.url ?? homeURL
        NSWorkspace.shared.open(destination(for: url) == .inApp && url.scheme == "https" ? url : homeURL)
    }

    private func buildMenus() {
        let main = NSMenu()
        NSApp.mainMenu = main
        func menu(_ title: String) -> NSMenu {
            let item = NSMenuItem()
            let submenu = NSMenu(title: title)
            item.submenu = submenu
            main.addItem(item)
            return submenu
        }
        func item(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String = "", target: AnyObject? = nil) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
            entry.target = target
            menu.addItem(entry)
        }
        let app = menu("MailDesk")
        item(app, "About MailDesk", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp)
        app.addItem(.separator())
        item(app, "Hide MailDesk", #selector(NSApplication.hide(_:)), "h", target: NSApp)
        app.addItem(.separator())
        item(app, "Quit MailDesk", #selector(NSApplication.terminate(_:)), "q", target: NSApp)
        let file = menu("File")
        item(file, "Open Mail", #selector(goHome), "1", target: self)
        item(file, "Open in Browser", #selector(openInBrowser), target: self)
        file.addItem(.separator())
        item(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
        let edit = menu("Edit")
        item(edit, "Undo", Selector(("undo:")), "z")
        item(edit, "Redo", Selector(("redo:")), "Z")
        edit.addItem(.separator())
        item(edit, "Cut", #selector(NSText.cut(_:)), "x")
        item(edit, "Copy", #selector(NSText.copy(_:)), "c")
        item(edit, "Paste", #selector(NSText.paste(_:)), "v")
        item(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
        let view = menu("View")
        item(view, "Reload", #selector(reload), "r", target: self)
        item(view, "Back", #selector(back), "[", target: self)
        item(view, "Forward", #selector(forward), "]", target: self)
        view.addItem(.separator())
        item(view, "Zoom In", #selector(zoomIn), "+", target: self)
        item(view, "Zoom Out", #selector(zoomOut), "-", target: self)
        item(view, "Actual Size", #selector(actualSize), "0", target: self)
        let windows = menu("Window")
        item(windows, "Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")
        item(windows, "Zoom", #selector(NSWindow.performZoom(_:)))
        item(windows, "Show MailDesk", #selector(showWindow), target: self)
        NSApp.windowsMenu = windows
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("back"), NSToolbarItem.Identifier("forward"),
         NSToolbarItem.Identifier("reload"), NSToolbarItem.Identifier("home"),
         .flexibleSpace, NSToolbarItem.Identifier("browser")]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarAllowedItemIdentifiers(toolbar)
    }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let definitions: [String: (String, String, Selector)] = [
            "back": ("Back", "chevron.left", #selector(back)),
            "forward": ("Forward", "chevron.right", #selector(forward)),
            "reload": ("Reload", "arrow.clockwise", #selector(reload)),
            "home": ("Open Mail", "envelope", #selector(goHome)),
            "browser": ("Open in Browser", "safari", #selector(openInBrowser)),
        ]
        guard let (label, symbol, action) = definitions[id.rawValue] else { return nil }
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.target = self
        item.action = action
        return item
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        // Subframes remain inside WebKit, so Proton's CAPTCHA can load normally.
        if let frame = action.targetFrame, !frame.isMainFrame {
            decisionHandler(["https", "about", "blob"].contains(url.scheme ?? "") ? .allow : .cancel)
            return
        }
        switch destination(for: url) {
        case .inApp:
            decisionHandler(action.shouldPerformDownload ? .download : .allow)
        case .browser:
            decisionHandler(.cancel)
            // Redirects from Proton can have navigationType .other.
            NSWorkspace.shared.open(url)
        case .blocked:
            decisionHandler(.cancel)
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let attachment = (response.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased().hasPrefix("attachment") == true
        decisionHandler(attachment || !response.canShowMIMEType ? .download : .allow)
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = action.request.url else { return nil }
        if destination(for: url) == .inApp {
            webView.load(action.request)
        }
        return nil
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadingError(error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadingError(error)
    }
    private func showLoadingError(_ error: Error) {
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled, nsError.code != 102, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Couldn’t load Proton Mail"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn { self?.goHome() }
        }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.beginSheetModal(for: window) { response in
            completionHandler(response == .OK ? panel.urls : nil)
        }
    }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = webAlert(message, frame: frame)
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = webAlert(message, frame: frame)
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = webAlert(prompt, frame: frame)
        let field = NSTextField(string: defaultText ?? "")
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { completionHandler($0 == .alertFirstButtonReturn ? field.stringValue : nil) }
    }
    private func webAlert(_ message: String, frame: WKFrameInfo) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? "Proton Mail"
        alert.informativeText = message
        return alert
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = (suggestedFilename as NSString).lastPathComponent
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] result in
            guard let self, result == .OK, let destination = panel.url else { completionHandler(nil); return }
            do {
                // Atomic replacement requires staging on the destination's volume.
                let directory = try FileManager.default.url(for: .itemReplacementDirectory,
                    in: .userDomainMask, appropriateFor: destination, create: true)
                let temporary = directory.appendingPathComponent(UUID().uuidString)
                self.downloads[download] = (temporary, directory, destination)
                completionHandler(temporary)
            } catch {
                completionHandler(nil)
                self.showFileError(error)
            }
        }
    }
    func downloadDidFinish(_ download: WKDownload) {
        guard let record = downloads.removeValue(forKey: download) else { return }
        defer { try? FileManager.default.removeItem(at: record.directory) }
        do {
            if FileManager.default.fileExists(atPath: record.destination.path) {
                _ = try FileManager.default.replaceItemAt(record.destination, withItemAt: record.temporary)
            } else {
                try FileManager.default.moveItem(at: record.temporary, to: record.destination)
            }
        } catch {
            showFileError(error)
        }
    }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if let record = downloads.removeValue(forKey: download) {
            try? FileManager.default.removeItem(at: record.directory)
        }
        if (error as NSError).code != NSURLErrorCancelled { showFileError(error) }
    }
    private func showFileError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Couldn’t save attachment"
        alert.informativeText = error.localizedDescription
        alert.beginSheetModal(for: window)
    }
}
