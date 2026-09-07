import AppKit
import UniformTypeIdentifiers

// MARK: - Configuration

/// One entry in the picker.
///
/// `name`     – display name, also used to locate `<name>.app` for the icon.
/// `bundleId` – optional; if set, the app is located by bundle identifier instead of by name.
/// `command`  – optional shell template for full control (e.g. terminals). `{dir}` is
///              replaced with a shell-quoted absolute path to the target folder.
///              When absent, the folder is opened with the app directly (like `open -a`).
/// `enabled`  – when false, the entry stays in the list but is hidden from the picker.
struct AppEntry: Codable {
    var name: String
    var bundleId: String?
    var command: String?
    var enabled: Bool

    init(name: String, bundleId: String? = nil, command: String? = nil, enabled: Bool = true) {
        self.name = name
        self.bundleId = bundleId
        self.command = command
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey { case name, bundleId, command, enabled }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        bundleId = try c.decodeIfPresent(String.self, forKey: .bundleId)
        command = try c.decodeIfPresent(String.self, forKey: .command)
        // Missing in older configs → treated as enabled.
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

struct Config: Codable {
    var apps: [AppEntry]
}

enum ConfigStore {
    static var directory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Switchyard", isDirectory: true)
    }

    static var fileURL: URL {
        directory.appendingPathComponent("apps.json")
    }

    static let defaults = Config(apps: [
        AppEntry(name: "Visual Studio Code", bundleId: "com.microsoft.VSCode", command: nil),
        AppEntry(name: "Terminal", bundleId: "com.apple.Terminal", command: nil),
        AppEntry(name: "Ghostty", bundleId: "com.mitchellh.ghostty",
                 command: "open -na Ghostty --args --working-directory={dir}"),
        AppEntry(name: "PyCharm", bundleId: "com.jetbrains.pycharm", command: nil),
        AppEntry(name: "IntelliJ IDEA", bundleId: "com.jetbrains.intellij", command: nil),
        AppEntry(name: "Xcode", bundleId: "com.apple.dt.Xcode", command: nil),
        AppEntry(name: "Zed", bundleId: "dev.zed.Zed", command: nil),
    ])

    /// Load config, creating a default file on first run.
    static func load() -> Config {
        let fm = FileManager.default
        if !fm.fileExists(atPath: fileURL.path) {
            write(defaults)
            return defaults
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            NSLog("Switchyard: failed to read config (\(error)); using defaults")
            return defaults
        }
    }

    static func write(_ config: Config) {
        let fm = FileManager.default
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        if let data = try? encoder.encode(config) {
            try? data.write(to: fileURL)
        }
    }
}

// MARK: - Supported-apps catalog

enum SupportedApps {
    /// Apps Switchyard knows how to configure out of the box. The "Add installed…"
    /// button in Settings offers any of these that are installed and not already in
    /// the user's list.
    ///
    /// This is intentionally SEPARATE from `ConfigStore.defaults` (the first-run
    /// list) so the shipped catalog can be broad without bloating a new install.
    /// Extend it freely. Detection matches by `bundleId` first, then falls back to
    /// `<name>.app` in the standard Applications folders — so keep `name` equal to
    /// the app's on-disk file name, and a slightly wrong `bundleId` still resolves.
    static let catalog: [AppEntry] = [
        // Editors
        AppEntry(name: "Visual Studio Code", bundleId: "com.microsoft.VSCode"),
        AppEntry(name: "VSCodium", bundleId: "com.vscodium"),
        AppEntry(name: "Cursor", bundleId: "com.todesktop.230313mzl4w4u92"),
        AppEntry(name: "Zed", bundleId: "dev.zed.Zed"),
        AppEntry(name: "Sublime Text", bundleId: "com.sublimetext.4"),
        AppEntry(name: "Nova", bundleId: "com.panic.Nova"),
        AppEntry(name: "BBEdit", bundleId: "com.barebones.bbedit"),
        AppEntry(name: "TextMate", bundleId: "com.macromates.TextMate"),
        AppEntry(name: "MacVim", bundleId: "org.vim.MacVim"),

        // JetBrains IDEs
        AppEntry(name: "IntelliJ IDEA", bundleId: "com.jetbrains.intellij"),
        AppEntry(name: "IntelliJ IDEA CE", bundleId: "com.jetbrains.intellij.ce"),
        AppEntry(name: "PyCharm", bundleId: "com.jetbrains.pycharm"),
        AppEntry(name: "PyCharm CE", bundleId: "com.jetbrains.pycharm.ce"),
        AppEntry(name: "WebStorm", bundleId: "com.jetbrains.WebStorm"),
        AppEntry(name: "PhpStorm", bundleId: "com.jetbrains.PhpStorm"),
        AppEntry(name: "CLion", bundleId: "com.jetbrains.CLion"),
        AppEntry(name: "GoLand", bundleId: "com.jetbrains.goland"),
        AppEntry(name: "RubyMine", bundleId: "com.jetbrains.rubymine"),
        AppEntry(name: "Rider", bundleId: "com.jetbrains.rider"),
        AppEntry(name: "DataGrip", bundleId: "com.jetbrains.datagrip"),
        AppEntry(name: "RustRover", bundleId: "com.jetbrains.rustrover"),
        AppEntry(name: "Android Studio", bundleId: "com.google.android.studio"),
        AppEntry(name: "Xcode", bundleId: "com.apple.dt.Xcode"),

        // Terminals
        AppEntry(name: "Terminal", bundleId: "com.apple.Terminal"),
        AppEntry(name: "iTerm", bundleId: "com.googlecode.iterm2"),
        AppEntry(name: "Ghostty", bundleId: "com.mitchellh.ghostty",
                 command: "open -na Ghostty --args --working-directory={dir}"),
        AppEntry(name: "kitty", bundleId: "net.kovidgoyal.kitty",
                 command: "open -na kitty --args --directory {dir}"),
        AppEntry(name: "Alacritty", bundleId: "org.alacritty",
                 command: "open -na Alacritty --args --working-directory {dir}"),
        AppEntry(name: "WezTerm", bundleId: "com.github.wez.wezterm",
                 command: "open -na WezTerm --args start --cwd {dir}"),
        AppEntry(name: "Warp", bundleId: "dev.warp.Warp-Stable"),
    ]
}

// MARK: - Resolving apps to on-disk URLs

enum AppLocator {
    /// Resolve an entry to its application bundle URL (for launching + icon), if installed.
    static func url(for entry: AppEntry) -> URL? {
        let ws = NSWorkspace.shared
        if let bid = entry.bundleId,
           let url = ws.urlForApplication(withBundleIdentifier: bid) {
            return url
        }
        // Fall back to locating `<name>.app` in the standard app folders.
        let candidates = [
            "/Applications", "/System/Applications",
            NSString(string: "~/Applications").expandingTildeInPath,
        ]
        for base in candidates {
            let path = "\(base)/\(entry.name).app"
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }
}

// MARK: - Finding the current Finder folder

enum FinderTarget {
    /// POSIX path of the folder shown in the frontmost Finder window,
    /// falling back to the home folder.
    static func currentFolder() -> String {
        let source = """
        tell application "Finder"
            try
                if (count of Finder windows) > 0 then
                    return POSIX path of (target of front Finder window as alias)
                else
                    return POSIX path of (path to home folder)
                end if
            on error
                return POSIX path of (path to home folder)
            end try
        end tell
        """
        var error: NSDictionary?
        if let script = NSAppleScript(source: source),
           let result = script.executeAndReturnError(&error).stringValue {
            return result
        }
        if let error { NSLog("Switchyard: AppleScript error \(error)") }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }
}

// MARK: - Launching

enum Launcher {
    static func open(folder: String, with entry: AppEntry, appURL: URL?) {
        let folderURL = URL(fileURLWithPath: folder, isDirectory: true)

        if let template = entry.command, !template.isEmpty {
            let quoted = "'" + folder.replacingOccurrences(of: "'", with: "'\\''") + "'"
            let command = template.replacingOccurrences(of: "{dir}", with: quoted)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]
            do {
                try process.run()
            } catch {
                NSLog("Switchyard: command failed (\(error))")
            }
            return
        }

