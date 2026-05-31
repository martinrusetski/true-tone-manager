import AppKit

class AboutWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 278),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        self.init(window: window)

        let contentView = makeContentView()
        window.contentView = contentView
    }

    private func makeContentView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 250))

        let iconView = NSImageView(image: NSImage(named: "AppIcon") ?? makePlaceholderIcon())
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.frame = NSRect(x: 110, y: 160, width: 80, height: 80)
        view.addSubview(iconView)

        let nameLabel = NSTextField(labelWithString: "TrueTone Manager")
        nameLabel.font = NSFont.boldSystemFont(ofSize: 15)
        nameLabel.alignment = .center
        nameLabel.frame = NSRect(x: 50, y: 116, width: 200, height: 22)
        view.addSubview(nameLabel)

        let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        let versionLabel = NSTextField(labelWithString: "Version \(versionString)")
        versionLabel.font = NSFont.systemFont(ofSize: 11)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 50, y: 98, width: 200, height: 16)
        view.addSubview(versionLabel)

        let copyrightLabel = NSTextField(labelWithString: "Copyright \u{00A9} 2026 Martin Rusetski")
        copyrightLabel.font = NSFont.systemFont(ofSize: 11)
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.alignment = .center
        copyrightLabel.frame = NSRect(x: 50, y: 68, width: 200, height: 16)
        view.addSubview(copyrightLabel)

        let githubLabel = makeLinkLabel(
            text: "GitHub",
            url: "https://github.com/martinrusetski/true-tone-manager"
        )
        githubLabel.frame = NSRect(x: 50, y: 36, width: 200, height: 22)
        view.addSubview(githubLabel)

        let websiteLabel = makeLinkLabel(
            text: "martinrusetski.com",
            url: "https://martinrusetski.com"
        )
        websiteLabel.frame = NSRect(x: 50, y: 14, width: 200, height: 22)
        view.addSubview(websiteLabel)

        return view
    }

    private func makePlaceholderIcon() -> NSImage {
        NSImage(size: NSSize(width: 80, height: 80), flipped: false) { rect in
            let insetRect = rect.insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: insetRect, xRadius: 18, yRadius: 18)
            NSColor.tertiaryLabelColor.setStroke()
            path.lineWidth = 2
            path.stroke()
            return true
        }
    }

    private func makeLinkLabel(text: String, url: String) -> NSTextField {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.link, value: url, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: text.count))

        let label = NSTextField()
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.attributedStringValue = attributedString
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .linkColor

        let gesture = NSClickGestureRecognizer(target: self, action: #selector(linkTapped(_:)))
        label.addGestureRecognizer(gesture)

        return label
    }

    @objc private func linkTapped(_ gesture: NSClickGestureRecognizer) {
        guard let label = gesture.view as? NSTextField,
              let urlString = label.attributedStringValue.attribute(.link, at: 0, effectiveRange: nil) as? String,
              let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func show() {
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
