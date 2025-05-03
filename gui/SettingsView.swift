// 
// SettingsView.swift - Einstellungsansicht für den Mac-Assistenten
// Erstellt am: 2025-05-04
// Änderungen:
// - Initiale Implementierung der Einstellungsansicht
// - Konfigurationsoptionen für API, Sprache und Bildschirmanalyse
// - Berechtigungsverwaltung und Wakeword-Konfiguration
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var assistantManager: AssistantManager
    @Environment(\.presentationMode) var presentationMode
    
    // Lokale Kopien der Einstellungen für zwei-Wege-Binding
    @State private var apiModel: String
    @State private var voiceEnabled: Bool
    @State private var screenAnalysisEnabled: Bool
    @State private var wakeWord: String
    
    // API-Schlüssel
    @State private var openaiApiKey: String = ""
    @State private var geminiApiKey: String = ""
    
    // Berechtigungsstatus
    @State private var hasMicrophonePermission: Bool = false
    @State private var hasScreenRecordingPermission: Bool = false
    
    // Initialisier mit den aktuellen Einstellungen
    init() {
        let manager = AssistantManager.shared
        _apiModel = State(initialValue: manager.apiModel)
        _voiceEnabled = State(initialValue: manager.voiceEnabled)
        _screenAnalysisEnabled = State(initialValue: manager.screenAnalysisEnabled)
        _wakeWord = State(initialValue: manager.wakeWord)
        
        // In einer vollständigen Implementierung würden die API-Schlüssel aus dem Keychain geladen
        _openaiApiKey = State(initialValue: "")
        _geminiApiKey = State(initialValue: "")
        
        // Berechtigungsstatus würde tatsächlich geprüft werden
        _hasMicrophonePermission = State(initialValue: false)
        _hasScreenRecordingPermission = State(initialValue: false)
    }
    
    var body: some View {
        TabView {
            // Allgemeine Einstellungen
            generalSettingsView
                .tabItem {
                    Label("Allgemein", systemImage: "gear")
                }
            
            // API-Einstellungen
            apiSettingsView
                .tabItem {
                    Label("API", systemImage: "network")
                }
            
            // Berechtigungs-Einstellungen
            permissionsView
                .tabItem {
                    Label("Berechtigungen", systemImage: "lock.shield")
                }
        }
        .padding()
        .frame(width: 450, height: 350)
        .onAppear {
            // Berechtigungsstatus prüfen (in einer vollständigen Implementierung)
            checkPermissions()
        }
    }
    
    // MARK: - Allgemeine Einstellungen
    
    private var generalSettingsView: some View {
        Form {
            Section(header: Text("Basiskonfiguration")) {
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
            }
            
            Section(header: Text("Sprachsteuerung")) {
                TextField("Aufweckwort", text: $wakeWord)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(!voiceEnabled)
                
                Text("Der Assistent reagiert, wenn er dieses Wort hört.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Abbrechen") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    
                    Button("Speichern") {
                        saveSettings()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding()
    }
    
    // MARK: - API-Einstellungen
    
    private var apiSettingsView: some View {
        Form {
            Section(header: Text("KI-Modell")) {
                Picker("API-Anbieter", selection: $apiModel) {
                    Text("OpenAI").tag("openai")
                    Text("Google Gemini").tag("gemini")
                }
                .pickerStyle(RadioGroupPickerStyle())
            }
            
            Section(header: Text("OpenAI-Konfiguration")) {
                SecureField("OpenAI API-Schlüssel", text: $openaiApiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(apiModel != "openai")
                
                if apiModel == "openai" && openaiApiKey.isEmpty {
                    Text("API-Schlüssel wird benötigt für OpenAI")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Section(header: Text("Google Gemini-Konfiguration")) {
                SecureField("Google Gemini API-Schlüssel", text: $geminiApiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(apiModel != "gemini")
                
                if apiModel == "gemini" && geminiApiKey.isEmpty {
                    Text("API-Schlüssel wird benötigt für Gemini")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Berechtigungsansicht
    
    private var permissionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Benötigte Berechtigungen")
                .font(.headline)
            
            // Mikrofonberechtigung
            HStack {
                Image(systemName: hasMicrophonePermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(hasMicrophonePermission ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Mikrofonzugriff")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Wird für die Spracherkennung benötigt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(hasMicrophonePermission ? "Erteilt" : "Erlauben") {
                    requestMicrophonePermission()
                }
                .disabled(hasMicrophonePermission)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Bildschirmaufnahmeberechtigung
            HStack {
                Image(systemName: hasScreenRecordingPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(hasScreenRecordingPermission ? .green : .red)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Bildschirmaufnahme")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Wird für die Bildschirmanalyse benötigt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(hasScreenRecordingPermission ? "Erteilt" : "Erlauben") {
                    requestScreenRecordingPermission()
                }
                .disabled(hasScreenRecordingPermission)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Text("Um alle Funktionen nutzen zu können, muss der Mac-Assistent die Erlaubnis haben, auf dein Mikrofon und deinen Bildschirm zuzugreifen. Diese Berechtigungen können jederzeit in den Systemeinstellungen unter 'Sicherheit & Datenschutz' geändert werden.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top)
            
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
        
        // In einer vollständigen Implementierung:
        // API-Schlüssel im Keychain speichern
        // saveApiKeysToKeychain()
        
        // Einstellungen speichern
        // manager.saveSettings()
    }
    
    private func checkPermissions() {
        // In einer vollständigen Implementierung:
        // Tatsächliche Prüfung der Berechtigungen
        
        // Simulierte Berechtigungsprüfung für den Prototyp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasMicrophonePermission = UserDefaults.standard.bool(forKey: "mockMicPermission")
            self.hasScreenRecordingPermission = UserDefaults.standard.bool(forKey: "mockScreenPermission")
        }
    }
    
    private func requestMicrophonePermission() {
        // In einer vollständigen Implementierung:
        // Tatsächliche Anfrage für Mikrofonzugriff
        
        // Simulierte Anfrage für den Prototyp
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.hasMicrophonePermission = true
            UserDefaults.standard.set(true, forKey: "mockMicPermission")
        }
    }
    
    private func requestScreenRecordingPermission() {
        // In einer vollständigen Implementierung:
        // Tatsächliche Anfrage für Bildschirmaufnahme
        
        // Simulierte Anfrage für den Prototyp
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.hasScreenRecordingPermission = true
            UserDefaults.standard.set(true, forKey: "mockScreenPermission")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AssistantManager.shared)
    }
}