        guard let appURL else {
            NSLog("Switchyard: could not locate app '\(entry.name)'")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([folderURL], withApplicationAt: appURL, configuration: config)
    }
}

// MARK: - Picker UI

final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            NSApp.terminate(nil)
            return
        }
        super.keyDown(with: event)
    }
}

final class AppController: NSObject, NSApplicationDelegate {
    private var panel: PickerPanel!
    private var folder: String = ""
    private var entries: [(entry: AppEntry, url: URL?)] = []
    private var buttons: [NSButton] = []

    private var configuredApps: [AppEntry] = []
    private var settingsController: SettingsWindowController?
    private var showingSettings = false

    private let tileSize: CGFloat = 92
    private let iconSize: CGFloat = 56
    private let padding: CGFloat = 16
    private let spacing: CGFloat = 8

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load config first so the defaults file is written even if Finder access is denied.
        let config = ConfigStore.load()
        configuredApps = config.apps

        // Hold ⌥ Option while clicking the toolbar button (or pass --settings) to
        // jump straight to Settings.
        if NSEvent.modifierFlags.contains(.option) || CommandLine.arguments.contains("--settings") {
            openSettings()
            return
        }

        folder = FinderTarget.currentFolder()

        // Only show enabled apps that are actually installed (or use a custom command).
        entries = config.apps.compactMap { entry in
            guard entry.enabled else { return nil }
            let url = AppLocator.url(for: entry)
            if url == nil && (entry.command?.isEmpty ?? true) { return nil }
            return (entry, url)
        }

