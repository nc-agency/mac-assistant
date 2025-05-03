#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
config.py - Konfigurationsmodul für die Mac-Assistenten-App
Erstellt am: 2025-05-03
Änderungen:
- Initiale Implementierung der Konfigurationsklasse
- Integration von Umgebungsvariablen
"""

import os
import logging
from typing import Optional

logger = logging.getLogger("MacAssistant.Config")

class AppConfig:
    """Konfigurationsklasse für die Anwendung"""
    
    def __init__(self):
        # API Keys
        self.openai_api_key: Optional[str] = os.getenv("OPENAI_API_KEY")
        self.gemini_api_key: Optional[str] = os.getenv("GEMINI_API_KEY")
        
        # Funktionseinstellungen
        self.voice_enabled: bool = self._parse_bool(os.getenv("VOICE_ENABLED", "true"))
        self.screen_analysis_enabled: bool = self._parse_bool(os.getenv("SCREEN_ANALYSIS_ENABLED", "true"))
        
        # Validierung durchführen
        self._validate_config()
        
        # Sprach-Einstellungen
        self.voice_language: str = os.getenv("VOICE_LANGUAGE", "de-DE")
        self.voice_rate: int = int(os.getenv("VOICE_RATE", "175"))
        self.voice_volume: float = float(os.getenv("VOICE_VOLUME", "1.0"))
        
        # KI-Modell-Einstellungen
        self.ai_model: str = os.getenv("AI_MODEL", "openai")  # 'openai' oder 'gemini'
        self.openai_model: str = os.getenv("OPENAI_MODEL", "gpt-4")
        self.gemini_model: str = os.getenv("GEMINI_MODEL", "gemini-pro")
        
        # Anwendungseinstellungen
        self.wake_word: str = os.getenv("WAKE_WORD", "Assistent")
        self.response_timeout: int = int(os.getenv("RESPONSE_TIMEOUT", "10"))
        self.screen_capture_interval: int = int(os.getenv("SCREEN_CAPTURE_INTERVAL", "5"))  # Sekunden
    
    def _parse_bool(self, value: Optional[str]) -> bool:
        """String in Boolean konvertieren"""
        if value is None:
            return False
        return value.lower() in ("yes", "true", "t", "1")
    
    def _validate_config(self):
        """Konfiguration validieren"""
        # Überprüfen, ob mindestens ein AI-Service aktiviert ist
        if self.ai_model == "openai" and not self.openai_api_key:
            logger.warning("OpenAI API-Key fehlt, aber OpenAI ist als AI-Modell konfiguriert")
        
        if self.ai_model == "gemini" and not self.gemini_api_key:
            logger.warning("Gemini API-Key fehlt, aber Gemini ist als AI-Modell konfiguriert")
            
        # Warnen, wenn weder Sprach- noch Bildschirmanalyse aktiviert ist
        if not self.voice_enabled and not self.screen_analysis_enabled:
            logger.warning("Weder Spracherkennung noch Bildschirmanalyse sind aktiviert. " 
                           "Der Assistent hat eingeschränkte Funktionalität.")
    
    def __str__(self) -> str:
        """String-Repräsentation der Konfiguration (ohne API Keys)"""
        return (
            f"AppConfig(voice_enabled={self.voice_enabled}, "
            f"screen_analysis_enabled={self.screen_analysis_enabled}, "
            f"ai_model={self.ai_model}, "
            f"wake_word='{self.wake_word}')"
        )
