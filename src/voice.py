#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
voice.py - Spracherkennungs- und Sprachsynthesemodul für die Mac-Assistenten-App
Erstellt am: 2025-05-03
Änderungen:
- Initiale Implementierung des Sprachmoduls
- Integration mit SpeechRecognition und pyttsx3
"""

import os
import logging
import threading
import time
from typing import Optional, Callable, List, Dict
import queue

# Spracherkennung
import speech_recognition as sr

# Sprachsynthese
import pyttsx3

# Lokale Imports
from ai_service import AIService

logger = logging.getLogger("MacAssistant.VoiceManager")

class VoiceManager:
    """Klasse zur Verarbeitung von Sprache (Erkennung und Synthese)"""
    
    def __init__(self, ai_service: AIService):
        """
        Initialisiert den Voice Manager
        
        Args:
            ai_service: Instanz des AI-Service
        """
        self.ai_service = ai_service
        self.config = ai_service.config
        
        # Spracherkennung initialisieren
        self.recognizer = sr.Recognizer()
        self.recognizer.energy_threshold = 300  # Anpassbar an Umgebungsgeräusche
        self.recognizer.dynamic_energy_threshold = True
        self.recognizer.pause_threshold = 0.8
        
        # Mikrofon initialisieren
        self.microphone = sr.Microphone()
        
        # Sprachsynthese initialisieren
        self.engine = pyttsx3.init()
        self.engine.setProperty('rate', self.config.voice_rate)
        self.engine.setProperty('volume', self.config.voice_volume)
        
        # Verfügbare Stimmen anzeigen und deutsche Stimme auswählen
        voices = self.engine.getProperty('voices')
        for voice in voices:
            if self.config.voice_language in voice.languages:
                self.engine.setProperty('voice', voice.id)
                logger.info(f"Sprachstimme eingestellt auf: {voice.name}")
                break
        
        # Zuhör-Flagge
        self.is_listening = False
        self.wake_word = self.config.wake_word.lower()
        
        # Thread für kontinuierliches Zuhören
        self.listen_thread = None
        self.stop_listening = threading.Event()
        
        # Sprachbefehlswarteschlange
        self.command_queue = queue.Queue()
        
        logger.info("Voice Manager initialisiert")
    
    def start_listening(self):
        """Startet das kontinuierliche Zuhören im Hintergrund"""
        if self.listen_thread and self.listen_thread.is_alive():
            logger.warning("Zuhören läuft bereits")
            return
        
        self.stop_listening.clear()
        self.is_listening = True
        self.listen_thread = threading.Thread(target=self._listen_continuously)
        self.listen_thread.daemon = True
        self.listen_thread.start()
        logger.info("Zuhören gestartet")
    
    def stop_listening(self):
        """Stoppt das kontinuierliche Zuhören"""
        if not self.listen_thread or not self.listen_thread.is_alive():
            logger.warning("Zuhören läuft nicht")
            return
        
        self.stop_listening.set()
        self.is_listening = False
        self.listen_thread.join(timeout=2.0)
        logger.info("Zuhören gestoppt")
    
    def _listen_continuously(self):
        """Hört kontinuierlich auf Sprachbefehle (wird als Thread ausgeführt)"""
        logger.info("Kontinuierliches Zuhören gestartet")
        
        with self.microphone as source:
            # Einmal an Umgebungsgeräusche anpassen
            logger.info("Anpassung an Umgebungsgeräusche...")
            self.recognizer.adjust_for_ambient_noise(source, duration=1)
            
            while not self.stop_listening.is_set():
                try:
                    logger.debug("Höre auf Audioeingabe...")
                    audio = self.recognizer.listen(source, timeout=1.0, phrase_time_limit=10.0)
                    
                    try:
                        # Spracherkennung mit Google (erfordert Internetverbindung)
                        text = self.recognizer.recognize_google(
                            audio, 
                            language=self.config.voice_language
                        ).lower()
                        
                        logger.debug(f"Erkannter Text: {text}")
                        
                        # Prüfen auf das Aufweckwort
                        if self.wake_word in text:
                            # Signal ausgeben, dass wir zuhören
                            self.speak("Ja, ich höre zu.")
                            
                            # Nach dem Aufweckwort noch einmal zuhören für den eigentlichen Befehl
                            try:
                                logger.info("Warte auf Befehl...")
                                command_audio = self.recognizer.listen(
                                    source, 
                                    timeout=5.0,
                                    phrase_time_limit=15.0
                                )
                                
                                command = self.recognizer.recognize_google(
                                    command_audio,
                                    language=self.config.voice_language
                                )
                                
                                logger.info(f"Befehl erkannt: {command}")
                                
                                # Befehl in die Warteschlange stellen
                                self.command_queue.put(command)
                                
                            except sr.WaitTimeoutError:
                                self.speak("Ich habe keinen Befehl gehört.")
                            except sr.UnknownValueError:
                                self.speak("Ich konnte den Befehl nicht verstehen.")
                            except Exception as e:
                                logger.error(f"Fehler bei der Befehlserkennung: {e}")
                                self.speak("Es ist ein Fehler aufgetreten.")
                    
                    except sr.UnknownValueError:
                        # Keine erkennbare Sprache
                        pass
                    except sr.RequestError as e:
                        logger.error(f"Fehler bei der Spracherkennung: {e}")
                    
                except sr.WaitTimeoutError:
                    # Timeout ist normal, einfach weitermachen
                    pass
                except Exception as e:
                    logger.error(f"Fehler beim kontinuierlichen Zuhören: {e}")
                    time.sleep(1)  # Kurze Pause, um eine Schleife bei anhaltenden Fehlern zu vermeiden
    
    def listen_once(self, timeout: Optional[int] = None) -> Optional[str]:
        """
        Hört einmal auf einen Sprachbefehl
        
        Args:
            timeout: Optionaler Timeout in Sekunden
            
        Returns:
            Erkannter Text oder None
        """
        with self.microphone as source:
            try:
                logger.info("Höre auf einmalige Audioeingabe...")
                self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                
                audio = self.recognizer.listen(source, timeout=timeout)
                
                try:
                    text = self.recognizer.recognize_google(
                        audio, 
                        language=self.config.voice_language
                    )
                    logger.info(f"Erkannter Text: {text}")
                    return text
                except sr.UnknownValueError:
                    logger.warning("Keine erkennbare Sprache")
                    return None
                except sr.RequestError as e:
                    logger.error(f"Fehler bei der Spracherkennung-API: {e}")
                    return None
                    
            except Exception as e:
                logger.error(f"Fehler beim einmaligen Zuhören: {e}")
                return None
    
    def speak(self, text: str):
        """
        Gibt Text als Sprache aus
        
        Args:
            text: Auszugebender Text
        """
        try:
            logger.info(f"Spreche: {text}")
            self.engine.say(text)
            self.engine.runAndWait()
        except Exception as e:
            logger.error(f"Fehler bei der Sprachausgabe: {e}")
    
    def get_next_command(self, block: bool = True, timeout: Optional[float] = None) -> Optional[str]:
        """
        Holt den nächsten Sprachbefehl aus der Warteschlange
        
        Args:
            block: Blockierender Modus
            timeout: Timeout in Sekunden (nur im blockierenden Modus)
            
        Returns:
            Sprachbefehl oder None bei Timeout/leerem Queue
        """
        try:
            return self.command_queue.get(block=block, timeout=timeout)
        except queue.Empty:
            return None
    
    def process_speech_commands(self, callback: Callable[[str], None]):
        """
        Verarbeitet Sprachbefehle kontinuierlich und ruft Callback für jeden Befehl auf
        
        Args:
            callback: Funktion, die für jeden erkannten Befehl aufgerufen wird
        """
        self.start_listening()
        
        try:
            while self.is_listening:
                command = self.get_next_command(timeout=0.1)
                if command:
                    callback(command)
                time.sleep(0.1)
        except KeyboardInterrupt:
            self.stop_listening()
        finally:
            self.stop_listening()
