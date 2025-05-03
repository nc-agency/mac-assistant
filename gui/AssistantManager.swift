// 
// AssistantManager.swift - Zustandsverwaltung für den Mac-Assistenten
// Erstellt am: 2025-05-04
// Änderungen:
// - Initiale Implementierung des AssistantManager
// - Zustandsverwaltung und Python-Bridge integriert
// - Kommunikationslogik mit dem Backend implementiert
//

import Foundation
import SwiftUI
import Combine

// Python-Bridge-Import würde hier erfolgen
// import PythonKit in einer vollständigen Implementierung

class AssistantManager: ObservableObject {
    // Singleton-Instance für globalen Zugriff
    static let shared = AssistantManager()
    
    // Veröffentlichte Eigenschaften für SwiftUI-Binding
    @Published var isListening: Bool = false
    @Published var isProcessing: Bool = false
    @Published var assistantResponse: String = ""
    @Published var conversationHistory: [Message] = []
    @Published var lastScreenAnalysis: String = ""
    @Published var activeCommand: String = ""
    
    // Konfiguration
    @Published var apiModel: String = "openai" // "openai" oder "gemini"
    @Published var voiceEnabled: Bool = true
    @Published var screenAnalysisEnabled: Bool = true
    @Published var wakeWord: String = "Assistent"
    
    // Python-Bridge (würde in der vollständigen Implementierung initialisiert)
    // private var pythonBridge: PythonBridge?
    
    // Einstellungs-Fenster-Verwaltung
    @Published var isSettingsWindowShown: Bool = false
    
    private init() {
        loadSettings()
        // In einer vollständigen Implementierung:
        // initializePythonBridge()
    }
    
    // MARK: - Public Interface
    
    /// Startet den Assistenten
    func startAssistant() {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        // In einer vollständigen Implementierung:
        // Starte Python-Backend über die Bridge
        // pythonBridge?.startAssistant()
        
        isProcessing = false
        
        // Simulierte Startmeldung (in der echten App würde dies vom Backend kommen)
        self.addMessage(
            Message(
                content: "Hallo! Ich bin dein Mac-Assistent. Wie kann ich dir helfen?",
                isFromUser: false,
                timestamp: Date()
            )
        )
        
        isListening = true
    }
    
    /// Stoppt den Assistenten
    func stopAssistant() {
        guard !isProcessing else { return }
        
        isProcessing = true
        
        // In einer vollständigen Implementierung:
        // Stoppe Python-Backend über die Bridge
        // pythonBridge?.stopAssistant()
        
        isProcessing = false
        isListening = false
        
        // Simulierte Stoppnachricht
        self.addMessage(
            Message(
                content: "Assistant wurde gestoppt.",
                isFromUser: false,
                timestamp: Date()
            )
        )
    }
    
    /// Sendet einen Befehl an den Assistenten
    func sendCommand(_ command: String) {
        guard !command.isEmpty else { return }
        
        isProcessing = true
        activeCommand = command
        
        // Befehl zur Historie hinzufügen
        self.addMessage(Message(content: command, isFromUser: true, timestamp: Date()))
        
        // In einer vollständigen Implementierung:
        // Sende Befehl an Python-Backend und verarbeite Antwort asynchron
        // Task {
        //     let response = await pythonBridge?.sendCommand(command) ?? "Keine Antwort erhalten."
        //     await MainActor.run {
        //         self.handleResponse(response)
        //     }
        // }
        
        // SIMULIERTE ANTWORT (nur für Prototyp)
        // In der echten App würde dies asynchron vom Python-Backend kommen
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let simulatedResponse = self.simulateResponse(to: command)
            self.handleResponse(simulatedResponse)
        }
    }
    
    /// Zeigt das Einstellungsfenster an
    func showSettings() {
        isSettingsWindowShown = true
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        // In einer vollständigen Implementierung:
        // Lade gespeicherte Einstellungen aus UserDefaults oder einer Konfigurationsdatei
        
        // Beispiel:
        let defaults = UserDefaults.standard
        apiModel = defaults.string(forKey: "apiModel") ?? "openai"
        voiceEnabled = defaults.bool(forKey: "voiceEnabled")
        screenAnalysisEnabled = defaults.bool(forKey: "screenAnalysisEnabled")
        wakeWord = defaults.string(forKey: "wakeWord") ?? "Assistent"
    }
    
    private func saveSettings() {
        // In einer vollständigen Implementierung:
        // Speichere Einstellungen in UserDefaults oder einer Konfigurationsdatei
        
        // Beispiel:
        let defaults = UserDefaults.standard
        defaults.set(apiModel, forKey: "apiModel")
        defaults.set(voiceEnabled, forKey: "voiceEnabled")
        defaults.set(screenAnalysisEnabled, forKey: "screenAnalysisEnabled")
        defaults.set(wakeWord, forKey: "wakeWord")
    }
    
    private func addMessage(_ message: Message) {
        // Füge eine Nachricht zur Konversationshistorie hinzu
        DispatchQueue.main.async {
            self.conversationHistory.append(message)
            
            // Beschränke die Historie auf die letzten 50 Nachrichten, um Speicher zu sparen
            if self.conversationHistory.count > 50 {
                self.conversationHistory.removeFirst()
            }
        }
    }
    
    private func handleResponse(_ response: String) {
        // Antwort vom Backend verarbeiten
        self.assistantResponse = response
        
        // Antwort zur Historie hinzufügen
        self.addMessage(Message(content: response, isFromUser: false, timestamp: Date()))
        
        // Status zurücksetzen
        self.isProcessing = false
        self.activeCommand = ""
    }
    
    // SIMULIERTE ANTWORT (nur für Prototyp)
    private func simulateResponse(to command: String) -> String {
        let commandLower = command.lowercased()
        
        if commandLower.contains("hallo") || commandLower.contains("hi") {
            return "Hallo! Wie kann ich dir helfen?"
        } else if commandLower.contains("öffne") && commandLower.contains("safari") {
            return "Ich öffne Safari für dich."
        } else if commandLower.contains("schließe") {
            return "Ich schließe die Anwendung für dich."
        } else if commandLower.contains("mail") || commandLower.contains("email") {
            return "Möchtest du eine neue E-Mail erstellen oder deine Mails überprüfen?"
        } else if commandLower.contains("uhrzeit") || commandLower.contains("zeit") {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeString = formatter.string(from: Date())
            return "Es ist jetzt \(timeString) Uhr."
        } else if commandLower.contains("hilfe") {
            return "Ich kann dir bei vielen Aufgaben helfen: Anwendungen öffnen und schließen, Text eingeben, Informationen suchen und vieles mehr. Was möchtest du tun?"
        } else {
            return "Ich verstehe deine Anfrage. Wie kann ich dir dabei helfen?"
        }
    }
}

// Struktur für Konversationsnachrichten
struct Message: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    
    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}