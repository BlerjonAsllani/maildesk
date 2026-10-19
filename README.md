# MailDesk

A small Mac app for using the Proton Mail website in its own window. Works
with a free Proton account; Proton Mail Bridge is not required.

MailDesk is an independent personal client, not an official Proton app.

## Install

Download `MailDesk.zip` from this repository's Releases, unzip it, and move
`MailDesk.app` to Applications. Open it and sign in on Proton's page.

The supplied build is for **Apple silicon Macs**, targeting **macOS 13 or
later**. It was tested on macOS 26.6.2. It is locally ad-hoc signed, not
Apple notarized for public distribution.

## Features

- Proton Mail's web interface in a native Mac window.
- Persistent WebKit website data, with Proton's own keep-signed-in setting.
- Native back, forward, reload, and open-in-browser buttons.
- Attachment file picker and Save As dialog for downloads.
- External website links open in your default browser.
- Standard copy/paste and zoom shortcuts.
- Window size is remembered; closing the window keeps the app running.

| Shortcut | Action |
| --- | --- |
| Command-R | Reload |
| Command-1 | Open Mail |
| Command-[ / Command-] | Back / forward |
| Command-+ / Command-- | Zoom in / out |
| Command-0 | Actual size |
| Command-W | Close window |
| Command-Q | Quit |

## Privacy

The app loads `https://mail.proton.me` using Apple's `WKWebView`. Login,
encryption, and email rendering run in Proton's web interface. There is no
custom login form, credential collection, analytics, JavaScript/native
bridge, or extra server.

Website session data and cache persist locally in WebKit's storage for
this app. Sign out through Proton on shared Macs. Only specific Proton
Mail, Account, and Calendar hosts may navigate the main app window;
other HTTP/HTTPS links and mailto links open through macOS.

## Limitations

Internet access is required. Native background notifications and offline
mail synchronization are not implemented. Paid Proton features remain
subject to your Proton plan. Web behavior may change as Proton updates
its website.

The build, navigation policy checks, application launch, sign-in page,
and reload shortcut were verified. Passkey/security-key authentication,
CAPTCHA challenges, and every signed-in mail workflow were not tested
automatically.

## Build

Requires Xcode or Apple's Command Line Tools. No third-party packages.

```sh
bash test.sh
bash build.sh
```

The build produces `../MailDesk.app` and `../MailDesk.zip`. To select a
different destination:

```sh
bash build.sh /absolute/path/MailDesk.app
```

Build products and compiler caches stay out of Git. The script signs a
staged app before creating the ZIP, so cloud-folder metadata does not
affect the packaged signature.

## Source

- `MailDesk.swift`: window, menus, WebKit delegates, uploads and downloads.
- `NavigationPolicy.swift`: URL navigation boundary.
- `NavigationTests.swift`: checks for insecure URLs and lookalike domains.
- `MakeIcon.swift`: native icon drawing.
- `Info.plist`: application metadata.
