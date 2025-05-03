/**
 * PythonBridge.swift
 * Erstellt am: 2025-05-04
 * 
 * Änderungen:
 * - Initiale Implementierung der Python-Swift-Brücke
 * - Implementierung der bidirektionalen Kommunikation zwischen Swift und Python
 * - Handling von asynchronen Python-Callbacks
 * - Integration mit dem EventSystem zur UI-Aktualisierung
 */

import Foundation
import Cocoa
import SwiftUI
import Combine

/// Event-Typen für die Kommunikation mit dem Python-Backend
enum PythonEvent: String, Codable {
    case response
    case error
    case systemStatus
    case voiceStatus
    case screenData
    case notificationReceived
}

/// Struktur für die Daten, die vom Python-Backend empfangen werden
struct PythonResponse: Codable, Identifiable {
    var id = UUID()
    var eventType: PythonEvent
    var data: [String: String]
    var timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case eventType, data, timestamp
    }
}

/// Klasse zur Kommunikation mit dem Python-Backend
class PythonBridge: ObservableObject {
    // Published-Properties für SwiftUI-Updates
    @Published var isConnected: Bool = false
    @Published var lastResponse: PythonResponse?
    @Published var assistantStatus: String = "Inaktiv"
    @Published var voiceStatus: String = "Ausgeschaltet"
    @Published var systemMessages: [String] = []
    @Published var isProcessing: Bool = false
    
    // Private Eigenschaften für die Python-Prozessverwaltung
    private var pythonProcess: Process?
    private var pythonStdout: Pipe?
    private var pythonStdin: Pipe?
    private var pythonStderr: Pipe?
    private var pythonDataHandle: FileHandle?
    private var cancellables = Set<AnyCancellable>()
    
    // Timer für regelmäßige Überprüfungen
    private var connectionCheckTimer: Timer?
    
    /// Initialisiert die Python-Brücke
    init() {
        setupPythonProcess()
    }
    
    /// Richtet den Python-Prozess ein
    private func setupPythonProcess() {
        // Stellen Sie sicher, dass frühere Prozesse beendet sind
        stopPythonProcess()
        
        // Pfade für das Python-Skript finden
        guard let appPath = Bundle.main.resourcePath else {
            logMessage("Fehler: App-Ressourcenpfad nicht gefunden.", isError: true)
            return
        }
        
        let pythonPath = "\(appPath)/python"
        let mainScriptPath = "\(appPath)/src/main.py"
        let pythonExecutable = "\(pythonPath)/bin/python3"
        
        // Pipes für die Kommunikation einrichten
        pythonStdout = Pipe()
        pythonStdin = Pipe()
        pythonStderr = Pipe()
        
        // Python-Prozess erstellen
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonExecutable)
        process.arguments = [mainScriptPath, "--api-mode"]
        process.standardOutput = pythonStdout
        process.standardInput = pythonStdin
        process.standardError = pythonStderr
        
        // Umgebungsvariablen setzen
        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = pythonPath
        env["PATH"] = "\(pythonPath)/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        // File Handles für die I/O einrichten
        pythonDataHandle = pythonStdout?.fileHandleForReading
        
        // Ausgabe asynchron lesen
        NotificationCenter.default.addObserver(
            forName: .NSFileHandleDataAvailable,
            object: pythonDataHandle,
            queue: .main
        ) { [weak self] _ in
            self?.readPythonOutput()
        }
        pythonDataHandle?.waitForDataInBackgroundAndNotify()
        
        // Stderr-Ausgabe für Debug-Zwecke
        let stderrHandle = pythonStderr?.fileHandleForReading
        NotificationCenter.default.addObserver(
            forName: .NSFileHandleDataAvailable,
            object: stderrHandle,
            queue: .main
        ) { [weak self] _ in
            guard let data = stderrHandle?.availableData, !data.isEmpty else { return }
            if let errorString = String(data: data, encoding: .utf8) {
                self?.logMessage("Python Error: \(errorString)", isError: true)
            }
            stderrHandle?.waitForDataInBackgroundAndNotify()
        }
        stderrHandle?.waitForDataInBackgroundAndNotify()
        
        // Prozess asynchron starten
        do {
            pythonProcess = process
            try process.run()
            isConnected = true
            
            // Timer für die Verbindungsprüfung
            connectionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
                self?.checkConnection()
            }
            
            logMessage("Python-Prozess gestartet")
            
