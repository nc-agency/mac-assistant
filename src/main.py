#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
main.py - Haupteinstiegspunkt für die Mac-Assistenten-App
Erstellt am: 2025-05-03
Änderungen:
- Initiale Implementierung des Hauptprogramms
- Integration von Umgebungsvariablen
- Setup der Assistenten-Komponenten
"""

import os
import sys
import time
import signal
import logging
from dotenv import load_dotenv

# Lokale Imports
from config import AppConfig
from assistant import Assistant
from voice import VoiceManager
from screen import ScreenManager
from mac_control import MacController
from ai_service import AIService

# Logging Setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(os.path.join(os.path.dirname(os.path.dirname(__file__)), 'app.log'))
    ]
)
logger = logging.getLogger("MacAssistant")

def signal_handler(sig, frame):
    """Sauberes Beenden bei SIGINT (Ctrl+C)"""
    logger.info("Beenden des Assistenten...")
    sys.exit(0)

def main():
    """Hauptfunktion der Anwendung"""
    # Banner anzeigen
    print("\n" + "="*50)
    print("Mac Assistent - Dein persönlicher KI-Assistent")
    print("="*50 + "\n")
    
    # Umgebungsvariablen laden
    env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), '.env')
    if os.path.exists(env_path):
        load_dotenv(env_path)
        logger.info("Umgebungsvariablen aus .env geladen")
    else:
        logger.warning("Keine .env-Datei gefunden. Verwende Standardeinstellungen.")
    
    # Konfiguration initialisieren
    config = AppConfig()
    
    # Komponenten initialisieren
    try:
        # AI-Service initialisieren
        ai_service = AIService(config)
        
        # Mac-Controller initialisieren
        mac_controller = MacController()
        
        # Voice-Manager initialisieren falls aktiviert
        voice_manager = None
        if config.voice_enabled:
            voice_manager = VoiceManager(ai_service)
        
        # Screen-Manager initialisieren falls aktiviert
        screen_manager = None
        if config.screen_analysis_enabled:
            screen_manager = ScreenManager(ai_service)
        
        # Hauptassistent initialisieren
        assistant = Assistant(
            ai_service=ai_service,
            mac_controller=mac_controller,
            voice_manager=voice_manager,
            screen_manager=screen_manager,
            config=config
        )
        
        # Sauberes Beenden einrichten
        signal.signal(signal.SIGINT, signal_handler)
        
        # Assistent starten
        logger.info("Mac Assistent gestartet")
        assistant.start()
        
    except Exception as e:
        logger.error(f"Fehler beim Starten des Assistenten: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
