// 
// MacAssistantApp.swift - Hauptapplikation für den Mac-Assistenten
// Erstellt am: 2025-05-04
// Änderungen:
// - Initiale Implementierung der SwiftUI-App
// - Menübar-Status-Icon eingerichtet
// - Integration mit AppDelegate
//

import SwiftUI

@main
struct MacAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var assistantManager = AssistantManager()
    
    var body: some Scene {
        WindowGroup {
            // Diese App hat kein Hauptfenster, nur ein Statusleisten-Icon
            EmptyView()
        }
        .commands {
            // Menübefehle für die App
            CommandGroup(replacing: .appInfo) {
                Button("Über Mac Assistant") {
                    appDelegate.showAboutPanel()
                }
            }
            
            CommandGroup(replacing: .appSettings) {
                Button("Einstellungen...") {
                    assistantManager.showSettings()
                }
            }
        }
    }
}

// AppDelegate für zusätzliche Funktionalität
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var assistantController: AssistantViewController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Erstellen des Status-Bar-Elements
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Mac Assistant")
            button.action = #selector(togglePopover(_:))
        }
        
        // Popover für die Hauptansicht einrichten
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 512)
        popover.behavior = .transient
        
        // SwiftUI-Ansicht in das Popover einfügen
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(AssistantManager.shared)
        )
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func showAboutPanel() {
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Mac Assistant",
            .applicationVersion: "1.0.0",
            .credits: NSAttributedString(
                string: "Entwickelt mit ❤️ von Windsurf Engineering",
                attributes: [
                    .foregroundColor: NSColor.labelColor,
                    .font: NSFont.systemFont(ofSize: 12)
                ]
            ),
            .applicationIcon: NSImage(named: "AppIcon") ?? NSImage()
        ]
        
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
    }
}