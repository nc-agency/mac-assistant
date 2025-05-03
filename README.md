# Mac Assistant

**Mac Assistant** ist ein revolutionärer persönlicher Assistent für macOS, der die Art und Weise, wie Benutzer mit ihrem Mac interagieren, grundlegend verändert.

## Funktionen

- **Sprachsteuerung**: Steuere deinen Mac mit natürlichen Sprachbefehlen
- **Kontextbewusstsein**: Der Assistent versteht, was auf deinem Bildschirm passiert
- **KI-Integration**: Nutzt fortschrittliche KI für intelligente Antworten und Aktionen
- **Nahtlose Integration**: Arbeitet perfekt mit macOS-Apps und -Funktionen zusammen
- **Workflow-Automatisierung**: Automatisiert komplexe Aufgaben mit einfachen Befehlen
- **Multi-Display-Unterstützung**: Funktioniert auf allen angeschlossenen Bildschirmen

## Installation

### Option 1: DMG-Installer

1. Lade die neueste DMG-Datei von der [Releases-Seite](https://github.com/nc-agency/mac-assistant/releases) herunter.
2. Öffne die DMG-Datei durch Doppelklick.
3. Ziehe die Mac Assistant-App in den Programme-Ordner.
4. Starte die App aus dem Programme-Ordner.
5. Bei der ersten Ausführung werden Berechtigungen für Mikrofon, Bildschirmaufnahme und Bedienungshilfen angefordert.

### Option 2: Manuelle Installation

Für Entwickler und fortgeschrittene Benutzer:

```bash
# Repository klonen
git clone https://github.com/nc-agency/mac-assistant.git
cd mac-assistant

# Abhängigkeiten installieren
pip install -r requirements.txt

# App aus dem Quellcode bauen
cd scripts
./create_app_icon.sh  # Icon erstellen
cd ..
xcodebuild -project xcode/MacAssistant/MacAssistant.xcodeproj -scheme MacAssistant -configuration Release

# DMG erstellen (optional)
cd scripts
./create_dmg.sh
```

## Entwicklungs-Setup

### Voraussetzungen

- macOS 10.15 (Catalina) oder höher
- Xcode 13.0 oder höher
- Python 3.8 oder höher
- Folgende Tools:
  - `create-dmg` (kann mit `brew install create-dmg` installiert werden)
  - Ein SVG-Konvertierungstool (Inkscape, librsvg oder ImageMagick)

### Projektstruktur

```
mac-assistant/
├── src/                    # Python-Backend
│   ├── main.py             # Haupteinstiegspunkt
│   ├── assistant.py        # Hauptassistenten-Klasse
│   ├── ai_service.py       # KI-Service (OpenAI, Gemini)
│   ├── mac_control.py      # Steuerung von macOS
│   ├── voice.py            # Spracherkennung und -synthese
│   ├── screen.py           # Bildschirmanalyse
│   └── config.py           # Konfigurationsmanagement
├── gui/                    # Swift-GUI-Prototyp
│   ├── MacAssistantApp.swift
│   ├── AssistantManager.swift
│   ├── PopoverView.swift
│   ├── SettingsView.swift
│   └── PythonBridge.swift
├── xcode/                  # Xcode-Projekt
│   └── MacAssistant/       # Hauptprojekt mit allen Ressourcen
├── resources/              # Ressourcen für die App
│   ├── icons/              # App-Icons
│   └── dmg_background.svg  # Hintergrund für DMG
├── scripts/                # Build-Skripte
│   ├── create_dmg.sh       # DMG-Erstellungsskript
│   ├── create_app_icon.sh  # Icon-Konvertierungsskript
│   └── convert_background.sh # Hintergrund-Konvertierungsskript
├── docs/                   # Dokumentation
│   └── dmg_creation_guide.md # Leitfaden zur DMG-Erstellung
└── requirements.txt        # Python-Abhängigkeiten
```

## DMG-Erstellung

Die App kann als DMG-Installationspaket verteilt werden. Details zur DMG-Erstellung finden sich in der [DMG-Erstellungsdokumentation](docs/dmg_creation_guide.md).

Kurzfassung:

1. Ressourcen generieren:
   ```bash
   cd scripts
   ./convert_background.sh  # DMG-Hintergrund erstellen
   ./create_app_icon.sh     # App-Icons erstellen
   ```

2. DMG erstellen:
   ```bash
   ./create_dmg.sh
   ```

3. Das fertige DMG befindet sich im `build`-Verzeichnis.

## Beitragende

Wir freuen uns über Beiträge! Bitte lies unsere [Beitragsrichtlinien](CONTRIBUTING.md), bevor du Pull Requests einreichst.

## Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe die [LIZENZ](LICENSE) Datei für Details.

## Kontakt

Bei Fragen oder Problemen wende dich bitte an [info.ncagency@gmail.com](mailto:info.ncagency@gmail.com).