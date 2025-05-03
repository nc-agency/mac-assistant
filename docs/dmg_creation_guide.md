# DMG-Erstellungsleitfaden für Mac-Assistenten
<!-- 
Erstellt am: 2025-05-04
Änderungen:
- Initiale Dokumentation für die DMG-Erstellung
- Detaillierte Anweisungen zum Bau des Installationspakets
-->

Dieser Leitfaden beschreibt den Prozess zur Erstellung des Mac-Assistenten-Installationspakets (DMG).

## Voraussetzungen

Bevor Sie mit der Erstellung des DMG-Pakets beginnen, stellen Sie sicher, dass folgende Voraussetzungen erfüllt sind:

1. **Entwicklungsumgebung**:
   - macOS 10.15 (Catalina) oder höher
   - Xcode 13.0 oder höher
   - Python 3.8 oder höher

2. **Benötigte Tools**:
   - `create-dmg` (kann mit `brew install create-dmg` installiert werden)
   - Ein Tool zum Konvertieren von SVG nach PNG (Inkscape, librsvg oder ImageMagick)

3. **Vorbereitungen**:
   - Gültiges Apple Developer-Zertifikat (für Code-Signierung)
   - Abgeschlossenes und erfolgreich gebautes Xcode-Projekt

## Verzeichnisstruktur

Die relevanten Dateien für die DMG-Erstellung befinden sich in folgenden Verzeichnissen:

```
mac-assistant/
├── scripts/
│   ├── create_dmg.sh          # Hauptskript für die DMG-Erstellung
│   └── convert_background.sh  # Hilfsskript zur Konvertierung des Hintergrundbilds
├── resources/
│   ├── dmg_background.svg     # Quell-SVG für den DMG-Hintergrund
│   ├── dmg_background.png     # Konvertiertes PNG für den DMG-Hintergrund
│   └── icons/                 # App-Symbole
└── xcode/                     # Xcode-Projektverzeichnis
```

## Schritt-für-Schritt-Anleitung

### 1. Vorbereitung der Ressourcen

Zunächst müssen die benötigten Ressourcen vorbereitet werden:

```bash
# Navigieren zum scripts-Verzeichnis
cd mac-assistant/scripts

# SVG-Hintergrundbild in PNG konvertieren
./convert_background.sh
```

### 2. Anpassen der Konfiguration (optional)

Für spezielle Anpassungen können Sie das Skript `create_dmg.sh` bearbeiten:

- Anpassen des Namens der DMG-Datei
- Ändern der Fenstergröße oder -position
- Anpassen der Icon-Positionen

### 3. Erstellen des DMG-Pakets

Um das DMG-Paket zu erstellen, führen Sie einfach das Hauptskript aus:

```bash
# Berechtigungen setzen (falls nötig)
chmod +x create_dmg.sh

# DMG erstellen
./create_dmg.sh
```

Das Skript führt folgende Schritte aus:

1. Kompilieren des Xcode-Projekts
2. Kopieren des Anwendungsbündels (.app)
3. Einbinden der Python-Umgebung
4. Erstellen der Python-Bridge
5. Vorbereiten des DMG-Layouts
6. Erzeugen der DMG-Datei
7. (Optional) Code-Signierung der DMG-Datei

### 4. Code-Signierung

Für die Distribution über den Mac App Store oder zur Vermeidung von Gatekeeper-Warnungen, müssen Sie die App signieren:

```bash
# Ersetzen Sie XXXXXXXXXX mit Ihrer Developer-ID
codesign --force --sign "Developer ID Application: Ihr Firmenname (XXXXXXXXXX)" \
    "../build/MacAssistant_Installer_X.Y.Z.dmg"
```

Diese Zeile ist bereits im Skript enthalten, aber als Kommentar. Entfernen Sie die Kommentarzeichen und passen Sie die ID an, um die App zu signieren.

### 5. Überprüfung

Nach Abschluss sollten Sie das erzeugte DMG überprüfen:
- Öffnen Sie die DMG-Datei durch Doppelklick
- Stellen Sie sicher, dass das Layout korrekt ist
- Testen Sie die Installation durch Ziehen der App in den Programme-Ordner
- Starten Sie die installierte App und prüfen Sie die Hauptfunktionen

## Fehlerbehebung

### Probleme bei der DMG-Erstellung

- **Fehler "create-dmg not found"**: Installieren Sie create-dmg mit `brew install create-dmg`
- **Konvertierungsfehler mit SVG**: Stellen Sie sicher, dass ein Konvertierungstool installiert ist
- **Xcode-Build fehlgeschlagen**: Überprüfen Sie das Xcode-Projekt auf Fehler und beheben Sie diese

### Probleme bei der Installation

- **Gatekeeper-Warnung**: App ist nicht korrekt signiert. Führen Sie die Code-Signierung durch.
- **App startet nicht**: Überprüfen Sie, ob alle Abhängigkeiten korrekt eingebettet sind
- **Python-Fehler**: Stellen Sie sicher, dass die Python-Umgebung korrekt konfiguriert ist

## Automatisierung

Dieser Prozess kann in eine CI/CD-Pipeline integriert werden, um automatisch DMG-Dateien zu erzeugen, wenn Code in bestimmte Branches gepusht wird. Hierfür ist eine angepasste Version des Skripts erforderlich, die keine Benutzerinteraktion erfordert.

---

Bei Fragen oder Problemen wenden Sie sich bitte an das Entwicklungsteam unter [info.ncagency@gmail.com](mailto:info.ncagency@gmail.com).