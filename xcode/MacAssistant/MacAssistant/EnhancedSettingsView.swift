// 
// EnhancedSettingsView.swift - Erweiterte Einstellungen für Mac-Assistenten
// Erstellt am: 2025-05-04
// Änderungen:
// - Komplett überarbeitete Einstellungsansicht mit modernem Design
// - Zusätzliche Konfigurationsoptionen für fortschrittliche Funktionen
// - Berechtigungsverwaltung und Workflow-Automatisierungen
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var assistantManager: AssistantManager
    @EnvironmentObject var contextManager: ContextManager
    @Environment(\.presentationMode) var presentationMode
    
    // Eigenschaften für die verschiedenen Einstellungsbereiche
    @State private var selectedTab = 0
    
    // Allgemeine Einstellungen
    @State private var apiModel: String
    @State private var voiceEnabled: Bool
    @State private var screenAnalysisEnabled: Bool
    @State private var wakeWord: String
    @State private var autoStartEnabled: Bool
    
    // Datenschutz-Einstellungen
    @State private var saveConversationHistory: Bool = true
    @State private var dataRetentionPeriod: Int = 30
    @State private var shareAnonymousUsageData: Bool = false
    
    // Erweiterte Einstellungen
    @State private var priorityLevel: Int = 1
    @State private var enableContextualSuggestions: Bool = true
    @State private var enableWorkflowLearning: Bool = true
    @State private var enableProactiveSuggestions: Bool = false
    
    // Automation-Einstellungen
    @State private var automationTriggers: [String: Bool] = [
        "appLaunch": true,
        "fileOpen": false,
        "screenTime": true,
        "frequentTasks": true
    ]
    
    // API-Schlüssel
    @State private var openaiApiKey: String = ""
    @State private var geminiApiKey: String = ""
    
    // Berechtigungsstatus
    @State private var hasMicrophonePermission: Bool = false
    @State private var hasScreenRecordingPermission: Bool = false
    @State private var hasNotificationsPermission: Bool = false
    @State private var hasAccessibilityPermission: Bool = false
    
    // Initialisier mit den aktuellen Einstellungen
    init() {
        let manager = AssistantManager.shared
        _apiModel = State(initialValue: manager.apiModel)
        _voiceEnabled = State(initialValue: manager.voiceEnabled)
        _screenAnalysisEnabled = State(initialValue: manager.screenAnalysisEnabled)
        _wakeWord = State(initialValue: manager.wakeWord)
        _autoStartEnabled = State(initialValue: UserDefaults.standard.bool(forKey: "autoStartAssistant"))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Allgemeine Einstellungen
            ScrollView {
                generalSettingsView
            }
            .tabItem {
                Label("Allgemein", systemImage: "gear")
            }
            .tag(0)
            
            // Intelligenz & Kontext
            ScrollView {
                intelligenceSettingsView
            }
            .tabItem {
                Label("Intelligenz", systemImage: "brain")
            }
            .tag(1)
            
            // API-Einstellungen
            ScrollView {
                apiSettingsView
            }
            .tabItem {
                Label("API", systemImage: "network")
            }
            .tag(2)
            
            // Datenschutz
            ScrollView {
                privacySettingsView
            }
            .tabItem {
                Label("Datenschutz", systemImage: "hand.raised")
            }
            .tag(3)
            
            // Berechtigungen
            ScrollView {
                permissionsView
            }
            .tabItem {
                Label("Berechtigungen", systemImage: "lock.shield")
            }
            .tag(4)
            
            // Automatisierung
            ScrollView {
                automationSettingsView
            }
            .tabItem {
                Label("Automatisierung", systemImage: "wand.and.stars")
            }
            .tag(5)
        }
        .padding()
        .frame(width: 600, height: 450)
        .onAppear {
            checkPermissions()
        }
    }
    
    // MARK: - Allgemeine Einstellungen
    
    private var generalSettingsView: View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("Basiskonfiguration", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Spracherkennung aktivieren", isOn: $voiceEnabled)
                        .disabled(!hasMicrophonePermission)
                    
                    if !hasMicrophonePermission && voiceEnabled {
                        Text("Mikrofonberechtigung erforderlich")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Toggle("Bildschirmanalyse aktivieren", isOn: $screenAnalysisEnabled)
                        .disabled(!hasScreenRecordingPermission)
                    
                    if !hasScreenRecordingPermission && screenAnalysisEnabled {
                        Text("Bildschirmaufnahmeberechtigung erforderlich")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Toggle("Assistant automatisch beim Systemstart starten", isOn: $autoStartEnabled)
                        .onChange(of: autoStartEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "autoStartAssistant")
                        }
                    
                    Divider()
                    
                    HStack {
                        Text("Aufweckwort:")
                            .frame(width: 120, alignment: .leading)
                        
                        TextField("Aufweckwort", text: $wakeWord)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(!voiceEnabled)
                            .frame(maxWidth: 300)
                    }
                    
                    Text("Der Assistent reagiert, wenn er dieses Wort hört.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            GroupBox(label: Label("Erscheinungsbild", systemImage: "paintpalette")) {
                VStack(alignment: .leading, spacing: 12) {
                    // Designs (in einer vollständigen Implementierung)
                    Text("Farbschema")
                        .fontWeight(.medium)
                    
                    Picker("", selection: .constant(0)) {
                        Text("System").tag(0)
                        Text("Hell").tag(1)
                        Text("Dunkel").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.bottom, 8)
                    
                    // Anpassungsoptionen (in einer vollständigen Implementierung)
                    Toggle("Animationen anzeigen", isOn: .constant(true))
                    Toggle("Icon in Menüleiste farbig anzeigen", isOn: .constant(true))
                }
                .padding()
            }
            
            Spacer()
            
            // Aktionsknöpfe
            HStack {
                Spacer()
                
                Button("Abbrechen") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Speichern") {
                    saveSettings()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top)
        }
        .padding()
    }
    
    // MARK: - Intelligenz-Einstellungen
    
    private var intelligenceSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("Kontextverständnis", systemImage: "brain.head.profile")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("KI-Prioritätsstufe:")
                            .frame(width: 150, alignment: .leading)
                        
                        Picker("", selection: $priorityLevel) {
                            Text("Minimal").tag(0)
                            Text("Standard").tag(1)
                            Text("Erweitert").tag(2)
                            Text("Maximum").tag(3)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(maxWidth: 350)
                    }
                    .padding(.vertical, 4)
                    
                    Text("Höhere Stufen bieten bessere Ergebnisse, verbrauchen aber mehr Ressourcen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Toggle("Kontextabhängige Vorschläge anzeigen", isOn: $enableContextualSuggestions)
                    Toggle("Arbeitsablauf-Erkennung aktivieren", isOn: $enableWorkflowLearning)
                    Toggle("Proaktive Benachrichtigungen aktivieren", isOn: $enableProactiveSuggestions)
                }
                .padding()
            }
            
            GroupBox(label: Label("Lernverhalten", systemImage: "graduationcap")) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading) {
                        Text("Benutzerverhaltensdaten")
                            .fontWeight(.medium)
                        
                        Text("Bestimmt, wie der Assistent aus Ihren Interaktionen lernt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)
                    }
                    
                    Picker("", selection: .constant(1)) {
                        Text("Nicht lernen").tag(0)
                        Text("Aus Befehlen lernen").tag(1)
                        Text("Aus allen Interaktionen lernen").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Divider()
                    
                    HStack {
                        Button("Lernfortschritt zurücksetzen") {
                            // Würde alle gelernten Präferenzen zurücksetzen
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Präferenzen exportieren") {
                            // Würde gelernte Präferenzen exportieren
                        }
                        .disabled(true)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - API-Einstellungen
    
    private var apiSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("KI-Modell", systemImage: "cpu")) {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("API-Anbieter", selection: $apiModel) {
                        Text("OpenAI").tag("openai")
                        Text("Google Gemini").tag("gemini")
                        Text("Lokal (funktioniert offline)").tag("local")
                    }
                    .pickerStyle(RadioGroupPickerStyle())
                    
                    Divider()
                    
                    if apiModel == "openai" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("OpenAI API-Schlüssel")
                                .fontWeight(.medium)
                            
                            SecureField("OpenAI API-Schlüssel", text: $openaiApiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if openaiApiKey.isEmpty {
                                Text("API-Schlüssel wird benötigt für OpenAI")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Link("OpenAI API-Schlüssel erhalten", destination: URL(string: "https://platform.openai.com/api-keys")!)
                                .font(.caption)
                        }
                    } else if apiModel == "gemini" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Google Gemini API-Schlüssel")
                                .fontWeight(.medium)
                            
                            SecureField("Google Gemini API-Schlüssel", text: $geminiApiKey)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if geminiApiKey.isEmpty {
                                Text("API-Schlüssel wird benötigt für Gemini")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Link("Google Gemini API-Schlüssel erhalten", destination: URL(string: "https://ai.google.dev/")!)
                                .font(.caption)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Lokales Modell")
                                .fontWeight(.medium)
                            
                            Text("Verwende lokal installierte Modelle für mehr Datenschutz")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Lokale Modelle herunterladen...") {
                                // Aktion zum Download lokaler Modelle
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding()
            }
            
            GroupBox(label: Label("API-Optionen", systemImage: "gear")) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Maximale Antwortlänge", selection: .constant(2)) {
                        Text("Kurz").tag(0)
                        Text("Mittel").tag(1)
                        Text("Lang").tag(2)
                        Text("Sehr lang").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Divider()
                    
                    Picker("Kreativitätslevel", selection: .constant(1)) {
                        Text("Präzise").tag(0)
                        Text("Ausgewogen").tag(1)
                        Text("Kreativ").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Datenschutz-Einstellungen
    
    private var privacySettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("Datenspeicherung", systemImage: "lock.doc")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Gesprächsverlauf speichern", isOn: $saveConversationHistory)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aufbewahrungsdauer für Gespräche:")
                        
                        Picker("", selection: $dataRetentionPeriod) {
                            Text("7 Tage").tag(7)
                            Text("30 Tage").tag(30)
                            Text("90 Tage").tag(90)
                            Text("Unbegrenzt").tag(-1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .disabled(!saveConversationHistory)
                    
                    Divider()
                    
                    HStack {
                        Button("Alle gespeicherten Daten löschen") {
                            // Aktion zum Löschen aller Daten
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                        
                        Button("Daten exportieren...") {
                            // Aktion zum Exportieren aller Daten
                        }
                    }
                }
                .padding()
            }
            
            GroupBox(label: Label("Datenweitergabe", systemImage: "arrow.triangle.branch")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Anonyme Nutzungsdaten teilen", isOn: $shareAnonymousUsageData)
                    
                    Text("Hilft uns, die App zu verbessern. Es werden keine persönlichen Daten oder Gespräche geteilt.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            GroupBox(label: Label("Offline-Modus", systemImage: "wifi.slash")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Offline-Modus aktivieren, wenn möglich", isOn: .constant(false))
                    
                    Text("In diesem Modus werden nur lokale KI-Modelle verwendet, und es werden keine Daten an externe Server gesendet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Lokale Modelle herunterladen (1.2 GB)") {
                        // Aktion zum Herunterladen lokaler Modelle
                    }
                    .disabled(true)
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Berechtigungsansicht
    
    private var permissionsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Benötigte Berechtigungen")
                .font(.headline)
            
            PermissionItem(
                icon: "mic",
                title: "Mikrofonzugriff",
                description: "Für die Spracherkennung und -steuerung",
                isGranted: hasMicrophonePermission,
                action: requestMicrophonePermission
            )
            
            PermissionItem(
                icon: "display",
                title: "Bildschirmaufnahme",
                description: "Für die Bildschirmanalyse und kontextbezogene Hilfe",
                isGranted: hasScreenRecordingPermission,
                action: requestScreenRecordingPermission
            )
            
            PermissionItem(
                icon: "bell",
                title: "Benachrichtigungen",
                description: "Für Alarme und wichtige Mitteilungen",
                isGranted: hasNotificationsPermission,
                action: requestNotificationsPermission
            )
            
            PermissionItem(
                icon: "hand.tap",
                title: "Bedienungshilfen",
                description: "Für die Steuerung anderer Apps und Automatisierungen",
                isGranted: hasAccessibilityPermission,
                action: requestAccessibilityPermission
            )
            
            Text("Um alle Funktionen nutzen zu können, muss Mac Assistant die Erlaubnis haben, auf diese Systemfunktionen zuzugreifen. Diese Berechtigungen können jederzeit in den Systemeinstellungen unter 'Sicherheit & Datenschutz' geändert werden.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
            
            Spacer()
            
            Button("Systemeinstellungen öffnen") {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
            }
        }
        .padding()
    }
    
    // MARK: - Automatisierungseinstellungen
    
    private var automationSettingsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox(label: Label("Automatisierungstrigger", systemImage: "bolt")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Wählen Sie aus, wann der Assistent automatisch aktiv werden soll:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    ForEach(Array(automationTriggers.keys.sorted()), id: \.self) { key in
                        Toggle(automationTriggerLabel(for: key), isOn: Binding(
                            get: { automationTriggers[key] ?? false },
                            set: { automationTriggers[key] = $0 }
                        ))
                        .padding(.vertical, 2)
                    }
                }
                .padding()
            }
            
            GroupBox(label: Label("Benutzerdefinierte Automatisierungen", systemImage: "wand.and.stars")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Automatisierungen definieren fortgeschrittene Regeln, wann der Mac-Assistent bestimmte Aktionen ausführen soll.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Neue Automatisierung erstellen...") {
                        // Öffne Dialog zum Erstellen einer neuen Automatisierung
                    }
                    .padding(.vertical, 4)
                    
                    Divider()
                    
                    Text("Vorhandene Automatisierungen (3)")
                        .fontWeight(.medium)
                    
                    // Beispiel-Automatisierungen (in vollständiger Implementierung dynamisch)
                    AutomationItem(
                        name: "Morgen-Briefing",
                        description: "Jeden Tag um 9:00 Uhr eine Zusammenfassung erstellen",
                        isActive: true
                    )
                    
                    AutomationItem(
                        name: "Fokus-Modus",
                        description: "Bei Öffnen von Visual Studio Code",
                        isActive: true
                    )
                    
                    AutomationItem(
                        name: "Erinnerung an Meetings",
                        description: "5 Minuten vor Kalenderereignissen",
                        isActive: false
                    )
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Hilfsmethoden
    
    private func saveSettings() {
        // Einstellungen im AssistantManager aktualisieren
        let manager = AssistantManager.shared
        manager.apiModel = self.apiModel
        manager.voiceEnabled = self.voiceEnabled
        manager.screenAnalysisEnabled = self.screenAnalysisEnabled
        manager.wakeWord = self.wakeWord
        
        // Weitere Einstellungen speichern
        UserDefaults.standard.set(autoStartEnabled, forKey: "autoStartAssistant")
        UserDefaults.standard.set(saveConversationHistory, forKey: "saveConversationHistory")
        UserDefaults.standard.set(dataRetentionPeriod, forKey: "dataRetentionPeriod")
        UserDefaults.standard.set(shareAnonymousUsageData, forKey: "shareAnonymousUsageData")
        UserDefaults.standard.set(priorityLevel, forKey: "priorityLevel")
        UserDefaults.standard.set(enableContextualSuggestions, forKey: "enableContextualSuggestions")
        UserDefaults.standard.set(enableWorkflowLearning, forKey: "enableWorkflowLearning")
        UserDefaults.standard.set(enableProactiveSuggestions, forKey: "enableProactiveSuggestions")
        
        // Automatisierungstrigger speichern
        for (key, value) in automationTriggers {
            UserDefaults.standard.set(value, forKey: "automationTrigger_\(key)")
        }
        
        // API-Schlüssel im Keychain speichern (in einer vollständigen Implementierung)
        if !openaiApiKey.isEmpty {
            // saveApiKey(openaiApiKey, forKey: "openaiApiKey")
        }
        
        if !geminiApiKey.isEmpty {
            // saveApiKey(geminiApiKey, forKey: "geminiApiKey")
        }
    }
    
    private func checkPermissions() {
        // In einer vollständigen Implementierung:
        // Tatsächliche Prüfung der Berechtigungen
        
        // Simulierte Berechtigungsprüfung für den Prototyp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasMicrophonePermission = UserDefaults.standard.bool(forKey: "mockMicPermission")
            self.hasScreenRecordingPermission = UserDefaults.standard.bool(forKey: "mockScreenPermission")
            self.hasNotificationsPermission = UserDefaults.standard.bool(forKey: "mockNotificationsPermission")
            self.hasAccessibilityPermission = UserDefaults.standard.bool(forKey: "mockAccessibilityPermission")
        }
    }
    
    private func requestMicrophonePermission() {
        requestPermission(name: "Mikrofon", key: "mockMicPermission") { granted in
            self.hasMicrophonePermission = granted
        }
    }
    
    private func requestScreenRecordingPermission() {
        requestPermission(name: "Bildschirmaufnahme", key: "mockScreenPermission") { granted in
            self.hasScreenRecordingPermission = granted
        }
    }
    
    private func requestNotificationsPermission() {
        requestPermission(name: "Benachrichtigungen", key: "mockNotificationsPermission") { granted in
            self.hasNotificationsPermission = granted
        }
    }
    
    private func requestAccessibilityPermission() {
        requestPermission(name: "Bedienungshilfen", key: "mockAccessibilityPermission") { granted in
            self.hasAccessibilityPermission = granted
        }
    }
    
    private func requestPermission(name: String, key: String, completion: @escaping (Bool) -> Void) {
        // In einer vollständigen Implementierung:
        // Echte Berechtigungsanfragen über die entsprechenden macOS-APIs
        
        // Für den Prototyp: Simulierte Anfrage
        let alert = NSAlert()
        alert.messageText = "Berechtigung anfordern"
        alert.informativeText = "Mac Assistant möchte auf \(name) zugreifen."
        alert.addButton(withTitle: "Erlauben")
        alert.addButton(withTitle: "Ablehnen")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Immer zulassen für den Prototyp
            UserDefaults.standard.set(true, forKey: key)
            completion(true)
        }
    }
    
    private func automationTriggerLabel(for key: String) -> String {
        switch key {
        case "appLaunch": return "Bei Start bestimmter Anwendungen"
        case "fileOpen": return "Beim Öffnen bestimmter Dateitypen"
        case "screenTime": return "Bei längerer Bildschirmzeit"
        case "frequentTasks": return "Bei wiederkehrenden Aufgaben"
        default: return key
        }
    }
}

// MARK: - Helper Components

struct PermissionItem: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isGranted ? .green : .red)
                .font(.title2)
                .frame(width: 36)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(isGranted ? "Erteilt" : "Erlauben") {
                action()
            }
            .disabled(isGranted)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct AutomationItem: View {
    let name: String
    let description: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(name)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(isActive))
        }
        .padding(.vertical, 4)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AssistantManager.shared)
            .environmentObject(ContextManager.shared)
    }
}