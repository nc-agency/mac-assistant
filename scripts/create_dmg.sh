#!/bin/bash
# 
# create_dmg.sh - Script zur Erstellung der DMG-Installationsdatei
# Erstellt am: 2025-05-04
# Änderungen:
# - Initialer Script für DMG-Erzeugung für Mac-Assistenten
# - Automatisierter Build-Prozess mit Xcode und Python-Integration
#

# Konstanten
APP_NAME="MacAssistant"
DMG_NAME="${APP_NAME}_Installer"
VERSION=$(grep -A 1 "CFBundleShortVersionString" ../xcode/MacAssistant/MacAssistant/Info.plist | grep string | sed -E 's/.*>([0-9.]+)<.*/\1/')
BUILD_DIR="../build"
DMG_DIR="${BUILD_DIR}/dmg"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_FINAL="${BUILD_DIR}/${DMG_NAME}_${VERSION}.dmg"
RESOURCES_DIR="../resources"
XCODE_PROJECT="../xcode/MacAssistant/MacAssistant.xcodeproj"
PYTHON_DIR="../src"

# Farben für Statusmeldungen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion für Statusmeldungen
function log_status {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function log_success {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function log_warning {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function log_error {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Überprüfen, ob create-dmg installiert ist
if ! command -v create-dmg &> /dev/null; then
    log_error "create-dmg ist nicht installiert. Installiere es mit 'brew install create-dmg'."
    exit 1
fi

# Verzeichnisse erstellen
log_status "Verzeichnisse vorbereiten..."
mkdir -p "${BUILD_DIR}"
mkdir -p "${DMG_DIR}"

# Xcode-Projekt bauen
log_status "Xcode-Projekt bauen..."
xcodebuild -project "${XCODE_PROJECT}" -scheme MacAssistant -configuration Release -derivedDataPath "${BUILD_DIR}/DerivedData" clean build

if [ $? -ne 0 ]; then
    log_error "Xcode-Build fehlgeschlagen."
    exit 1
fi

# App-Bundle suchen
APP_BUNDLE=$(find "${BUILD_DIR}/DerivedData" -name "*.app" -type d)
if [ -z "${APP_BUNDLE}" ]; then
    log_error "App-Bundle nicht gefunden nach dem Build."
    exit 1
fi

# App-Bundle kopieren
log_status "App-Bundle kopieren..."
cp -R "${APP_BUNDLE}" "${BUILD_DIR}/"

# Python-Umgebung für die App vorbereiten
log_status "Python-Umgebung vorbereiten..."
mkdir -p "${APP_DIR}/Contents/Resources/python"
cp -R "${PYTHON_DIR}"/* "${APP_DIR}/Contents/Resources/python/"

# Python-Bridge-Skript erstellen
log_status "Python-Bridge-Skript erstellen..."
cat > "${APP_DIR}/Contents/Resources/python/bridge.py" << EOF
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
bridge.py - Python-Bridge für Mac-Assistenten
Erstellt am: 2025-05-04
"""

import os
import sys
import json
import time
import threading
import logging
from typing import Dict, Any, Optional

# Logging einrichten
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(os.path.expanduser('~/Library/Logs/MacAssistant/bridge.log'))
    ]
)
logger = logging.getLogger("PythonBridge")

# Verzeichnis für Logs erstellen
os.makedirs(os.path.expanduser('~/Library/Logs/MacAssistant'), exist_ok=True)

# Lokale Importe
try:
    import assistant
    import ai_service
    import voice
    import screen
    import mac_control
    
    logger.info("Python-Module erfolgreich importiert")
except ImportError as e:
    logger.error(f"Fehler beim Importieren der Module: {e}")
    # Füge das src-Verzeichnis zum Pfad hinzu
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    try:
        # Erneut versuchen
        import assistant
        import ai_service
        import voice
        import screen
        import mac_control
        
        logger.info("Python-Module erfolgreich importiert (2. Versuch)")
    except ImportError as e:
        logger.error(f"Module konnten nicht importiert werden: {e}")
        sys.exit(1)

class Bridge:
    """Brückenklasse für die Kommunikation zwischen Swift und Python"""
    
    def __init__(self):
        self.config = None
        self.assistant = None
        self.ai_service = None
        self.voice_manager = None
        self.screen_manager = None
        self.mac_controller = None
        
        # Initialisierung starten
        self.initialize()
        
        # Bereitschaftssignal senden
        print("BRIDGE_INITIALIZED", flush=True)
        logger.info("Python-Bridge initialisiert und bereit")
    
    def initialize(self):
        """Initialisiert alle Komponenten"""
        try:
            # Konfiguration laden
            self.config = assistant.AppConfig()
            
            # Mac-Controller initialisieren
            self.mac_controller = mac_control.MacController()
            
            # KI-Service initialisieren
            self.ai_service = ai_service.AIService(self.config)
            
            # Voice Manager initialisieren
            if self.config.voice_enabled:
                self.voice_manager = voice.VoiceManager(self.ai_service)
            
            # Screen Manager initialisieren
            if self.config.screen_analysis_enabled:
                self.screen_manager = screen.ScreenManager(self.ai_service)
            
            # Hauptassistent initialisieren
            self.assistant = assistant.Assistant(
                ai_service=self.ai_service,
                mac_controller=self.mac_controller,
                voice_manager=self.voice_manager,
                screen_manager=self.screen_manager,
                config=self.config
            )
            
            logger.info("Alle Komponenten erfolgreich initialisiert")
            return True
        
        except Exception as e:
            logger.error(f"Fehler bei der Initialisierung: {e}")
            return False
    
    def start_assistant(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Startet den Assistenten"""
        try:
            self.assistant.start()
            
            # Ereignisbehandlungen in separaten Threads starten
            threading.Thread(target=self.monitor_screen_analysis, daemon=True).start()
            threading.Thread(target=self.monitor_speech_commands, daemon=True).start()
            
            return {"success": True, "message": "Assistent erfolgreich gestartet"}
        
        except Exception as e:
            logger.error(f"Fehler beim Starten des Assistenten: {e}")
            return {"success": False, "message": str(e)}
    
    def stop_assistant(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Stoppt den Assistenten"""
        try:
            self.assistant.stop()
            return {"success": True, "message": "Assistent erfolgreich gestoppt"}
        
        except Exception as e:
            logger.error(f"Fehler beim Stoppen des Assistenten: {e}")
            return {"success": False, "message": str(e)}
    
    def process_query(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Verarbeitet eine Anfrage"""
        try:
            query = params.get("query", "")
            if not query:
                return {"success": False, "message": "Keine Anfrage angegeben"}
            
            # Anfrage verarbeiten
            response = self.assistant.process_direct_query(query)
            
            return {"success": True, "response": response}
        
        except Exception as e:
            logger.error(f"Fehler beim Verarbeiten der Anfrage: {e}")
            return {"success": False, "message": str(e)}
    
    def update_config(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Aktualisiert die Konfiguration"""
        try:
            # Konfiguration aktualisieren
            if "api_model" in params:
                self.config.ai_model = params["api_model"]
            
            if "voice_enabled" in params:
                self.config.voice_enabled = params["voice_enabled"]
            
            if "screen_enabled" in params:
                self.config.screen_analysis_enabled = params["screen_enabled"]
            
            if "wake_word" in params:
                self.config.wake_word = params["wake_word"]
            
            # Voice und Screen Manager aktualisieren
            if self.config.voice_enabled and not self.voice_manager:
                self.voice_manager = voice.VoiceManager(self.ai_service)
                self.assistant.voice_manager = self.voice_manager
            
            if self.config.screen_analysis_enabled and not self.screen_manager:
                self.screen_manager = screen.ScreenManager(self.ai_service)
                self.assistant.screen_manager = self.screen_manager
            
            return {"success": True, "message": "Konfiguration erfolgreich aktualisiert"}
        
        except Exception as e:
            logger.error(f"Fehler beim Aktualisieren der Konfiguration: {e}")
            return {"success": False, "message": str(e)}
    
    def analyze_image(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Analysiert ein Bild"""
        try:
            image_path = params.get("image_path", "")
            if not image_path or not os.path.exists(image_path):
                return {"success": False, "message": "Ungültiger Bildpfad"}
            
            analysis = self.ai_service.analyze_image(image_path)
            
            return {"success": True, "analysis": analysis}
        
        except Exception as e:
            logger.error(f"Fehler bei der Bildanalyse: {e}")
            return {"success": False, "message": str(e)}
    
    def execute_action(self, params: Dict[str, Any]) -> Dict[str, Any]:
        """Führt eine Aktion aus"""
        try:
            action = params.get("action", "")
            action_params = params.get("parameters", {})
            
            if not action:
                return {"success": False, "message": "Keine Aktion angegeben"}
            
            # Aktion ausführen
            if action == "open_app":
                success = self.mac_controller.open_application(action_params.get("app_name", ""))
                return {"success": success, "message": "Anwendung geöffnet" if success else "Fehler beim Öffnen der Anwendung"}
            
            elif action == "close_app":
                success = self.mac_controller.close_application(action_params.get("app_name", ""))
                return {"success": success, "message": "Anwendung geschlossen" if success else "Fehler beim Schließen der Anwendung"}
            
            elif action == "type_text":
                success = self.mac_controller.type_text(action_params.get("text", ""))
                return {"success": success, "message": "Text eingegeben" if success else "Fehler bei der Texteingabe"}
            
            elif action == "take_screenshot":
                screenshot_path = self.mac_controller.take_screenshot()
                success = screenshot_path is not None
                return {"success": success, "path": screenshot_path, "message": "Screenshot erstellt" if success else "Fehler beim Erstellen des Screenshots"}
            
            else:
                return {"success": False, "message": f"Unbekannte Aktion: {action}"}
        
        except Exception as e:
            logger.error(f"Fehler bei der Ausführung der Aktion: {e}")
            return {"success": False, "message": str(e)}
    
    def monitor_screen_analysis(self):
        """Überwacht Bildschirmanalysen und sendet Ereignisse"""
        if not self.screen_manager:
            return
        
        try:
            while True:
                analysis = self.screen_manager.get_latest_analysis(timeout=1.0)
                if analysis:
                    # Analyseergebnis als JSON an Swift senden
                    self.send_event("screen_analysis", analysis["analysis"])
                
                time.sleep(0.5)
        
        except Exception as e:
            logger.error(f"Fehler bei der Bildschirmanalyse-Überwachung: {e}")
    
    def monitor_speech_commands(self):
        """Überwacht Sprachbefehle und sendet Ereignisse"""
        if not self.voice_manager:
            return
        
        try:
            while True:
                command = self.voice_manager.get_next_command(timeout=1.0)
                if command:
                    # Sprachbefehl als JSON an Swift senden
                    self.send_event("speech_command", command)
                
                time.sleep(0.5)
        
        except Exception as e:
            logger.error(f"Fehler bei der Sprachbefehl-Überwachung: {e}")
    
    def send_event(self, event_type: str, content: Any):
        """Sendet ein Ereignis als JSON an Swift"""
        event = {
            "type": event_type,
            "content": content,
            "timestamp": time.time()
        }
        
        json_event = json.dumps(event)
        print(json_event, flush=True)

# Hauptfunktion
def main():
    """Hauptfunktion des Python-Bridge-Skripts"""
    try:
        bridge = Bridge()
        logger.info("Bridge gestartet, warte auf Befehle...")
        
        # Auf Befehle von Swift warten
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            
            try:
                # JSON-Befehl parsen
                command = json.loads(line)
                command_type = command.get("command", "")
                params = command.get("params", {})
                
                # Befehl verarbeiten
                result = None
                
                if command_type == "start_assistant":
                    result = bridge.start_assistant(params)
                
                elif command_type == "stop_assistant":
                    result = bridge.stop_assistant(params)
                
                elif command_type == "process_query":
                    result = bridge.process_query(params)
                
                elif command_type == "update_config":
                    result = bridge.update_config(params)
                
                elif command_type == "analyze_image":
                    result = bridge.analyze_image(params)
                
                elif command_type == "execute_action":
                    result = bridge.execute_action(params)
                
                else:
                    result = {"success": False, "message": f"Unbekannter Befehl: {command_type}"}
                
                # Ergebnis als JSON zurücksenden
                result["command"] = command_type
                print(json.dumps(result), flush=True)
                
            except json.JSONDecodeError:
                logger.error(f"Ungültiger JSON-Befehl: {line}")
                print(json.dumps({"success": False, "message": "Ungültiger JSON-Befehl"}), flush=True)
            
            except Exception as e:
                logger.error(f"Fehler bei der Befehlsverarbeitung: {e}")
                print(json.dumps({"success": False, "message": str(e)}), flush=True)
    
    except Exception as e:
        logger.error(f"Kritischer Fehler in der Bridge: {e}")
        sys.exit(1)

if __name__ == "__main__":
    logger.info("Python-Bridge wird gestartet...")
    main()
EOF

# Berechtigung für das Bridge-Skript setzen
chmod +x "${APP_DIR}/Contents/Resources/python/bridge.py"

# Symbole und Ressourcen kopieren
log_status "Symbole und Ressourcen kopieren..."
mkdir -p "${APP_DIR}/Contents/Resources/Assets.xcassets"
cp -R "${RESOURCES_DIR}/icons" "${APP_DIR}/Contents/Resources/"

# DMG-Hintergrund vorbereiten
log_status "DMG-Hintergrund vorbereiten..."
mkdir -p "${DMG_DIR}/.background"
cp "${RESOURCES_DIR}/dmg_background.png" "${DMG_DIR}/.background/background.png"

# Symbolischen Link zum Programme-Ordner im DMG erstellen
ln -s /Applications "${DMG_DIR}/Applications"

# App ins DMG-Verzeichnis kopieren
cp -R "${APP_DIR}" "${DMG_DIR}/"

# DMG erstellen
log_status "DMG-Datei erstellen..."
create-dmg \
    --volname "${APP_NAME}" \
    --volicon "${RESOURCES_DIR}/icons/AppIcon.icns" \
    --background "${DMG_DIR}/.background/background.png" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 200 190 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 600 185 \
    "${DMG_FINAL}" \
    "${DMG_DIR}"

if [ $? -ne 0 ]; then
    log_error "DMG-Erstellung fehlgeschlagen."
    exit 1
fi

# Code-Signierung (in einer echten Implementierung würde hier der Code signiert werden)
log_status "Code-Signierung simulieren..."
# codesign --force --sign "Developer ID Application: Your Company (XXXXXXXXXX)" "${DMG_FINAL}"

# Erfolgsmeldung
log_success "DMG-Datei erfolgreich erstellt: ${DMG_FINAL}"
log_status "Größe: $(du -h "${DMG_FINAL}" | cut -f1)"

# Aufräumen
log_status "Aufräumen..."
rm -rf "${DMG_DIR}"

exit 0