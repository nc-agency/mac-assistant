#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ai_service.py - KI-Service für die Mac-Assistenten-App
Erstellt am: 2025-05-03
Änderungen:
- Initiale Implementierung des AI-Service-Moduls
- Integration mit OpenAI und Google Gemini APIs
"""

import os
import logging
import json
from typing import Dict, List, Any, Optional, Union
import time

# OpenAI-API-Integration
import openai

# Google Gemini-API-Integration
try:
    import google.generativeai as genai
except ImportError:
    genai = None

# Lokale Imports
from config import AppConfig

logger = logging.getLogger("MacAssistant.AIService")

class AIService:
    """Klasse zum Interagieren mit KI-APIs"""
    
    def __init__(self, config: AppConfig):
        self.config = config
        
        # Initialisiere OpenAI, wenn konfiguriert
        if config.openai_api_key:
            openai.api_key = config.openai_api_key
            logger.info("OpenAI initialisiert")
        else:
            logger.warning("OpenAI-API-Key fehlt, OpenAI wird nicht verfügbar sein")
        
        # Initialisiere Gemini, wenn konfiguriert
        if config.gemini_api_key and genai:
            genai.configure(api_key=config.gemini_api_key)
            logger.info("Google Gemini initialisiert")
        elif config.gemini_api_key and not genai:
            logger.warning("Google Gemini Modul nicht gefunden. 'pip install google-generativeai' ausführen")
        elif not config.gemini_api_key and genai:
            logger.warning("Gemini-API-Key fehlt, Gemini wird nicht verfügbar sein")
        
        # System-Prompt
        self.system_prompt = """
        Du bist ein hilfreicher Mac-Assistent. Deine Aufgabe ist es, dem Benutzer bei der Steuerung 
        seines Mac-Computers zu helfen und Aufgaben auszuführen. Du kannst auf den Bildschirm sehen,
        Spracheingaben verstehen und den Computer steuern.
        
        Beantworte Fragen klar und präzise. Wenn du eine Aktion ausführen sollst, bestätige
        was du tun wirst und führe sie dann aus. Bei Unklarheiten frage nach.
        
        Verfügbare Befehle:
        - Öffne [App-Name] - Öffnet eine Anwendung
        - Suche [Suchbegriff] - Führt eine Suche durch
        - Klicke auf [Element] - Klickt auf ein sichtbares Element
        - Tippe [Text] - Gibt Text ein
        - Schließe [App-Name] - Schließt eine Anwendung
        """
        
        # Konversationsverlauf für Kontext
        self.conversation_history: List[Dict[str, str]] = [
            {"role": "system", "content": self.system_prompt}
        ]
    
    def process_query(self, 
                      query: str, 
                      screen_content: Optional[str] = None,
                      context: Optional[Dict[str, Any]] = None) -> str:
        """
        Verarbeitet eine Benutzeranfrage und gibt eine Antwort zurück
        
        Args:
            query: Die Benutzeranfrage
            screen_content: Optional, Text/Beschreibung des aktuellen Bildschirminhalts
            context: Optional, zusätzlicher Kontext
            
        Returns:
            Die Antwort des KI-Assistenten
        """
        current_model = self.config.ai_model
        
        # Aktualisiere den Konversationsverlauf
        if screen_content:
            self.conversation_history.append({
                "role": "system", 
                "content": f"Aktueller Bildschirminhalt: {screen_content}"
            })
        
        self.conversation_history.append({"role": "user", "content": query})
        
        # Verarbeite mit dem konfigurierten Modell
        try:
            if current_model == "openai" and self.config.openai_api_key:
                return self._process_with_openai()
            elif current_model == "gemini" and self.config.gemini_api_key and genai:
                return self._process_with_gemini()
            else:
                logger.error(f"Modell {current_model} ist nicht verfügbar oder konfiguriert")
                return "Entschuldigung, das konfigurierte KI-Modell ist derzeit nicht verfügbar."
        except Exception as e:
            logger.error(f"Fehler bei der Verarbeitung mit {current_model}: {e}")
            return f"Es ist ein Fehler aufgetreten: {str(e)}"
    
    def _process_with_openai(self) -> str:
        """Verarbeitet die Anfrage mit OpenAI API"""
        try:
            response = openai.ChatCompletion.create(
                model=self.config.openai_model,
                messages=self.conversation_history,
                max_tokens=500,
                temperature=0.7
            )
            
            # Antwort extrahieren
            reply = response.choices[0].message.content
            
            # Antwort zum Verlauf hinzufügen
            self.conversation_history.append({"role": "assistant", "content": reply})
            
            return reply
        except Exception as e:
            logger.error(f"OpenAI API Fehler: {e}")
            return f"OpenAI API-Fehler: {str(e)}"
    
    def _process_with_gemini(self) -> str:
        """Verarbeitet die Anfrage mit Google Gemini API"""
        try:
            # Gemini verwendet ein anderes Format, also konvertieren
            gemini_messages = []
            for msg in self.conversation_history:
                if msg["role"] == "system":
                    # Für Gemini fügen wir System-Nachrichten dem ersten User hinzu
                    # oder erstellen eine neue User-Nachricht
                    role = "user"
                else:
                    role = msg["role"]
                
                gemini_messages.append({"role": role, "parts": [msg["content"]]})
            
            # Gemini-Modell erstellen und Anfrage senden
            model = genai.GenerativeModel(self.config.gemini_model)
            response = model.generate_content(gemini_messages)
            
            # Antwort extrahieren
            reply = response.text
            
            # Antwort zum Verlauf hinzufügen
            self.conversation_history.append({"role": "assistant", "content": reply})
            
            return reply
        except Exception as e:
            logger.error(f"Gemini API Fehler: {e}")
            return f"Gemini API-Fehler: {str(e)}"
            
    def analyze_image(self, image_path: str) -> str:
        """
        Analysiert ein Bild (Screenshot) mit Vision-Fähigkeiten
        
        Args:
            image_path: Pfad zum Bild
            
        Returns:
            Textbeschreibung des Bildes
        """
        try:
            if self.config.ai_model == "openai" and self.config.openai_api_key:
                return self._analyze_image_with_openai(image_path)
            elif self.config.ai_model == "gemini" and self.config.gemini_api_key:
                return self._analyze_image_with_gemini(image_path)
            else:
                return "Bildanalyse ist mit dem aktuellen Modell nicht verfügbar."
        except Exception as e:
            logger.error(f"Fehler bei der Bildanalyse: {e}")
            return f"Fehler bei der Bildanalyse: {str(e)}"
    
    def _analyze_image_with_openai(self, image_path: str) -> str:
        """Analysiert ein Bild mit OpenAI Vision-Fähigkeiten"""
        try:
            import base64
            
            # Bild als base64 kodieren
            with open(image_path, "rb") as image_file:
                base64_image = base64.b64encode(image_file.read()).decode('utf-8')
            
            # Analyse mit Vision-Modell
            response = openai.ChatCompletion.create(
                model="gpt-4-vision-preview",
                messages=[
                    {
                        "role": "system",
                        "content": "Beschreibe den Inhalt dieses Screenshots im Detail. "
                                   "Achte besonders auf sichtbare UI-Elemente, geöffnete Anwendungen und Text."
                    },
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "Was siehst du auf diesem Screenshot?"},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/png;base64,{base64_image}"
                                }
                            }
                        ]
                    }
                ],
                max_tokens=500
            )
            
            return response.choices[0].message.content
        except Exception as e:
            logger.error(f"OpenAI Vision API Fehler: {e}")
            return f"Fehler bei der Bildanalyse mit OpenAI: {str(e)}"
    
    def _analyze_image_with_gemini(self, image_path: str) -> str:
        """Analysiert ein Bild mit Gemini Pro Vision-Fähigkeiten"""
        try:
            # Bildanalyse-Modell laden
            model = genai.GenerativeModel('gemini-pro-vision')
            
            # Bild laden
            image = genai.types.Image.load_from_file(image_path)
            
            # Prompt definieren
            prompt = "Beschreibe den Inhalt dieses Screenshots im Detail. Achte besonders auf sichtbare UI-Elemente, geöffnete Anwendungen und Text."
            
            # Analyse durchführen
            result = model.generate_content([prompt, image])
            
            return result.text
        except Exception as e:
            logger.error(f"Gemini Vision API Fehler: {e}")
            return f"Fehler bei der Bildanalyse mit Gemini: {str(e)}"