        // Nothing to show (no apps configured / none installed): go to Settings
        // rather than dead-ending with an alert.
        guard !entries.isEmpty else {
            openSettings()
            return
        }

        buildPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func buildPanel() {
        let count = entries.count
        let contentWidth = padding * 2 + CGFloat(count) * tileSize + CGFloat(count - 1) * spacing
        let titleHeight: CGFloat = 34
        let contentHeight = padding * 2 + tileSize + titleHeight

        panel = PickerPanel(
            contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let root = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight))
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        panel.contentView = root

        // Folder label (inset on the right so it never sits under the gear)
        let label = NSTextField(labelWithString: "Open “\((folder as NSString).lastPathComponent)” in…")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.frame = NSRect(x: padding + 20, y: contentHeight - titleHeight + 4,
                             width: contentWidth - (padding + 20) * 2, height: 18)
        label.lineBreakMode = .byTruncatingMiddle
        root.addSubview(label)

        // Gear → Settings, tucked in the top-right corner.
        let gear = NSButton(frame: NSRect(x: contentWidth - 26, y: contentHeight - 26, width: 18, height: 18))
        gear.isBordered = false
        gear.bezelStyle = .regularSquare
        gear.title = ""
        gear.imagePosition = .imageOnly
        gear.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        gear.contentTintColor = .secondaryLabelColor
        gear.toolTip = "Settings"
        gear.target = self
        gear.action = #selector(openSettingsFromPicker)
        root.addSubview(gear)

        // App tiles
        for (index, item) in entries.enumerated() {
            let x = padding + CGFloat(index) * (tileSize + spacing)
            let tile = makeTile(for: item, index: index)
            tile.frame = NSRect(x: x, y: padding, width: tileSize, height: tileSize)
            root.addSubview(tile)
        }

