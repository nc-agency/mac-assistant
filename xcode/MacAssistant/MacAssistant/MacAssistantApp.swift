// 
// MacAssistantApp.swift - Haupteinstiegspunkt für die Mac-Assistenten-App
// Erstellt am: 2025-05-04
// Änderungen:
// - Komplett überarbeitete App mit fortschrittlichen Funktionen
// - Integration von MacOS-spezifischen Features wie Spotlight und Siri
// - Kontext-bewusste Automatisierungsfunktionen hinzugefügt
// - Unterstützung für Multi-Display-Setups
//

import SwiftUI
import Combine
import AppKit
import UserNotifications
import AVFoundation

@main
struct MacAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var assistantManager = AssistantManager.shared
    @StateObject private var contextManager = ContextManager.shared
    
    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(assistantManager)
                .environmentObject(contextManager)
        }
        
        // Diese App hat kein Hauptfenster, sondern ein Statusleisten-Icon
        WindowGroup {
            EmptyView()
                .frame(width: 0, height: 0)
                .hidden()
        }
    }
}

// AppDelegate für zusätzliche Funktionalität und macOS-Integration
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    var monitors: [NSObjectProtocol] = []
    var pythonBridge: PythonBridge!
    
    // Kontext-Timer für regelmäßige Statusupdates
    private var contextTimer: Timer?
    
    // Subscribers für Events
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Anfragen von Berechtigungen für Benachrichtigungen
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermissions()
        
        // Python-Bridge initialisieren
        pythonBridge = PythonBridge.shared
        
        // Systemweite Event-Überwachung einrichten
        setupEventMonitoring()
        
        // Statusleisten-Element erstellen
        configureStatusBarItem()
        
        // Popover für die Hauptansicht einrichten
        configurePopover()
        
        // Kontextmanager starten
        ContextManager.shared.startMonitoring()
        
        // Tastenkombination für schnellen Zugriff registrieren (Cmd+Shift+Space)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 49 {
                self.togglePopover(nil)
            }
        }
        
        // Abonniere Benachrichtigungen vom AssistantManager
        subscribeToNotifications()
        
        // Automatisches Starten des Assistenten
        if UserDefaults.standard.bool(forKey: "autoStartAssistant") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                AssistantManager.shared.startAssistant()
            }
        }
        
        // Kontextaktualisierungstimer einrichten
        setupContextTimer()
        
        // Anfangs-Logs
        NSLog("MacAssistant erfolgreich gestartet")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Bereinigen und deaktivieren der Event-Monitore
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        
        // Stoppe den Assistenten
        AssistantManager.shared.stopAssistant()
        
        // Timer anhalten
        contextTimer?.invalidate()
        
        // Verbindungen schließen
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
    
    // MARK: - Konfiguration
    
    private func configureStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Mac Assistant")
            // Fortschrittliches Menü mit Kontext-Informationen
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            
            // Mit kontextsensitivem Hover-Tooltip erweitern
            updateTooltip()
        }
    }
    
    private func configurePopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.behavior = .transient
        popover.animates = true
        
        // SwiftUI-Ansicht in das Popover einfügen
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(AssistantManager.shared)
                .environmentObject(ContextManager.shared)
        )
    }
    
    // MARK: - Event-Handling
    
    @objc func togglePopover(_ sender: Any?) {
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                // Position für das Popover anpassen
                let position = determineOptimalPopoverPosition(for: button)
                
                // Aktualisieren des UI vor Anzeigen
                (popover.contentViewController as? NSHostingController<PopoverView>)?.rootView = PopoverView()
                    .environmentObject(AssistantManager.shared)
                    .environmentObject(ContextManager.shared)
                
                // Popover anzeigen
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: position)
                
                // Fokus auf Popover setzen
                popover.contentViewController?.view.window?.makeKey()
                
                // Aktuellen Kontext aktualisieren
                ContextManager.shared.updateContext()
            }
        }
    }
    
    private func determineOptimalPopoverPosition(for button: NSButton) -> NSRectEdge {
        // Intelligente Positionierung basierend auf Bildschirmplatz
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let buttonFrame = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
        
        // Prüfen, ob mehr Platz unter oder über dem Button ist
        let spaceAbove = buttonFrame.minY - screenFrame.minY
        let spaceBelow = screenFrame.maxY - buttonFrame.maxY
        
        return spaceBelow > spaceAbove ? .minY : .maxY
    }
    
    private func setupEventMonitoring() {
        // Überwache Tastatur und Mauseingaben für kontextbezogene Hilfe
        let keyDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        let mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseEvent(event)
        }
        
        monitors.append(keyDownMonitor!)
        monitors.append(mouseMonitor!)
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Hier würde die Analyse von Tastatureingaben erfolgen
        // für proaktive Hilfefunktionen
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        // Hier würde die Analyse von Mauseingaben erfolgen
        // für kontextbezogene UI-Hinweise
    }
    
    // MARK: - Benachrichtigungen
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                NSLog("Benachrichtigungsberechtigungen erteilt")
            } else if let error = error {
                NSLog("Fehler bei Benachrichtigungsberechtigungen: \(error)")
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Behandle Aktionen auf Benachrichtigungen
        let userInfo = response.notification.request.content.userInfo
        
        // Je nach Aktion den entsprechenden Code ausführen
        if let actionType = userInfo["actionType"] as? String {
            handleNotificationAction(actionType, userInfo: userInfo)
        }
        
        completionHandler()
    }
    
    private func handleNotificationAction(_ actionType: String, userInfo: [AnyHashable: Any]) {
        // Implementierung verschiedener Aktionen basierend auf Benachrichtigungstyp
        switch actionType {
        case "command":
            if let command = userInfo["command"] as? String {
                AssistantManager.shared.sendCommand(command)
            }
        case "openURL":
            if let urlString = userInfo["url"] as? String, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        default:
            break
        }
    }
    
    private func subscribeToNotifications() {
        // Abonniert Ereignisse vom AssistantManager und PythonBridge
        AssistantManager.shared.$isListening
            .sink { [weak self] isListening in
                self?.updateStatusBarAppearance(isListening: isListening)
            }
            .store(in: &cancellables)
        
        PythonBridge.shared.screenAnalysisPublisher
            .sink { [weak self] analysis in
                self?.handleScreenAnalysis(analysis)
            }
            .store(in: &cancellables)
    }
    
    private func updateStatusBarAppearance(isListening: Bool) {
        if let button = statusBarItem.button {
            // Statusleistensymbol und -farbe basierend auf Status aktualisieren
            button.image = NSImage(systemSymbolName: isListening ? "waveform.circle.fill" : "waveform.circle", 
                                   accessibilityDescription: "Mac Assistant")
            
            if isListening {
                button.contentTintColor = NSColor.systemGreen
            } else {
                button.contentTintColor = nil
            }
            
            updateTooltip()
        }
    }
    
    private func updateTooltip() {
        if let button = statusBarItem.button {
            let isListening = AssistantManager.shared.isListening
            let context = ContextManager.shared.currentAppName
            
            let status = isListening ? "Aktiv" : "Inaktiv"
            var tooltip = "Mac Assistant: \(status)"
            
            if let context = context, !context.isEmpty {
                tooltip += "\nAktuelle App: \(context)"
            }
            
            button.toolTip = tooltip
        }
    }
    
    private func handleScreenAnalysis(_ analysis: String) {
        // Verarbeite die Bildschirmanalyse für kontextbezogene Aktionen
        ContextManager.shared.lastScreenAnalysis = analysis
        updateTooltip()
    }
    
    private func setupContextTimer() {
        // Timer für regelmäßige Kontextaktualisierungen
        contextTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateContextInfo()
        }
    }
    
    private func updateContextInfo() {
        // Aktuelle App und andere Kontextinformationen aktualisieren
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            ContextManager.shared.currentAppName = frontmostApp.localizedName
            updateTooltip()
        }
        
        // Andere Kontextinformationen wie Bildschirminhalt, geöffnete Fenster usw.
        // würden hier aktualisiert werden
    }
}