            // Beim Beenden des Prozesses reagieren
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.logMessage("Python-Prozess beendet mit Status: \(process.terminationStatus)")
                }
            }
        } catch {
            isConnected = false
            logMessage("Fehler beim Starten des Python-Prozesses: \(error.localizedDescription)", isError: true)
        }
    }
    
    /// Liest die Ausgabe des Python-Prozesses
    private func readPythonOutput() {
        guard let data = pythonDataHandle?.availableData, !data.isEmpty else {
            pythonDataHandle?.waitForDataInBackgroundAndNotify()
            return
        }
        
        if let outputString = String(data: data, encoding: .utf8) {
            processPythonOutput(outputString)
        }
        
        pythonDataHandle?.waitForDataInBackgroundAndNotify()
    }
    
    /// Verarbeitet die Ausgabe des Python-Prozesses
    private func processPythonOutput(_ output: String) {
        // Die Ausgabe kann mehrere JSON-Objekte enthalten
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        for line in lines {
            if line.hasPrefix("{") && line.hasSuffix("}") {
                do {
                    if let jsonData = line.data(using: .utf8) {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        let response = try decoder.decode(PythonResponse.self, from: jsonData)
                        
                        DispatchQueue.main.async { [weak self] in
                            self?.handlePythonResponse(response)
                        }
                    }
                } catch {
                    logMessage("Fehler beim Decodieren der Python-Antwort: \(error.localizedDescription)", isError: true)
                }
            } else {
                // Nicht-JSON-Ausgabe als Systemnachricht behandeln
                logMessage("Python: \(line)")
            }
        }
    }
    
    /// Handhabt die decodierte Python-Antwort
    private func handlePythonResponse(_ response: PythonResponse) {
        // Die neueste Antwort setzen
        lastResponse = response
        
        // Je nach Event-Typ die entsprechenden Aktionen ausführen
        switch response.eventType {
        case .response:
            if let message = response.data["message"] {
                logMessage("Assistent: \(message)")
            }
            isProcessing = false
            
        case .error:
            if let errorMessage = response.data["message"] {
                logMessage("Fehler: \(errorMessage)", isError: true)
            }
            isProcessing = false
            
        case .systemStatus:
            if let status = response.data["status"] {
                assistantStatus = status
            }
            
        case .voiceStatus:
            if let status = response.data["status"] {
                voiceStatus = status
            }
            
        case .screenData:
            // Hier könnte die Bildschirmdaten-Verarbeitung stattfinden
            break
            
        case .notificationReceived:
            if let title = response.data["title"], let message = response.data["message"] {
                showNotification(title: title, message: message)
            }
        }
    }
    
    /// Sendet einen Befehl an das Python-Backend
    func sendCommand(_ command: String, withParameters parameters: [String: String] = [:]) {
        guard isConnected, let pythonStdin = pythonStdin else {
            logMessage("Kann Befehl nicht senden: Keine Verbindung zum Python-Prozess", isError: true)
            return
        }
        
        var commandDict: [String: Any] = ["command": command]
        if !parameters.isEmpty {
            commandDict["parameters"] = parameters
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: commandDict, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let commandString = jsonString + "\n"
                if let data = commandString.data(using: .utf8) {
                    pythonStdin.fileHandleForWriting.write(data)
                    isProcessing = true
                    logMessage("Befehl gesendet: \(command)")
                }
            }
        } catch {
            logMessage("Fehler beim Senden des Befehls: \(error.localizedDescription)", isError: true)
        }
    }
    
    /// Prüft die Verbindung zum Python-Prozess
    private func checkConnection() {
        guard let process = pythonProcess else {
            isConnected = false
            return
        }
        
        isConnected = process.isRunning
        
        if !isConnected {
            // Versuchen, den Prozess neu zu starten
            setupPythonProcess()
        } else {
            // Ping senden, um zu prüfen, ob das Python-Skript noch reagiert
            sendCommand("ping")
        }
    }
    
    /// Stoppt den Python-Prozess
    func stopPythonProcess() {
        connectionCheckTimer?.invalidate()
        connectionCheckTimer = nil
        
        if let process = pythonProcess, process.isRunning {
            // Versuchen, den Prozess sauber zu beenden
            sendCommand("exit")
            
            // Kurz warten und dann erzwingen, falls nötig
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                if process.isRunning {
                    process.terminate()
                }
            }
        }
        
        pythonProcess = nil
        isConnected = false
    }
    
    /// Fügt eine Nachricht zum Log hinzu
    private func logMessage(_ message: String, isError: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            let logMessage = "[\(timestamp)] \(message)"
            self?.systemMessages.append(logMessage)
            
            // Die Liste begrenzen, um Speicherüberlauf zu vermeiden
            if (self?.systemMessages.count ?? 0) > 100 {
                self?.systemMessages.removeFirst()
            }
            
            // Für die Fehlersuche in die Konsole ausgeben
            if isError {
                print("ERROR: \(logMessage)")
            } else {
                print("INFO: \(logMessage)")
            }
        }
    }
    
    /// Zeigt eine System-Benachrichtigung an
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    /// Bereinigt beim Deinitialisieren
    deinit {
        stopPythonProcess()
    }
}