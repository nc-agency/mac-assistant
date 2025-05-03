/**
 * MenuBarView.swift
 * Erstellt am: 2025-05-04
 * 
 * Änderungen:
 * - Implementierung der Menüleisten-Benutzeroberfläche
 * - Integration der Haupt-UI-Komponenten
 * - Einrichtung der Tab-Navigation
 */

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Kopfzeile mit Logo und Status
            HeaderView()
            
            // Tabs für verschiedene Funktionen
            TabView(selection: $appState.selectedTab) {
                // Chat-Oberfläche
                ChatView()
                    .tabItem {
                        Label("Chat", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(0)
                
                // Aktionen-Oberfläche
                ActionsView()
                    .tabItem {
                        Label("Aktionen", systemImage: "wand.and.stars")
                    }
                    .tag(1)
                
                // Einstellungen
                SettingsView()
                    .tabItem {
                        Label("Einstellungen", systemImage: "gear")
                    }
                    .tag(2)
            }
            .padding(.horizontal, 4)
            
            // Statusleiste
            FooterView()
        }
        .frame(width: 400, height: 500)
    }
}

/// Kopfzeile der App mit Logo und Status
struct HeaderView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    
    var body: some View {
        HStack {
            // Logo und Titel
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.accentColor)
                
                Text("Mac Assistant")
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            // Status-Indikator
            HStack(spacing: 4) {
                Circle()
                    .fill(pythonBridge.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(pythonBridge.isConnected ? "Verbunden" : "Nicht verbunden")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// Fußzeile mit Systeminformationen
struct FooterView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack {
            // Sprachstatus
            Label(
                pythonBridge.voiceStatus,
                systemImage: pythonBridge.voiceStatus == "Aktiv" ? "mic.fill" : "mic.slash"
            )
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
            
            // Systemstatus
            Text(pythonBridge.assistantStatus)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
}

/// Chat-Oberfläche
struct ChatView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Chatverlauf
            ScrollView {
                if let conversation = appState.conversations.first {
                    LazyVStack(spacing: 12) {
                        ForEach(conversation.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                } else {
                    // Leerer Zustand
                    VStack(spacing: 16) {
                        Image(systemName: "bubble.left.and.text.bubble.right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("Starte eine Unterhaltung mit dem Assistenten")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        
                        Text("Tippe eine Frage oder einen Befehl unten ein, um loszulegen.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            
            // Trennlinie
            Divider()
            
            // Eingabebereich
            HStack(alignment: .bottom) {
                // Multimedia-Button
                Button(action: {
                    // Multimediale Optionen anzeigen (Bild, Datei, etc.)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Datei oder Bild hinzufügen")
                
                // Texteingabefeld
                TextField("Frage oder Befehl eingeben...", text: $appState.userInput, axis: .vertical)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .lineLimit(5)
                    .onSubmit {
                        sendMessage()
                    }
                
                // Senden-Button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundColor(appState.userInput.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(appState.userInput.isEmpty || pythonBridge.isProcessing)
                .help("Nachricht senden")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
        }
    }
    
    /// Sendet die Nachricht an den Assistenten
    private func sendMessage() {
        guard !appState.userInput.isEmpty, !pythonBridge.isProcessing else { return }
        
        let userMessage = appState.userInput
        appState.addUserMessage(userMessage)
        
        // Texteingabe zurücksetzen
        appState.userInput = ""
        
        // An Python-Backend senden
        pythonBridge.sendCommand("process_text", withParameters: ["text": userMessage])
    }
}

/// Chat-Nachrichtenblase
struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(10)
                    .background(message.isUser ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(12)
                
                Text(formattedTime(from: message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isUser {
                Spacer()
            }
        }
    }
    
    /// Formatiert den Zeitstempel für die Anzeige
    private func formattedTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Aktionen-Oberfläche
struct ActionsView: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    
    // Liste der verfügbaren Aktionen
    let actions = [
        Action(icon: "display", title: "Screenshot analysieren", command: "analyze_screen"),
        Action(icon: "keyboard", title: "Text schreiben", command: "type_text"),
        Action(icon: "folder", title: "Datei finden", command: "find_file"),
        Action(icon: "gearshape", title: "Einstellung ändern", command: "change_setting"),
        Action(icon: "app.dashed", title: "App starten", command: "launch_app"),
        Action(icon: "mic", title: "Diktiermodus", command: "dictation_mode")
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(actions) { action in
                    ActionButton(action: action)
                }
            }
            .padding()
        }
    }
}

/// Einzelne Aktion für die Aktionen-Oberfläche
struct ActionButton: View {
    @EnvironmentObject private var pythonBridge: PythonBridge
    
    let action: Action
    
    var body: some View {
        Button(action: {
            pythonBridge.sendCommand(action.command)
        }) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.accentColor)
                
                Text(action.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(minWidth: 80, minHeight: 80)
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Struktur für eine Aktion
struct Action: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let command: String
}

/// Einstellungen-Oberfläche
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Form {
            Section(header: Text("Allgemein").font(.headline)) {
                Toggle("Beim Login starten", isOn: $appState.settings.startAtLogin)
                Toggle("Sprachsteuerung aktivieren", isOn: $appState.settings.useVoiceControl)
                Toggle("Bildschirmanalyse aktivieren", isOn: $appState.settings.useScreenAnalysis)
            }
            
            Section(header: Text("Sprache & KI").font(.headline)) {
                Picker("Sprache", selection: $appState.settings.preferredVoiceLanguage) {
                    Text("Deutsch").tag("Deutsch")
                    Text("Englisch").tag("Englisch")
                }
                
                Picker("KI-Modell", selection: $appState.settings.aiModel) {
                    Text("OpenAI").tag("OpenAI")
                    Text("Gemini").tag("Gemini")
                }
                .pickerStyle(.menu)
            }
            
            Section(header: Text("Darstellung").font(.headline)) {
                Picker("Darstellung", selection: $appState.settings.theme) {
                    Text("System").tag("System")
                    Text("Hell").tag("Hell")
                    Text("Dunkel").tag("Dunkel")
                }
                .pickerStyle(.menu)
            }
            
            Section {
                HStack {
                    Spacer()
                    Button("Zurücksetzen") {
                        appState.settings.resetToDefaults()
                    }
                    Spacer()
                }
            }
        }
        .padding()
    }
}

/// Vorschau für SwiftUI-Canvas
struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView()
            .environmentObject(PythonBridge())
            .environmentObject(AppState())
    }
}