// MARK: - Kontextmanager für intelligente Assistenz

class ContextManager: ObservableObject {
    static let shared = ContextManager()
    
    // Veröffentlichte Eigenschaften für SwiftUI-Binding
    @Published var currentAppName: String?
    @Published var activeWindowTitle: String?
    @Published var lastScreenAnalysis: String = ""
    @Published var recentCommands: [String] = []
    @Published var suggestedActions: [SuggestedAction] = []
    
    // Arbeitsablauf-Erkennung
    @Published var detectedWorkflow: String?
    @Published var workflowSteps: [String] = []
    
    private var isMonitoring = false
    private var workflowPatterns: [WorkflowPattern] = []
    
    private init() {
        loadWorkflowPatterns()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Hier würde die tatsächliche Überwachung starten
        NSLog("ContextManager: Überwachung gestartet")
        
        // Initialen Kontext laden
        updateContext()
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        
        NSLog("ContextManager: Überwachung gestoppt")
    }
    
    func updateContext() {
        // Aktuelle Anwendung und Fenster erfassen
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            self.currentAppName = frontmostApp.localizedName
            
            // Hier würden wir Fenstertitel über AppleScript oder Accessibility APIs abrufen
            fetchActiveWindowInfo(for: frontmostApp)
        }
        
        // Auf Grundlage des aktuellen Kontexts Aktionen vorschlagen
        generateSuggestedActions()
        
