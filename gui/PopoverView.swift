// 
// PopoverView.swift - Hauptansicht für den Mac-Assistenten-Popover
// Erstellt am: 2025-05-04
// Änderungen:
// - Initiale Implementierung der PopoverView
// - Chat-Interface und Steuerungselemente implementiert
// - Bildschirmanalyse-Anzeige integriert
//

import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var assistantManager: AssistantManager
    @State private var commandInput: String = ""
    @State private var isInputFocused: Bool = false
    
    // Audio-Visualisierung (simuliert)
    @State private var audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.4, 0.3, 0.6, 0.7, 0.3]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header mit Status
            HeaderView(isListening: $assistantManager.isListening)
            
            // Chat-Verlauf
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(assistantManager.conversationHistory) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .onChange(of: assistantManager.conversationHistory.count) { _ in
                    if let lastMessage = assistantManager.conversationHistory.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Trennlinie
            Divider()
            
            // Bildschirmanalyse-Indikator
            if assistantManager.screenAnalysisEnabled && !assistantManager.lastScreenAnalysis.isEmpty {
                ScreenAnalysisView(analysis: assistantManager.lastScreenAnalysis)
            }
            
            if assistantManager.isProcessing {
                // Lade-Indikator
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    Text("Verarbeite...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if assistantManager.isListening && assistantManager.voiceEnabled {
                // Audio-Visualisierung
                AudioVisualizerView(levels: $audioLevels)
                    .frame(height: 30)
                    .padding(.vertical, 4)
                    .onAppear {
                        startAudioSimulation()
                    }
            }
            
            // Eingabebereich
            HStack(spacing: 8) {
                // Sprach-Toggle
                Button(action: {
                    if assistantManager.isListening {
                        assistantManager.stopAssistant()
                    } else {
                        assistantManager.startAssistant()
                    }
                }) {
                    Image(systemName: assistantManager.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 16))
                        .foregroundColor(assistantManager.isListening ? .red : .accentColor)
                        .frame(width: 30, height: 30)
                        .background(
                            Circle()
                                .fill(Color.accentColor.opacity(0.1))
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help(assistantManager.isListening ? "Spracherkennung deaktivieren" : "Spracherkennung aktivieren")
                
                // Texteingabe
                TextField("Befehl eingeben...", text: $commandInput, onCommit: sendCommand)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(assistantManager.isProcessing)
                
                // Senden-Button
                Button(action: sendCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(
                            commandInput.isEmpty || assistantManager.isProcessing 
                            ? .gray 
                            : .accentColor
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(commandInput.isEmpty || assistantManager.isProcessing)
                .help("Befehl senden")
            }
            .padding()
        }
        .frame(width: 360)
    }
    
    private func sendCommand() {
        guard !commandInput.isEmpty && !assistantManager.isProcessing else { return }
        
        let command = commandInput
        commandInput = ""
        
        assistantManager.sendCommand(command)
    }
    
    // Simuliert die Audio-Visualisierung
    private func startAudioSimulation() {
        // In einer echten App würde dies auf tatsächlichen Audiodaten basieren
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard assistantManager.isListening && assistantManager.voiceEnabled else {
                timer.invalidate()
                return
            }
            
            // Simuliere Änderungen in den Audiopegeln
            withAnimation {
                audioLevels = audioLevels.map { _ in
                    CGFloat.random(in: 0.1...0.9)
                }
            }
        }
    }
}

// Header-Komponente
struct HeaderView: View {
    @Binding var isListening: Bool
    
    var body: some View {
        HStack {
            // Icon und Titel
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            
            Text("Mac Assistant")
                .font(.headline)
            
            Spacer()
            
            // Status-Anzeige
            HStack(spacing: 4) {
                Circle()
                    .fill(isListening ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Text(isListening ? "Aktiv" : "Inaktiv")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// Nachrichten-Komponente
struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.isFromUser 
                                  ? Color.accentColor
                                  : Color(NSColor.controlBackgroundColor))
                    )
                    .foregroundColor(message.isFromUser ? .white : .primary)
                
                // Zeitstempel
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !message.isFromUser {
                Spacer()
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Bildschirmanalyse-Anzeige
struct ScreenAnalysisView: View {
    let analysis: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "eye")
                    .font(.caption)
                
                Text("Bildschirmanalyse")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text(analysis)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// Audio-Visualisierung
struct AudioVisualizerView: View {
    @Binding var levels: [CGFloat]
    
    var body: some View {
        HStack(spacing: 3) {
            Spacer()
            
            ForEach(0..<levels.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 20 * levels[index])
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
            
            Spacer()
        }
    }
}

// Vorschau für SwiftUI-Canvas
struct PopoverView_Previews: PreviewProvider {
    static var previews: some View {
        PopoverView()
            .environmentObject(AssistantManager.shared)
            .frame(width: 360, height: 512)
    }
}