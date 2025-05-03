# Mac Assistant

Eine KI-basierte Assistenten-App, die deinen Mac steuert, mit dir spricht und Aufgaben für dich erledigt.

## Features

- Spracherkennung und -steuerung
- Bildschirmerkennung und -analyse
- Automatisierung von Mac-Funktionen
- Integration mit OpenAI und Google Gemini API
- Natürliche Konversation

## Installation

1. Klone dieses Repository
2. Installiere die Abhängigkeiten:
   ```
   pip install -r requirements.txt
   ```
3. Kopiere `.env.example` zu `.env` und füge deine API-Schlüssel hinzu
4. Starte den Assistenten:
   ```
   python src/main.py
   ```

## Konfiguration

In der `.env`-Datei müssen folgende Werte konfiguriert werden:

```
OPENAI_API_KEY=your_openai_api_key
GEMINI_API_KEY=your_gemini_api_key
```

## Berechtigungen

Die App benötigt folgende Berechtigungen:
- Mikrofonzugriff
- Bildschirmaufnahme
- Steuerung des Computers

Diese Berechtigungen müssen beim ersten Start in den macOS-Systemeinstellungen erteilt werden.
