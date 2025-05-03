#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
assistant.py - Hauptassistentenmodul für die Mac-Assistenten-App
Erstellt am: 2025-05-03
Änderungen:
- Initiale Implementierung des Assistentenmoduls
- Integration aller Komponenten
"""

import os
import logging
import threading
import time
from typing import Optional, Dict, Any

# Lokale Imports
from config import AppConfig
from ai_service import AIService
from voice import VoiceManager
from screen import ScreenManager
from mac_control import MacController

logger = logging.getLogger("MacAssistant.Assistant")

class Assistant:
    """Hauptassistentenklasse, die alle Komponenten koordiniert"""
    
    def __init__(
        self,
        ai_service: AIService,
        mac_controller: MacController,
        voice_manager: Optional[VoiceManager] = None,
        screen_manager: Optional[ScreenManager] = None,
        config: Optional[AppConfig] = None
    ):
        """
        Initialisiert den Assistenten
        
        Args:
            ai_service: Instanz des AI-Service
            mac_controller: Instanz des Mac-Controllers
            voice_manager: Optional, Instanz des Voice-Managers
            screen_manager: Optional, Instanz des Screen-Managers
            config: Optional, Instanz der Konfiguration
        """
        self.ai_service = ai_service
        self.mac_controller = mac_controller
        self.voice_manager = voice_manager
        self.screen_manager = screen_manager
        self.config = config or AppConfig()
        
        self.running = False
        self.main_thread = None
        self.stop_event = threading.Event()
        
        # Statusvariablen
        self.last_screen_analysis = None
        self.last_command = None
        
        logger.info("Assistent initialisiert")
    
    def start(self):
        """Startet den Assistenten"""
        if self.running:
            logger.warning("Assistent läuft bereits")
            return
        
        self.running = True
        self.stop_event.clear()
        
        # Komponenten starten
        if self.voice_manager:
            self.voice_manager.start_listening()
        
        if self.screen_manager:
            self.screen_manager.start_analysis()
        
        # Hauptschleife starten
        self.main_thread = threading.Thread(target=self._main_loop)
        self.main_thread.daemon = True
        self.main_thread.start()
        
        # Willkommensnachricht
        if self.voice_manager:
            self.voice_manager.speak("Hallo! Ich bin dein Mac-Assistent. Wie kann ich dir helfen?")
        
        logger.info("Assistent gestartet")
    
    def stop(self):
        """Stoppt den Assistenten"""
        if not self.running:
            logger.warning("Assistent läuft nicht")
            return
        
        self.running = False
        self.stop_event.set()
        
        # Komponenten stoppen
        if self.voice_manager:
            self.voice_manager.stop_listening()
        
        if self.screen_manager:
            self.screen_manager.stop_analysis()
        
        # Auf Hauptthread warten
        if self.main_thread:
            self.main_thread.join(timeout=2.0)
        
        logger.info("Assistent gestoppt")
    
    def _main_loop(self):
        """Hauptschleife des Assistenten"""
        logger.info("Hauptschleife gestartet")
        
        while not self.stop_event.is_set():
            try:
                # Sprachbefehle verarbeiten, falls vorhanden
                if self.voice_manager:
                    command = self.voice_manager.get_next_command(block=False)
                    if command:
                        self._process_command(command)
                
                # Bildschirmanalyse verarbeiten, falls vorhanden und nicht zu alt
                if self.screen_manager:
                    analysis = self.screen_manager.get_latest_analysis(block=False)
                    if analysis and self._is_relevant_analysis(analysis):
                        self._process_screen_analysis(analysis)
                
                # Pause, um CPU-Last zu reduzieren
                time.sleep(0.1)
                
            except Exception as e:
                logger.error(f"Fehler in der Hauptschleife: {e}")
                time.sleep(1)  # Pause bei Fehler
    
    def _process_command(self, command: str):
        """
        Verarbeitet einen Sprachbefehl
        
        Args:
            command: Der Sprachbefehl
        """
        logger.info(f"Verarbeite Befehl: {command}")
        self.last_command = command
        
        # Bildschirmkontext abrufen, falls verfügbar
        screen_context = None
        if self.last_screen_analysis and self._is_relevant_analysis(self.last_screen_analysis):
            screen_context = self.last_screen_analysis['analysis']
        
        # Befehl an AI-Service senden
        response = self.ai_service.process_query(command, screen_content=screen_context)
        
        # Aktionen basierend auf der Antwort ausführen
        self._execute_actions(response)
        
        # Antwort vorlesen
        if self.voice_manager:
            self.voice_manager.speak(response)
    
    def _process_screen_analysis(self, analysis: Dict[str, Any]):
        """
        Verarbeitet eine Bildschirmanalyse
        
        Args:
            analysis: Die Bildschirmanalyse
        """
        logger.debug(f"Neue Bildschirmanalyse erhalten: {analysis['timestamp']}")
        self.last_screen_analysis = analysis
        
        # Hier könnten wir proaktive Aktionen basierend auf dem Bildschirminhalt ausführen
        # z.B. Erkennen von Popups, Fehlermeldungen usw.
        # Vorerst speichern wir nur die Analyse für spätere Verwendung
    
    def _is_relevant_analysis(self, analysis: Dict[str, Any]) -> bool:
        """
        Prüft, ob eine Bildschirmanalyse noch relevant ist
        
        Args:
            analysis: Die zu prüfende Analyse
            
        Returns:
            True wenn relevant, False wenn veraltet
        """
        # Prüfen, ob die Analyse nicht älter als 30 Sekunden ist
        current_time = time.time()
        analysis_time = analysis['timestamp']
        return (current_time - analysis_time) <= 30
    
    def _execute_actions(self, response: str):
        """
        Führt Aktionen basierend auf der KI-Antwort aus
        
        Args:
            response: Die KI-Antwort
        """
        # Einfache Befehlserkennung basierend auf Schlüsselwörtern
        response_lower = response.lower()
        
        # Anwendungen öffnen
        if "öffne " in response_lower:
            app_name = self._extract_app_name(response, "öffne ")
            if app_name:
                self.mac_controller.open_application(app_name)
        
        # Anwendungen schließen
        elif "schließe " in response_lower:
            app_name = self._extract_app_name(response, "schließe ")
            if app_name:
                self.mac_controller.close_application(app_name)
        
        # Text eingeben
        elif "tippe " in response_lower:
            text = self._extract_text(response, "tippe ")
            if text:
                self.mac_controller.type_text(text)
        
        # Screenshot erstellen
        elif "screenshot" in response_lower or "bildschirmfoto" in response_lower:
            self.mac_controller.take_screenshot()
        
        # Hinweis: In einer vollständigen Implementierung würden wir einen 
        # komplexeren NLU-Ansatz verwenden oder die Aktionserkennung an den AI-Service delegieren
    
    def _extract_app_name(self, text: str, keyword: str) -> Optional[str]:
        """Extrahiert einen App-Namen aus einem Text"""
        try:
            start_index = text.lower().find(keyword) + len(keyword)
            end_index = text.find(".", start_index)
            
            if end_index == -1:
                end_index = text.find(",", start_index)
            
            if end_index == -1:
                end_index = len(text)
            
            app_name = text[start_index:end_index].strip()
            return app_name if app_name else None
        except Exception:
            return None
    
    def _extract_text(self, text: str, keyword: str) -> Optional[str]:
        """Extrahiert einen Text nach einem Schlüsselwort"""
        try:
            start_index = text.lower().find(keyword) + len(keyword)
            end_index = text.find(".", start_index)
            
            if end_index == -1:
                end_index = len(text)
            
            extracted_text = text[start_index:end_index].strip()
            return extracted_text if extracted_text else None
        except Exception:
            return None
            
    def process_direct_query(self, query: str) -> str:
        """
        Verarbeitet eine direkte Textanfrage (z.B. von einer CLI)
        
        Args:
            query: Die Textanfrage
            
        Returns:
            Die Antwort des Assistenten
        """
        # Bildschirmkontext abrufen, falls verfügbar
        screen_context = None
        if self.last_screen_analysis and self._is_relevant_analysis(self.last_screen_analysis):
            screen_context = self.last_screen_analysis['analysis']
        
        # Anfrage an AI-Service senden
        response = self.ai_service.process_query(query, screen_content=screen_context)
        
        # Aktionen basierend auf der Antwort ausführen
        self._execute_actions(response)
        
        return response