        centerNearMouse(size: NSSize(width: contentWidth, height: contentHeight))
    }

    private func makeTile(for item: (entry: AppEntry, url: URL?), index: Int) -> NSView {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.title = ""
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(pick(_:))
        button.tag = index
        button.toolTip = item.entry.name

        let icon: NSImage
        if let url = item.url {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        icon.size = NSSize(width: iconSize, height: iconSize)
        button.image = icon
        buttons.append(button)

        let name = NSTextField(labelWithString: item.entry.name)
        name.font = .systemFont(ofSize: 11)
        name.textColor = .labelColor
        name.alignment = .center
        name.lineBreakMode = .byTruncatingTail
        name.maximumNumberOfLines = 1

        let stack = NSStackView(views: [button, name])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 4
        stack.frame = NSRect(x: 0, y: 0, width: tileSize, height: tileSize)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        button.heightAnchor.constraint(equalToConstant: iconSize).isActive = true
        name.widthAnchor.constraint(equalToConstant: tileSize).isActive = true
        return stack
    }

    private func centerNearMouse(size: NSSize) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let visible = screen?.visibleFrame else {
            panel.center()
            return
        }
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height / 2)
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    @objc private func pick(_ sender: NSButton) {
        let item = entries[sender.tag]
        Launcher.open(folder: folder, with: item.entry, appURL: item.url)
        NSApp.terminate(nil)
    }

    @objc private func openSettingsFromPicker() {
        openSettings()
    }

    /// Show the Settings window. Closing it saves and quits (the app is one-shot).
    private func openSettings() {
        showingSettings = true
        panel?.orderOut(nil)

        // Promote to a regular app so Settings behaves like a normal, focusable window.
        NSApp.setActivationPolicy(.regular)

        let controller = SettingsWindowController(apps: configuredApps) { updated in
            ConfigStore.write(Config(apps: updated))
            NSApp.terminate(nil)
        }
        settingsController = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }
}

extension AppController: NSWindowDelegate {
    // Dismiss the picker when the user clicks elsewhere — but not while Settings is up.
    func windowDidResignKey(_ notification: Notification) {
        if showingSettings { return }
        NSApp.terminate(nil)
    }
}

// MARK: - Settings window

final class SettingsWindowController: NSWindowController {
    private var apps: [AppEntry]
    private let onClose: ([AppEntry]) -> Void

    private var tableView: NSTableView!
    private var nameField: NSTextField!
    private var bundleField: NSTextField!
    private var commandField: NSTextField!
    private var removeButton: NSButton!
    private var upButton: NSButton!
    private var downButton: NSButton!

