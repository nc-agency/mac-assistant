// 
// EnhancedPopoverView.swift - Erweiterte Popup-Ansicht mit kontextsensitiven Funktionen
// Erstellt am: 2025-05-04
// Änderungen:
// - Komplett überarbeitete UI mit modernem Design
// - Kontext-bewusste Vorschläge und Automatisierungen
// - Workflow-Erkennung und intelligente Assistenz
// - Fortschrittliche Visualisierungen für KI-Aktivität
//

import SwiftUI
import AVKit

struct PopoverView: View {
    @EnvironmentObject var assistantManager: AssistantManager
    @EnvironmentObject var contextManager: ContextManager
    
    @State private var commandInput: String = ""
    @State private var isInputFocused: Bool = false
    @State private var showWorkflowPanel: Bool = false
    @State private var expandedConversationId: UUID? = nil
    
    // Animation für Fließeffekte
    @State private var audioLevels: [CGFloat] = [0.2, 0.5, 0.8, 0.4, 0.3, 0.6, 0.7, 0.3]
    @State private var animateBackground = false
    
    private let conversationLimit = 10
    
    var body: some View {
        ZStack {
            // Hintergrund mit subtiler Animation
            BackgroundView(animate: $animateBackground)
            
            VStack(spacing: 0) {
                // Header mit Status und App-Kontext
                EnhancedHeaderView(
                    isListening: $assistantManager.isListening,
                    currentApp: contextManager.currentAppName
                )
                
                // Intelligente Vorschläge basierend auf aktuellem Kontext
                if !contextManager.suggestedActions.isEmpty {
                    SuggestionView(
                        suggestions: contextManager.suggestedActions,
                        onSuggestionTapped: { action in
                            assistantManager.sendCommand(action.command)
                        }
                    )
                }
                
                // Workflow-Erkennung
                if let workflow = contextManager.detectedWorkflow {
                    WorkflowBanner(
                        workflow: workflow,
                        isExpanded: $showWorkflowPanel
                    )
                    
                    if showWorkflowPanel {
                        WorkflowStepsView(steps: contextManager.workflowSteps)
                    }
                }
                
                // Chat-Verlauf mit erweiterten Interaktionsmöglichkeiten
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(limitedConversationHistory) { message in
                                EnhancedMessageView(
                                    message: message,
                                    isExpanded: expandedConversationId == message.id,
                                    onTap: {
                                        withAnimation {
                                            if expandedConversationId == message.id {
                                                expandedConversationId = nil
                                            } else {
                                                expandedConversationId = message.id
                                            }
                                        }
                                    },
                                    onActionTapped: handleMessageAction
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: assistantManager.conversationHistory.count) { _ in
                        if let lastMessage = limitedConversationHistory.last {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Trennlinie mit visueller Aufwertung
                Divider()
                    .background(LinearGradient(
                        gradient: Gradient(colors: [Color.clear, Color.accentColor.opacity(0.5), Color.clear]),
                        startPoint: .leading, 
                        endPoint: .trailing
                    ))
                
                // Bildschirmanalyse-Zusammenfassung
                if assistantManager.screenAnalysisEnabled && !contextManager.lastScreenAnalysis.isEmpty {
                    EnhancedScreenAnalysisView(analysis: contextManager.lastScreenAnalysis)
                }
                
                // Status-Indikatoren und Audio-Visualisierung
                statusView
                
                // Erweiterte Eingabezeile mit Kontext-Symbolen
                EnhancedInputView(
                    text: $commandInput,
                    isListening: assistantManager.isListening,
                    isProcessing: assistantManager.isProcessing,
                    currentAppIcon: iconForApp(contextManager.currentAppName),
                    onSend: sendCommand,
                    onMicToggle: toggleMic
                )
                .padding()
            }
        }
        .frame(width: 380)
        .onAppear {
            startAudioSimulation()
            animateBackground = true
        }
        .onDisappear {
            animateBackground = false
        }
    }
    
    // MARK: - Hilfsfunktionen und Komponenten
    
    private var limitedConversationHistory: [Message] {
        if assistantManager.conversationHistory.count > conversationLimit {
            return Array(assistantManager.conversationHistory.suffix(conversationLimit))
        }
        return assistantManager.conversationHistory
    }
    
    private var statusView: some View {
        Group {
            if assistantManager.isProcessing {
                // Erweiterte Lade-Animation
                ProcessingIndicatorView()
                    .frame(height: 40)
            } else if assistantManager.isListening && assistantManager.voiceEnabled {
                // Audio-Visualisierung
                EnhancedAudioVisualizerView(levels: $audioLevels)
                    .frame(height: 40)
                    .padding(.vertical, 4)
            } else {
                // Platzhalterhöhe für konsistentes Layout
                Color.clear.frame(height: 40)
            }
        }
    }
    
    private func sendCommand() {
        guard !commandInput.isEmpty && !assistantManager.isProcessing else { return }
        
        let command = commandInput
        commandInput = ""
        
        assistantManager.sendCommand(command)
    }
    
    private func toggleMic() {
        if assistantManager.isListening {
            assistantManager.stopAssistant()
        } else {
            assistantManager.startAssistant()
        }
    }
    
    private func handleMessageAction(_ action: MessageAction, for message: Message) {
        switch action {
        case .copy:
            // Text in Zwischenablage kopieren
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(message.content, forType: .string)
            
        case .repeat:
            // Befehl wiederholen
            if message.isFromUser {
                assistantManager.sendCommand(message.content)
            }
            
        case .save:
            // Nachricht speichern (als Notiz oder Erinnerung)
            // In einer vollständigen Implementierung würden wir hier
            // die Notes-App oder Reminders-App integrieren
            break
            
        case .share:
            // Teilen-Menü anzeigen
            // In einer vollständigen Implementierung würden wir hier
            // das native macOS-Teilen-Menü aufrufen
            break
        }
    }
    
    private func iconForApp(_ appName: String?) -> String {
        guard let appName = appName else { return "app" }
        
        switch appName {
        case "Safari": return "safari"
        case "Mail": return "mail"
        case "Finder": return "finder"
        case "Messages": return "message"
        case "Calendar": return "calendar"
        case "Notes": return "note.text"
        case "Photos": return "photo"
        case "Music": return "music.note"
        case "Preview": return "doc.viewfinder"
        case "Pages": return "doc.text"
        case "Numbers": return "number"
        case "Keynote": return "chart.bar.presentation"
        case "Xcode": return "hammer"
        case "Terminal": return "terminal"
        default: return "app"
        }
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

// MARK: - Erweiterte UI-Komponenten

// Animierter Hintergrund
struct BackgroundView: View {
    @Binding var animate: Bool
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            
            // Dezente animierte Elemente im Hintergrund
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.accentColor.opacity(0.05))
                    .frame(width: CGFloat.random(in: 100...200))
                    .position(
                        x: CGFloat.random(in: 0...380),
                        y: CGFloat.random(in: 0...520)
                    )
                    .blur(radius: 30)
                    .scaleEffect(animate ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: Double.random(in: 4...8))
                            .repeatForever(autoreverses: true)
                            .delay(Double.random(in: 0...3)),
                        value: animate
                    )
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// Erweiterte Kopfzeile
struct EnhancedHeaderView: View {
    @Binding var isListening: Bool
    var currentApp: String?
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                // App-Logo und Titel
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                    .symbolRenderingMode(.multicolor)
                
                Text("Mac Assistant")
                    .font(.headline)
                    .foregroundStyle(LinearGradient(
                        gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.7)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                
                Spacer()
                
                // Status-Anzeige mit visueller Verbesserung
                HStack(spacing: 4) {
                    Circle()
                        .fill(isListening ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                        .shadow(color: isListening ? Color.green.opacity(0.5) : Color.clear, radius: 3)
                    
                    Text(isListening ? "Aktiv" : "Inaktiv")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
            }
            
            // Aktuelle App-Anzeige
            if let appName = currentApp {
                HStack {
                    Image(systemName: "arrow.forward")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("Aktiv: \(appName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(
            ZStack {
                Color(NSColor.controlBackgroundColor)
                
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.accentColor.opacity(0.05),
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
    }
}

// Vorschlagsansicht
struct SuggestionView: View {
    let suggestions: [SuggestedAction]
    let onSuggestionTapped: (SuggestedAction) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { action in
                    Button(action: {
                        onSuggestionTapped(action)
                    }) {
                        HStack {
                            Image(systemName: action.icon)
                                .font(.caption)
                            
                            Text(action.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

// Erkannter Workflow-Banner
struct WorkflowBanner: View {
    let workflow: String
    @Binding var isExpanded: Bool
    
    var body: some View {
        Button(action: {
            withAnimation {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(.yellow)
                
                Text("Erkannter Workflow: \(workflow)")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.1))
            )
            .padding(.horizontal)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Workflow-Schritte
struct WorkflowStepsView: View {
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(steps.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                    
                    Text(steps[index])
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.05))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// Erweiterte Nachrichtenansicht
struct EnhancedMessageView: View {
    let message: Message
    let isExpanded: Bool
    let onTap: () -> Void
    let onActionTapped: (MessageAction, Message) -> Void
    
    var body: some View {
        VStack {
            HStack {
                if message.isFromUser {
                    Spacer()
                }
                
                VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                    // Nachrichteninhalt
                    Text(message.content)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    message.isFromUser 
                                    ? LinearGradient(
                                        gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.8)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                      )
                                    : Color(NSColor.controlBackgroundColor)
                                )
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                        .foregroundColor(message.isFromUser ? .white : .primary)
                    
                    // Zeitstempel
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .onTapGesture {
                    onTap()
                }
                
                if !message.isFromUser {
                    Spacer()
                }
            }
            
            // Erweiterte Aktionen, wenn Nachricht erweitert ist
            if isExpanded {
                HStack {
                    Spacer()
                    
                    ForEach(MessageAction.allCases, id: \.self) { action in
                        Button(action: {
                            onActionTapped(action, message)
                        }) {
                            Image(systemName: action.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 30, height: 30)
                                .background(Color(NSColor.controlBackgroundColor))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(action.description)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Nachrichtenaktionen
enum MessageAction: CaseIterable {
    case copy, repeat, save, share
    
    var icon: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .repeat: return "arrow.triangle.2.circlepath"
        case .save: return "square.and.arrow.down"
        case .share: return "square.and.arrow.up"
        }
    }
    
    var description: String {
        switch self {
        case .copy: return "Kopieren"
        case .repeat: return "Wiederholen"
        case .save: return "Speichern"
        case .share: return "Teilen"
        }
    }
}

// Bildschirmanalyse mit visuellen Verbesserungen
struct EnhancedScreenAnalysisView: View {
    let analysis: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "eye")
                    .font(.caption)
                    .foregroundColor(.blue)
                
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
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// Verarbeitungs-Indikator
struct ProcessingIndicatorView: View {
    @State private var animateGradient = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Eleganter Fortschrittsbalken
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple, .blue]),
                            startPoint: animateGradient ? .leading : .trailing,
                            endPoint: animateGradient ? .trailing : .leading
                        )
                    )
                    .frame(height: 4)
                    .offset(x: animateGradient ? 100 : -100)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: animateGradient
                    )
            }
            .frame(width: 150)
            .onAppear {
                animateGradient = true
            }
            
            Text("Verarbeitung läuft...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// Erweiterte Audio-Visualisierung
struct EnhancedAudioVisualizerView: View {
    @Binding var levels: [CGFloat]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .accentColor]),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 4, height: 20 * levels[index])
                    .animation(.easeInOut(duration: 0.1), value: levels[index])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// Erweiterte Eingabezeilele
struct EnhancedInputView: View {
    @Binding var text: String
    var isListening: Bool
    var isProcessing: Bool
    var currentAppIcon: String
    let onSend: () -> Void
    let onMicToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // App-Kontext-Symbol
            Image(systemName: currentAppIcon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .clipShape(Circle())
            
            // Sprach-Toggle
            Button(action: onMicToggle) {
                Image(systemName: isListening ? "mic.fill" : "mic")
                    .font(.system(size: 16))
                    .foregroundColor(isListening ? .red : .accentColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isProcessing)
            .help(isListening ? "Spracherkennung deaktivieren" : "Spracherkennung aktivieren")
            
            // Texteingabe
            TextField("Befehl eingeben...", text: $text, onCommit: onSend)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(isProcessing)
            
            // Senden-Button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(
                        text.isEmpty || isProcessing 
                        ? .gray 
                        : .accentColor
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(text.isEmpty || isProcessing)
            .help("Befehl senden")
        }
    }
}

// Vorschau für SwiftUI-Canvas
struct PopoverView_Previews: PreviewProvider {
    static var previews: some View {
        PopoverView()
            .environmentObject(AssistantManager.shared)
            .environmentObject(ContextManager.shared)
            .frame(width: 380, height: 520)
    }
}