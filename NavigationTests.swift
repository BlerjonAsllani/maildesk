import Foundation

// Catches insecure navigation, lookalike domains, and accidentally trapping email links.
@main
struct NavigationTests {
    static func main() {
        let cases: [(String, Destination)] = [
            ("https://mail.proton.me/u/0/inbox", .inApp),
            ("https://account.proton.me/login", .inApp),
            ("https://calendar.proton.me/", .inApp),
            ("https://mail.proton.me:443/", .inApp),
            ("https://example.com/", .browser),
            ("http://example.com/", .browser),
            ("https://mail.proton.me.evil.example/", .browser),
            ("https://evilproton.me/", .browser),
            ("http://mail.proton.me/", .blocked),
            ("https://mail.proton.me:8443/", .blocked),
            ("https://user@mail.proton.me/", .blocked),
            ("mailto:friend@example.com", .browser),
            ("file:///etc/passwd", .blocked),
            ("javascript:alert(1)", .blocked),
            ("x-apple.systempreferences:example", .blocked),
            ("blob:https://mail.proton.me/123", .inApp),
            ("blob:https://evil.example/123", .blocked),
        ]
        var failures = 0
        for (input, expected) in cases {
            let actual = destination(for: URL(string: input)!)
            if actual != expected {
                print("FAIL: \(input): expected \(expected), got \(actual)")
                failures += 1
            }
        }
        guard failures == 0 else { exit(1) }
        print("PASS: \(cases.count) navigation safety checks")
    }
}
