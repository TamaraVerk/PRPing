import Cocoa

struct PR: Codable {
    let url: String
    let title: String
    let number: Int
    let repository: Repo
    struct Repo: Codable {
        let nameWithOwner: String
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var blinkTimer: Timer?
    private var refreshTimer: Timer?
    private var fileSource: DispatchSourceFileSystemObject?
    private var triggerFile: URL!
    private var prs: [PR] = []
    private var blinkOn = false
    private let searchURL = "https://github.com/pulls?q=is%3Aopen+is%3Apr+review-requested%3A%40me"

    func applicationDidFinishLaunching(_ notification: Notification) {
        let triggerDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude-pr-ping")
        try? FileManager.default.createDirectory(at: triggerDir, withIntermediateDirectories: true)
        triggerFile = triggerDir.appendingPathComponent("trigger")
        if !FileManager.default.fileExists(atPath: triggerFile.path) {
            FileManager.default.createFile(atPath: triggerFile.path, contents: Data())
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "PR"
            button.imagePosition = .imageLeading
        }
        statusItem.isVisible = true
        setIcon(blinkState: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        rebuildMenu()

        watchTrigger()
        refresh(shouldBlink: false)

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.refresh(shouldBlink: false)
        }
    }

    private func watchTrigger() {
        let fd = open(triggerFile.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.refresh(shouldBlink: true)
            // If file was renamed/deleted, re-arm
            if source.data.contains(.delete) || source.data.contains(.rename) {
                self?.fileSource?.cancel()
                self?.fileSource = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let path = self?.triggerFile.path,
                       !FileManager.default.fileExists(atPath: path) {
                        FileManager.default.createFile(atPath: path, contents: Data())
                    }
                    self?.watchTrigger()
                }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        fileSource = source
    }

    private func refresh(shouldBlink: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = [
                "gh", "search", "prs",
                "--review-requested=@me",
                "--state=open",
                "--limit", "30",
                "--json", "url,title,number,repository"
            ]
            let out = Pipe()
            let err = Pipe()
            task.standardOutput = out
            task.standardError = err
            do {
                try task.run()
                task.waitUntilExit()
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let parsed = (try? JSONDecoder().decode([PR].self, from: data)) ?? []
                DispatchQueue.main.async {
                    self.prs = parsed
                    self.rebuildMenu()
                    if parsed.isEmpty {
                        self.stopBlinking()
                    } else if shouldBlink {
                        self.startBlinking()
                    } else {
                        self.setIcon(blinkState: false)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusItem.button?.title = "PR?"
                }
            }
        }
    }

    private func setIcon(blinkState: Bool) {
        guard let button = statusItem.button else { return }
        if prs.isEmpty {
            let img = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "No PRs")
            img?.isTemplate = true
            button.image = img
            button.title = "PR"
        } else {
            let name = blinkState ? "exclamationmark.octagon.fill" : "exclamationmark.octagon"
            let img = NSImage(systemSymbolName: name, accessibilityDescription: "PRs to review")
            img?.isTemplate = true
            button.image = img
            button.title = "PR \(prs.count)"
        }
    }

    private func startBlinking() {
        stopBlinking()
        blinkOn = true
        setIcon(blinkState: blinkOn)
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.blinkOn.toggle()
            self.setIcon(blinkState: self.blinkOn)
        }
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        blinkOn = false
        setIcon(blinkState: false)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.delegate = self
        if prs.isEmpty {
            let item = NSMenuItem(title: "Nema PR-ova za review ✓", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            let header = NSMenuItem(
                title: "\(prs.count) PR\(prs.count == 1 ? "" : "-ova") čeka review",
                action: nil, keyEquivalent: ""
            )
            header.isEnabled = false
            menu.addItem(header)
            menu.addItem(.separator())
            for pr in prs {
                let title = "\(pr.repository.nameWithOwner) #\(pr.number) — \(pr.title)"
                let item = NSMenuItem(title: title, action: #selector(openPR(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = pr.url
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let openAll = NSMenuItem(title: "Otvori GitHub review listu",
                                     action: #selector(openAllOnGitHub),
                                     keyEquivalent: "g")
            openAll.target = self
            menu.addItem(openAll)
        }
        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem(title: "Quit PRPing",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func openPR(_ sender: NSMenuItem) {
        guard let s = sender.representedObject as? String,
              let url = URL(string: s) else { return }
        NSWorkspace.shared.open(url)
        stopBlinking()
    }

    @objc private func openAllOnGitHub() {
        if let url = URL(string: searchURL) {
            NSWorkspace.shared.open(url)
        }
        stopBlinking()
    }

    @objc private func refreshNow() { refresh(shouldBlink: false) }

    func menuWillOpen(_ menu: NSMenu) {
        stopBlinking()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
