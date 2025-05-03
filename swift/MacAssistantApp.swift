/**
 * MacAssistantApp.swift
 * Erstellt am: 2025-05-04
 * 
 * Änderungen:
 * - Hauptanwendungseinstiegspunkt für die Mac Assistant App
 * - Statusleisten-Icon und Menü-Integration
 * - Konfiguration der App-Initialisierung und Berechtigungen
 */

import SwiftUI
import Cocoa

@main
struct MacAssistantApp: App {
    // Umgebungsobjekte für die gesamte App
    @StateObject private var pythonBridge = PythonBridge()
    @StateObject private var appState = AppState()
    
    // Statusleisten-Item
    @State private var statusItem: NSStatusItem?
    
    var body: some Scene {
        WindowGroup {
            // Hauptfenster-Content nur anzeigen, wenn das Fenster sichtbar ist
            EmptyView()
                .frame(width: 0, height: 0)
        }
        .commands {
            // Standard-Menüeinträge entfernen
            CommandGroup(replacing: .appInfo) {
                Button("Über Mac Assistant") {
                    showAboutPanel()
                }
            }
            CommandGroup(replacing: .newItem) { }
        }
        
        // Menübar Extras für Statusleisten-Icon
        MenuBarExtra("Mac Assistant", systemImage: "brain.head.profile") {
            MenuBarView()
                .environmentObject(pythonBridge)
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
    }
    
    init() {
        setupApp()
    }
    
    /// Richtet die App ein und konfiguriert Berechtigungen
    private func setupApp() {
        // App-Name im Menü setzen
        NSApplication.shared.setActivationPolicy(.accessory)
        
        // Verhindert, dass die App im Dock erscheint
        // NSApplication.shared.setActivationPolicy(.accessory)
        
        // Berechtigungen anfordern, wenn die App startet
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            requestPermissions()
        }
    }
    
    /// Fordert notwendige Berechtigungen an
    private func requestPermissions() {
        // Hier die verschiedenen Berechtigungsanfragen implementieren
        
        // Beispiel: Mikrofon-Berechtigung
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if granted {
                print("Mikrofon-Berechtigung erteilt")
            } else {
                print("Mikrofon-Berechtigung verweigert")
            }
        }
        
        // Beispiel: Screen Recording (muss in der Info.plist-Datei definiert werden)
        if let options = CGWindowListOption(rawValue: CGWindowListOption.optionOnScreenOnly.rawValue) {
            let windowList = CGWindowListCopyWindowInfo(options, CGWindowID(0))
            if let windowListInfo = windowList as NSArray? {
                print("Bildschirmaufnahme-Test: \(windowListInfo.count) Fenster gefunden")
            }
        }
    }
    
    /// Zeigt das "Über"-Panel an
    private func showAboutPanel() {
        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                NSApplication.AboutPanelOptionKey.applicationName: "Mac Assistant",
                NSApplication.AboutPanelOptionKey.applicationVersion: "1.0",
                NSApplication.AboutPanelOptionKey.version: "Build 1",
                NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                    string: "Ein leistungsstarker KI-Assistent für deinen Mac.\nEntwickelt mit ❤️ von NC Agency."
                )
            ]
        )
    }
}

/// Der Anwendungszustand für Datenfluss zwischen Views
class AppState: ObservableObject {
    @Published var isPopoverVisible = false
    @Published var selectedTab = 0
    @Published var userInput = ""
    @Published var conversations: [Conversation] = []
    @Published var settings = AppSettings()
    
    func resetConversation() {
        userInput = ""
    }
    
    func addUserMessage(_ message: String) {
        let newMessage = Message(text: message, isUser: true)
        
        if conversations.isEmpty {
            let newConversation = Conversation(
                id: UUID(),
                title: "Neue Konversation",
                messages: [newMessage],
                timestamp: Date()
            )
            conversations.append(newConversation)
        } else {
            conversations[0].messages.append(newMessage)
        }
    }
    
    func addAssistantMessage(_ message: String) {
        guard !conversations.isEmpty else { return }
        
        let newMessage = Message(text: message, isUser: false)
        conversations[0].messages.append(newMessage)
    }
}

/// App-Einstellungen
struct AppSettings: Codable {
    var startAtLogin: Bool = true
    var useVoiceControl: Bool = true
    var useScreenAnalysis: Bool = true
    var preferredVoiceLanguage: String = "Deutsch"
    var keyboardShortcut: String = "⌥⌘A"
    var aiModel: String = "OpenAI"
    var theme: String = "System"
    
    /// Standardeinstellungen zurücksetzen
    mutating func resetToDefaults() {
        self = AppSettings()
    }
}

/// Nachricht in einer Konversation
struct Message: Identifiable, Codable {
    var id = UUID()
    var text: String
    var isUser: Bool
    var timestamp = Date()
}

/// Eine Konversation mit mehreren Nachrichten
struct Conversation: Identifiable, Codable {
    var id: UUID
    var title: String
    var messages: [Message]
    var timestamp: Date
}

// Hilfserweiterungen für Cocoa/AppKit
extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Notwendige Imports
import AVFoundation
import CoreGraphics