        // Arbeitsablauf-Erkennung
        detectWorkflow()
    }
    
    private func fetchActiveWindowInfo(for app: NSRunningApplication) {
        // In einer vollständigen Implementierung würden wir die Apple Accessibility API
        // oder AppleScript verwenden, um Fenstertitel zu erhalten
        
        // Beispiel für simulierten Titel
        if let appName = app.localizedName {
            switch appName {
            case "Safari":
                self.activeWindowTitle = "GitHub - Repositories"
            case "Mail":
                self.activeWindowTitle = "Inbox (3 ungelesen)"
            case "Finder":
                self.activeWindowTitle = "Documents"
            default:
                self.activeWindowTitle = nil
            }
        }
    }
    
    private func generateSuggestedActions() {
        // Kontextbezogene Aktionsvorschläge generieren
        var newActions: [SuggestedAction] = []
        
        if let appName = currentAppName {
            switch appName {
            case "Safari":
                newActions.append(SuggestedAction(
                    title: "Webseite zusammenfassen",
                    command: "Fasse diese Webseite zusammen",
                    icon: "doc.text.magnifyingglass"
                ))
                newActions.append(SuggestedAction(
                    title: "Lesezeichen speichern",
                    command: "Speichere diese Seite als Lesezeichen",
                    icon: "bookmark"
                ))
            case "Mail":
                newActions.append(SuggestedAction(
                    title: "E-Mails scannen",
                    command: "Zeige mir wichtige ungelesene E-Mails",
                    icon: "envelope.badge"
                ))
                newActions.append(SuggestedAction(
                    title: "Schnelle Antwort",
                    command: "Antworte auf diese E-Mail",
                    icon: "arrowshape.turn.up.left"
                ))
            case "Finder":
                newActions.append(SuggestedAction(
                    title: "Dateien ordnen",
                    command: "Ordne diese Dateien nach Typ",
                    icon: "folder.badge.gear"
                ))
                newActions.append(SuggestedAction(
                    title: "Duplikate finden",
                    command: "Suche nach Duplikaten in diesem Ordner",
                    icon: "doc.on.doc"
                ))
            default:
                // Generische Aktionen für unbekannte Apps
                newActions.append(SuggestedAction(
                    title: "Hilfe zu dieser App",
                    command: "Wie benutze ich \(appName)?",
                    icon: "questionmark.circle"
                ))
            }
        }
        
        // Begrenzen auf die Top 5 relevantesten Aktionen
        if newActions.count > 5 {
            newActions = Array(newActions.prefix(5))
        }
        
        DispatchQueue.main.async {
            self.suggestedActions = newActions
        }
    }
    
    private func loadWorkflowPatterns() {
        // Hier würden wir Muster für häufige Arbeitsabläufe laden
        // In einer vollständigen Implementierung könnten diese von einer JSON-Datei
        // oder einer Datenbank geladen werden
        
        workflowPatterns = [
            WorkflowPattern(
                name: "E-Mail-Verarbeitung",
                appSequence: ["Mail", "Safari", "Pages"],
                actions: ["E-Mail öffnen", "Link folgen", "Notizen machen"]
            ),
            WorkflowPattern(
                name: "Präsentationsvorbereitung",
                appSequence: ["Finder", "Preview", "Keynote"],
                actions: ["Bilder auswählen", "Bilder ansehen", "Folien erstellen"]
            ),
            WorkflowPattern(
                name: "Codeentwicklung",
                appSequence: ["Terminal", "Visual Studio Code", "Safari"],
                actions: ["Repository klonen", "Code bearbeiten", "Dokumentation lesen"]
            )
        ]
    }
    
    private func detectWorkflow() {
        // In einer vollständigen Implementierung würden wir hier
        // Muster in den kürzlich verwendeten Apps und Aktionen erkennen
        
        // Für den Prototyp simulieren wir dies
        if let appName = currentAppName, !workflowPatterns.isEmpty {
            for pattern in workflowPatterns {
                if pattern.appSequence.contains(appName) {
                    // Ein möglicher Arbeitsablauf wurde erkannt
                    if self.detectedWorkflow != pattern.name {
                        self.detectedWorkflow = pattern.name
                        self.workflowSteps = pattern.actions
                        
                        NSLog("Workflow erkannt: \(pattern.name)")
                    }
                    return
                }
            }
        }
        
        // Kein Arbeitsablauf erkannt
        self.detectedWorkflow = nil
        self.workflowSteps = []
    }
}

// MARK: - Hilfsstrukturen

struct SuggestedAction: Identifiable {
    let id = UUID()
    let title: String
    let command: String
    let icon: String
}

struct WorkflowPattern {
    let name: String
    let appSequence: [String]
    let actions: [String]
}