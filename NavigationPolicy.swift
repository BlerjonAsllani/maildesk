import Foundation

enum Destination { case inApp, browser, blocked }

func destination(for url: URL) -> Destination {
    let scheme = url.scheme?.lowercased() ?? ""
    let hosts: Set<String> = ["mail.proton.me", "account.proton.me", "calendar.proton.me",
                              "mail.protonmail.com", "account.protonmail.com"]
    if scheme == "blob" {
        let origin = String(url.absoluteString.dropFirst(5))
        guard let inner = URL(string: origin), inner.scheme == "https",
              hosts.contains(inner.host?.lowercased() ?? ""),
              inner.port == nil || inner.port == 443,
              inner.user == nil, inner.password == nil else { return .blocked }
        return .inApp
    }
    if hosts.contains(url.host?.lowercased() ?? "") {
        guard scheme == "https", url.port == nil || url.port == 443,
              url.user == nil, url.password == nil else { return .blocked }
        return .inApp
    }
    if ["https", "http"].contains(scheme), url.host != nil { return .browser }
    if scheme == "mailto" { return .browser }
    return .blocked
}