    init(apps: [AppEntry], onClose: @escaping ([AppEntry]) -> Void) {
        self.apps = apps
        self.onClose = onClose
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 400),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Switchyard Settings"
        window.center()
        super.init(window: window)
        window.delegate = self
        buildUI()
        selectRow(apps.isEmpty ? -1 : 0)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }

    // MARK: UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // App list.
        let scroll = NSScrollView(frame: NSRect(x: 20, y: 96, width: 250, height: 284))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autohidesScrollers = true

        let table = NSTableView(frame: scroll.bounds)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.width = 230
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 30
        table.dataSource = self
        table.delegate = self
        table.doubleAction = nil
        scroll.documentView = table
        content.addSubview(scroll)
        tableView = table

        // List toolbar: add / remove / move up / move down — sits just under the list.
        let addButton = squareButton("plus", action: #selector(addApp))
        addButton.frame = NSRect(x: 20, y: 64, width: 28, height: 24)
        addButton.toolTip = "Add a new entry"
        content.addSubview(addButton)

        removeButton = squareButton("minus", action: #selector(removeApp))
        removeButton.frame = NSRect(x: 50, y: 64, width: 28, height: 24)
        removeButton.toolTip = "Remove selected"
        content.addSubview(removeButton)

        upButton = squareButton("chevron.up", action: #selector(moveRowUp))
        upButton.frame = NSRect(x: 88, y: 64, width: 28, height: 24)
        upButton.toolTip = "Move up"
        content.addSubview(upButton)

        downButton = squareButton("chevron.down", action: #selector(moveRowDown))
        downButton.frame = NSRect(x: 118, y: 64, width: 28, height: 24)
        downButton.toolTip = "Move down"
        content.addSubview(downButton)

        let detect = NSButton(title: "Add installed…", target: self, action: #selector(addSupportedApps))
        detect.bezelStyle = .rounded
        detect.frame = NSRect(x: 156, y: 62, width: 130, height: 26)
        detect.toolTip = "Detect installed supported apps and add any missing from your list."
        content.addSubview(detect)

        // Detail form.
        let formX: CGFloat = 292
        let formW: CGFloat = 308
        nameField = addFormRow(to: content, label: "Name", x: formX, y: 336, width: formW,
                               action: #selector(fieldChanged(_:)))

        // Bundle ID row leaves space for a Browse… button.
        let browseW: CGFloat = 84
        bundleField = addFormRow(to: content, label: "Bundle ID", x: formX, y: 282,
                                 width: formW - browseW - 8, action: #selector(fieldChanged(_:)))
        bundleField.placeholderString = "e.g. com.microsoft.VSCode"
        let browse = NSButton(title: "Browse…", target: self, action: #selector(browseForApp))
        browse.bezelStyle = .rounded
        browse.frame = NSRect(x: formX + formW - browseW, y: 280, width: browseW, height: 24)
        browse.toolTip = "Pick an application to fill in the bundle ID"
        content.addSubview(browse)

        commandField = addFormRow(to: content, label: "Command (optional)", x: formX, y: 228, width: formW,
                                  action: #selector(fieldChanged(_:)))
        commandField.placeholderString = "leave blank to just open the folder"

        let help = NSTextField(wrappingLabelWithString:
            "Command overrides the default open. Use {dir} for the folder path " +
            "(shell-quoted automatically). Example:\n" +
            "open -na Ghostty --args --working-directory={dir}")
        help.font = .systemFont(ofSize: 10)
        help.textColor = .tertiaryLabelColor
        help.frame = NSRect(x: formX, y: 150, width: formW, height: 56)
        content.addSubview(help)

        // Done.
        let done = NSButton(title: "Done", target: self, action: #selector(done))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.frame = NSRect(x: 512, y: 20, width: 88, height: 32)
        content.addSubview(done)

        let reveal = NSButton(title: "Reveal config file", target: self, action: #selector(revealConfig))
        reveal.bezelStyle = .rounded
        reveal.frame = NSRect(x: 20, y: 18, width: 160, height: 30)
        content.addSubview(reveal)
    }

    private func squareButton(_ symbol: String, action: Selector) -> NSButton {
        let b = NSButton(title: "", target: self, action: action)
        b.bezelStyle = .smallSquare
        b.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        b.imagePosition = .imageOnly
        return b
    }

    private func addFormRow(to parent: NSView, label: String, x: CGFloat, y: CGFloat,
                            width: CGFloat, action: Selector) -> NSTextField {
        let caption = NSTextField(labelWithString: label)
        caption.font = .systemFont(ofSize: 11, weight: .medium)
        caption.textColor = .secondaryLabelColor
        caption.frame = NSRect(x: x, y: y + 22, width: width, height: 16)
        parent.addSubview(caption)

        let field = NSTextField(frame: NSRect(x: x, y: y, width: width, height: 22))
        field.font = .systemFont(ofSize: 12)
        field.target = self
        field.action = action                // fires on Enter / focus change
        field.delegate = self                // fires on each keystroke
        parent.addSubview(field)
        return field
    }

    // MARK: Selection / editing

    private var selected: Int { tableView.selectedRow }

    private func selectRow(_ row: Int) {
        if row >= 0 && row < apps.count {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        syncForm()
    }

    private func syncForm() {
        let i = selected
        let hasSel = i >= 0 && i < apps.count
        for f in [nameField, bundleField, commandField] { f?.isEnabled = hasSel }
        removeButton.isEnabled = hasSel
        upButton.isEnabled = hasSel && i > 0
        downButton.isEnabled = hasSel && i < apps.count - 1
        guard hasSel else {
            nameField.stringValue = ""; bundleField.stringValue = ""; commandField.stringValue = ""
            return
        }
        let a = apps[i]
        nameField.stringValue = a.name
        bundleField.stringValue = a.bundleId ?? ""
        commandField.stringValue = a.command ?? ""
    }

    private func commit() {
        let i = selected
        guard i >= 0 && i < apps.count else { return }
        func trimmed(_ s: String) -> String? {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        apps[i].name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        apps[i].bundleId = trimmed(bundleField.stringValue)
        apps[i].command = trimmed(commandField.stringValue)
        tableView.reloadData(forRowIndexes: IndexSet(integer: i),
                             columnIndexes: IndexSet(integer: 0))
    }

    // MARK: Actions

    @objc private func fieldChanged(_ sender: Any?) { commit() }

    @objc private func addApp() {
        commit()
        // Add a blank entry and let the user type/paste or use Browse…
        apps.append(AppEntry(name: "New App", bundleId: nil, command: nil))
        tableView.reloadData()
        selectRow(apps.count - 1)
        nameField.stringValue = ""
        commit()
        window?.makeFirstResponder(nameField)
    }

    /// Fill the Bundle ID (and Name, if empty) from a chosen application.
    @objc private func browseForApp() {
        guard selected >= 0 else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Choose"
        panel.beginSheetModal(for: window!) { [weak self] resp in
            guard let self, resp == .OK, let url = panel.url else { return }
            if let bid = Bundle(url: url)?.bundleIdentifier {
                self.bundleField.stringValue = bid
            }
            if self.nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.nameField.stringValue = url.deletingPathExtension().lastPathComponent
            }
            self.commit()
        }
    }

    @objc private func removeApp() {
        let i = selected
        guard i >= 0 && i < apps.count else { return }
        let name = apps[i].name.isEmpty ? "this entry" : "“\(apps[i].name)”"
        let alert = NSAlert()
        alert.messageText = "Remove \(name)?"
        alert.informativeText = "It will be removed from the list. You can add it again later."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        alert.beginSheetModal(for: window!) { [weak self] resp in
            guard let self, resp == .alertFirstButtonReturn else { return }
            guard i < self.apps.count else { return }
            self.apps.remove(at: i)
            self.tableView.reloadData()
            self.selectRow(min(i, self.apps.count - 1))
        }
    }

    @objc private func moveRowUp() { move(by: -1) }
    @objc private func moveRowDown() { move(by: 1) }

    private func move(by delta: Int) {
        commit()
        let i = selected
        let j = i + delta
        guard i >= 0, j >= 0, j < apps.count else { return }
        apps.swapAt(i, j)
        tableView.reloadData()
        selectRow(j)
    }

    @objc private func revealConfig() {
        commit()
        ConfigStore.write(Config(apps: apps))   // ensure the file exists to reveal
        NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.fileURL])
    }

    // MARK: Detect installed supported apps

    /// Supported-catalog apps that are installed but not yet in the list.
    /// Deduped primarily by bundle ID (so "VS Code" matches catalog "Visual Studio Code").
    private func missingSupportedApps() -> [AppEntry] {
        let haveIds = Set(apps.compactMap { $0.bundleId?.lowercased() })
        let haveNames = Set(apps.map { $0.name.lowercased() })
        return SupportedApps.catalog.filter { entry in
            guard AppLocator.url(for: entry) != nil else { return false }   // installed?
            if let bid = entry.bundleId?.lowercased() { return !haveIds.contains(bid) }
            return !haveNames.contains(entry.name.lowercased())
        }
    }

    @objc private func addSupportedApps() {
        commit()
        let missing = missingSupportedApps()
        guard !missing.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Nothing to add"
            alert.informativeText = "All supported apps that are installed are already in your list."
            alert.beginSheetModal(for: window!)
            return
        }
        offerToAdd(missing)
    }

    /// Checklist sheet: one pre-checked row (icon + name) per detected app.
    private func offerToAdd(_ missing: [AppEntry]) {
        let rowH: CGFloat = 26
        let width: CGFloat = 320
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width,
                                             height: rowH * CGFloat(missing.count)))
        var checks: [(NSButton, AppEntry)] = []
        for (i, entry) in missing.enumerated() {
            let y = container.frame.height - rowH * CGFloat(i + 1)
            if let url = AppLocator.url(for: entry) {
                let iv = NSImageView(frame: NSRect(x: 0, y: y + 3, width: 20, height: 20))
                iv.image = NSWorkspace.shared.icon(forFile: url.path)
                container.addSubview(iv)
            }
            let cb = NSButton(checkboxWithTitle: entry.name, target: nil, action: nil)
            cb.state = .on
            cb.frame = NSRect(x: 28, y: y + 3, width: width - 32, height: 20)
            container.addSubview(cb)
            checks.append((cb, entry))
        }

        let alert = NSAlert()
        alert.messageText = "Add supported apps"
        alert.informativeText = "These installed apps aren't in your list yet. Choose which to add."
        alert.accessoryView = container
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window!) { [weak self] resp in
            guard let self, resp == .alertFirstButtonReturn else { return }
            let chosen = checks.filter { $0.0.state == .on }.map { $0.1 }
            guard !chosen.isEmpty else { return }
            let start = self.apps.count
            self.apps.append(contentsOf: chosen)
            self.tableView.reloadData()
            self.selectRow(start)
        }
    }

    @objc private func done() {
        window?.close()
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        commit()
        onClose(apps)
    }
}

extension SettingsWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { apps.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? AppCellView)
            ?? { let c = AppCellView(); c.identifier = id; return c }()
        let entry = apps[row]
        cell.textField?.stringValue = entry.name.isEmpty ? "Untitled" : entry.name
        cell.textField?.textColor = entry.enabled ? .labelColor : .tertiaryLabelColor
        cell.checkbox.state = entry.enabled ? .on : .off
        cell.checkbox.target = self
        cell.checkbox.action = #selector(toggleEnabled(_:))
        cell.checkbox.toolTip = entry.enabled ? "Enabled — shown in the picker"
                                              : "Disabled — hidden from the picker"
        let icon: NSImage
        if let url = AppLocator.url(for: entry) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        cell.imageView?.image = icon
        cell.imageView?.alphaValue = entry.enabled ? 1.0 : 0.4
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) { syncForm() }

    @objc private func toggleEnabled(_ sender: NSButton) {
        let row = tableView.row(for: sender)
        guard row >= 0 && row < apps.count else { return }
        apps[row].enabled = (sender.state == .on)
        tableView.reloadData(forRowIndexes: IndexSet(integer: row),
                             columnIndexes: IndexSet(integer: 0))
    }
}

/// Table row: enable/disable checkbox + app icon + name.
final class AppCellView: NSTableCellView {
    let checkbox = NSButton()

    init() {
        super.init(frame: .zero)
        checkbox.setButtonType(.switch)
        checkbox.title = ""
        checkbox.frame = NSRect(x: 6, y: 7, width: 18, height: 18)
        addSubview(checkbox)

        let image = NSImageView(frame: NSRect(x: 28, y: 5, width: 20, height: 20))
        let text = NSTextField(labelWithString: "")
        text.frame = NSRect(x: 54, y: 6, width: 168, height: 18)
        text.font = .systemFont(ofSize: 12)
        text.lineBreakMode = .byTruncatingTail
        imageView = image
        textField = text
        addSubview(image)
        addSubview(text)
    }

    required init?(coder: NSCoder) { fatalError("not supported") }
}

extension SettingsWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) { commit() }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = AppController()
app.delegate = controller
app.run()
