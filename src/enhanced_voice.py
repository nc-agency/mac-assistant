#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
enhanced_voice.py - Verbesserte Spracherkennung für Mac-Assistenten
Erstellt am: 2025-05-04
Änderungen:
- Initiale Implementierung der erweiterten Spracherkennung
- Integration mit lokaler Spracherkennung für Offline-Funktionen
- Implementierung verbesserter Wakeword-Erkennung
- Unterstützung für Deutsch und Englisch als Hauptsprachen
"""

import os
import time
import queue
import logging
import threading
import tempfile
import io
import wave
import json
from typing import Dict, List, Optional, Tuple, Any, Union, Callable
from datetime import datetime
import speech_recognition as sr
import pyttsx3
import numpy as np
from collections import deque

# PyAudio für Streaming-Audioverarbeitung
try:
    import pyaudio
    PYAUDIO_AVAILABLE = True
except ImportError:
    PYAUDIO_AVAILABLE = False
    logging.warning("PyAudio nicht verfügbar. Installation mit 'pip install pyaudio' empfohlen.")

# Pydub für Audio-Verarbeitung
try:
    from pydub import AudioSegment
    PYDUB_AVAILABLE = True
except ImportError:
    PYDUB_AVAILABLE = False
    logging.warning("Pydub nicht verfügbar. Installation mit 'pip install pydub' empfohlen.")

logger = logging.getLogger("MacAssistant.EnhancedVoiceManager")

class EnhancedVoiceManager:
    """Verbesserte Spracherkennung und -synthese für Mac-Assistenten"""
    
    def __init__(self, ai_service, config=None):
        """Initialisiert den Enhanced Voice Manager"""
        self.ai_service = ai_service
        self.config = config
        
        # Standardeinstellungen
        self.voice_language = config.voice_language if config else "de-DE"
        self.voice_rate = config.voice_rate if config else 175
        self.voice_volume = config.voice_volume if config else 1.0
        self.wake_word = config.wake_word.lower() if config else "assistent"
        
        # Spracherkennungsspezifische Einstellungen
        self.recognition_threshold = 0.5  # Erkennungsschwelle (0.0 bis 1.0)
        self.silence_threshold = 500  # Stille in Millisekunden zum Beenden einer Sprachaufnahme
        self.phrase_timeout = 5.0  # Maximale Dauer einer Phrase in Sekunden
        self.sample_rate = 16000  # Abtastrate in Hz
        self.offline_mode = False  # Offline-Modus (ohne API-Anfragen)
        
        # Unterstützte Sprachen
        self.supported_languages = {
            "de-DE": "Deutsch",
            "en-US": "Englisch (US)",
            "en-GB": "Englisch (UK)",
            "fr-FR": "Französisch",
            "es-ES": "Spanisch"
        }
        
        # Zustandsvariablen
        self.running = False
        self.listening_for_wake_word = False
        self.recording_command = False
        self.command_queue = queue.Queue()
        self.audio_buffer = deque(maxlen=int(self.sample_rate * 5))  # 5 Sekunden Buffer
        
        # Recognizer initialisieren
        self.recognizer = sr.Recognizer()
        self.recognizer.energy_threshold = 4000  # Empfindlichkeit anpassen
        self.recognizer.dynamic_energy_threshold = True
        self.recognizer.pause_threshold = 0.8  # Pause zwischen Wörtern
        
        # Text-to-Speech-Engine initialisieren
        self.init_tts_engine()
        
        # Thread für die kontinuierliche Spracherkennung
        self.recognition_thread = None
        
        logger.info("Enhanced Voice Manager initialisiert")
    
    def init_tts_engine(self):
        """Initialisiert die Text-to-Speech-Engine"""
        try:
            self.tts_engine = pyttsx3.init()
            
            # Verfügbare Stimmen anzeigen
            voices = self.tts_engine.getProperty('voices')
            logger.debug(f"Verfügbare Stimmen: {len(voices)}")
            
            # Stimme basierend auf der Spracheinstellung auswählen
            selected_voice = None
            language_prefix = self.voice_language.split('-')[0].lower()
            
            for voice in voices:
                if language_prefix in voice.id.lower():
                    selected_voice = voice.id
                    logger.debug(f"Stimme für {self.voice_language} gefunden: {voice.id}")
                    break
            
            if selected_voice:
                self.tts_engine.setProperty('voice', selected_voice)
            
            # Sprechgeschwindigkeit und Lautstärke einstellen
            self.tts_engine.setProperty('rate', self.voice_rate)
            self.tts_engine.setProperty('volume', self.voice_volume)
            
            logger.info("Text-to-Speech-Engine initialisiert")
        except Exception as e:
            logger.error(f"Fehler bei der Initialisierung der Text-to-Speech-Engine: {e}")
            self.tts_engine = None
    
    def start(self):
        """Startet die kontinuierliche Spracherkennung"""
        if self.running:
            logger.warning("Spracherkennung läuft bereits")
            return
        
        if not PYAUDIO_AVAILABLE:
            logger.error("PyAudio nicht verfügbar. Spracherkennung kann nicht gestartet werden.")
            return
        
        self.running = True
        self.listening_for_wake_word = True
        
        # Thread für die kontinuierliche Spracherkennung starten
        self.recognition_thread = threading.Thread(target=self._continuous_recognition, daemon=True)
        self.recognition_thread.start()
        
        logger.info("Kontinuierliche Spracherkennung gestartet")
    
    def stop(self):
        """Stoppt die kontinuierliche Spracherkennung"""
        self.running = False
        self.listening_for_wake_word = False
        
        if self.recognition_thread and self.recognition_thread.is_alive():
            self.recognition_thread.join(timeout=2.0)
        
        logger.info("Spracherkennung gestoppt")
    
    def _continuous_recognition(self):
        """Thread-Funktion für kontinuierliche Spracherkennung"""
        logger.info("Kontinuierliche Spracherkennung gestartet")
        
        # Mikrofon einrichten
        mic = sr.Microphone(sample_rate=self.sample_rate)
        
        with mic as source:
            # Umgebungsgeräusche anpassen
            logger.info("Umgebungsgeräusche werden kalibriert...")
            self.recognizer.adjust_for_ambient_noise(source, duration=1)
            logger.info(f"Energieschwelle auf {self.recognizer.energy_threshold} gesetzt")
            
            while self.running:
                try:
                    if self.listening_for_wake_word:
                        # Auf Aktivierungswort lauschen
                        logger.debug("Höre auf Aktivierungswort...")
                        audio = self.recognizer.listen(source, timeout=1, phrase_time_limit=3)
                        
                        # Aktivierungswort erkennen
                        try:
                            # In Offline-Modus lokale Erkennung verwenden
                            if self.offline_mode:
                                # Voice Recognition kann ohne Internet mit dem Modell "Vosk" implementiert werden
                                # Hier ist ein Fallback zur Sphinx-Engine, die direkt in speech_recognition enthalten ist
                                text = self.recognizer.recognize_sphinx(audio).lower()
                            else:
                                # Zunächst Google für bessere Genauigkeit verwenden
                                text = self.recognizer.recognize_google(
                                    audio, 
                                    language=self.voice_language
                                ).lower()
                            
                            logger.debug(f"Erkannt: {text}")
                            
                            # Aktivierungswort überprüfen
                            if self.wake_word.lower() in text.lower():
                                logger.info(f"Aktivierungswort erkannt: {self.wake_word}")
                                self._on_wake_word_detected()
                        except sr.UnknownValueError:
                            # Nichts erkannt - normal während des Lauschens
                            pass
                        except sr.RequestError as e:
                            # API-Fehler - ggf. auf Offline-Modus umschalten
                            logger.warning(f"API-Anfragefehler: {e}")
                            if not self.offline_mode:
                                logger.info("Wechsle in den Offline-Modus")
                                self.offline_mode = True
                        except Exception as e:
                            logger.error(f"Fehler bei Wakeword-Erkennung: {e}")
                    
                    elif self.recording_command:
                        # Nach dem Erkennen des Aktivierungsworts, Befehl aufnehmen
                        logger.info("Höre auf Befehl...")
                        
                        # Tonsignal zum Anzeigen des Aufnahmebeginns
                        self._play_audio_cue("start")
                        
                        audio = self.recognizer.listen(source, timeout=5, phrase_time_limit=10)
                        
                        # Tonsignal zum Anzeigen des Aufnahmeendes
                        self._play_audio_cue("end")
                        
                        # Befehl erkennen
                        try:
                            # Spracherkennung basierend auf Modus
                            if self.offline_mode:
                                text = self.recognizer.recognize_sphinx(audio).lower()
                            else:
                                text = self.recognizer.recognize_google(
                                    audio, 
                                    language=self.voice_language
                                ).lower()
                            
                            logger.info(f"Befehl erkannt: {text}")
                            
                            # In die Befehlswarteschlange einfügen
                            command = {
                                'text': text,
                                'timestamp': datetime.now().isoformat(),
                                'audio': audio  # Audiodaten für eventuelle weitere Verarbeitung
                            }
                            self.command_queue.put(command)
                            
                            # Wieder auf Aktivierungswort lauschen
                            self.recording_command = False
                            self.listening_for_wake_word = True
                        except sr.UnknownValueError:
                            logger.info("Konnte keinen Befehl erkennen")
                            self._speak("Ich konnte dich leider nicht verstehen. Bitte versuche es erneut.")
                            # Wieder auf Aktivierungswort lauschen
                            self.recording_command = False
                            self.listening_for_wake_word = True
                        except sr.RequestError as e:
                            logger.warning(f"API-Anfragefehler: {e}")
                            self._speak("Es gab ein Problem mit der Spracherkennung.")
                            # Wieder auf Aktivierungswort lauschen
                            self.recording_command = False
                            self.listening_for_wake_word = True
                            # In den Offline-Modus wechseln
                            if not self.offline_mode:
                                logger.info("Wechsle in den Offline-Modus")
                                self.offline_mode = True
                        except Exception as e:
                            logger.error(f"Fehler bei Befehlserkennung: {e}")
                            self.recording_command = False
                            self.listening_for_wake_word = True
                except Exception as e:
                    logger.error(f"Fehler bei der kontinuierlichen Spracherkennung: {e}")
                    time.sleep(1)  # Kurze Pause, um CPU-Last zu reduzieren
    
    def _on_wake_word_detected(self):
        """Wird aufgerufen, wenn das Aktivierungswort erkannt wurde"""
        # Status aktualisieren
        self.listening_for_wake_word = False
        self.recording_command = True
        
        # Feedback an den Benutzer
        self._speak("Ja?", block=False)
    
    def _play_audio_cue(self, cue_type):
        """Spielt einen Audiohinweis ab"""
        try:
            # Implementierung hängt von verfügbaren Audiodateien ab
            # Hier könnte man kurze Töne mithilfe von PyAudio direkt generieren
            pass
        except Exception as e:
            logger.error(f"Fehler beim Abspielen des Audiohinweises: {e}")
    
    def speak(self, text, block=True):
        """
        Spricht einen Text
        
        Args:
            text: str - Der zu sprechende Text
            block: bool - Blockiert, bis das Sprechen abgeschlossen ist
        """
        # Öffentliche Methode, die von extern aufgerufen werden kann
        self._speak(text, block=block)
    
    def _speak(self, text, block=True):
        """
        Interne Methode für Text-to-Speech
        
        Args:
            text: str - Der zu sprechende Text
            block: bool - Blockiert, bis das Sprechen abgeschlossen ist
        """
        if not text:
            return
        
        if self.tts_engine:
            try:
                logger.debug(f"Spreche: {text}")
                
                # In separatem Thread sprechen, wenn nicht blockierend
                if not block:
                    t = threading.Thread(target=self._speak_blocking, args=(text,))
                    t.daemon = True
                    t.start()
                else:
                    self._speak_blocking(text)
            except Exception as e:
                logger.error(f"Fehler beim Sprechen: {e}")
    
    def _speak_blocking(self, text):
        """Blockierendes Sprechen des Textes"""
        try:
            self.tts_engine.say(text)
            self.tts_engine.runAndWait()
        except Exception as e:
            logger.error(f"Fehler beim blockierenden Sprechen: {e}")
    
    def get_next_command(self, timeout=None) -> Optional[Dict[str, Any]]:
        """
        Holt den nächsten Sprachbefehl aus der Queue
        
        Args:
            timeout: Optional[float] - Timeout in Sekunden
            
        Returns:
            Dict mit Befehlsdaten oder None, wenn keine Daten verfügbar sind
        """
        try:
            command = self.command_queue.get(block=True, timeout=timeout)
            self.command_queue.task_done()
            
            # Audiodaten für die externe Nutzung entfernen
            if 'audio' in command:
                del command['audio']
            
            return command
        except queue.Empty:
            return None
    
    def recognize_text(self, audio_data=None, file_path=None, language=None) -> Dict[str, Any]:
        """
        Erkennt Text aus Audiodaten oder einer Audiodatei
        
        Args:
            audio_data: Optional[bytes] - Rohe Audiodaten
            file_path: Optional[str] - Pfad zur Audiodatei
            language: Optional[str] - Sprachcode (z.B. 'de-DE')
            
        Returns:
            Dict mit Erkennungsergebnissen
        """
        if not audio_data and not file_path:
            return {"error": "Keine Audiodaten oder Datei angegeben"}
        
        if not language:
            language = self.voice_language
        
        try:
            if file_path:
                # Audiodatei laden
                with sr.AudioFile(file_path) as source:
                    audio_data = self.recognizer.record(source)
            
            # Spracherkennung
            result = {
                'timestamp': datetime.now().isoformat()
            }
            
            try:
                # Versuche es mit verschiedenen Engines
                if not self.offline_mode:
                    # Online-Erkennung mit Google
                    text = self.recognizer.recognize_google(audio_data, language=language)
                    result['text'] = text
                    result['engine'] = 'google'
                else:
                    # Offline-Erkennung mit Sphinx
                    text = self.recognizer.recognize_sphinx(audio_data)
                    result['text'] = text
                    result['engine'] = 'sphinx'
            except sr.UnknownValueError:
                result['error'] = "Konnte keine Sprache erkennen"
            except sr.RequestError as e:
                result['error'] = f"API-Anfragefehler: {e}"
                # In den Offline-Modus wechseln
                if not self.offline_mode:
                    logger.info("Wechsle in den Offline-Modus")
                    self.offline_mode = True
                    # Erneut versuchen mit Offline-Engine
                    try:
                        text = self.recognizer.recognize_sphinx(audio_data)
                        result['text'] = text
                        result['engine'] = 'sphinx'
                        del result['error']  # Fehler entfernen, da erfolgreich
                    except Exception:
                        pass
            
            return result
        except Exception as e:
            logger.error(f"Fehler bei der Spracherkennung: {e}")
            return {"error": str(e)}
    
    def save_audio_to_file(self, audio_data, file_path=None) -> Optional[str]:
        """
        Speichert Audiodaten in einer Datei
        
        Args:
            audio_data: Die Audiodaten
            file_path: Optional[str] - Pfad zur Ausgabedatei (wenn None, wird automatisch generiert)
            
        Returns:
            Pfad zur gespeicherten Datei oder None bei Fehler
        """
        try:
            if file_path is None:
                # Automatischen Dateinamen generieren
                audio_dir = os.path.expanduser("~/Library/Application Support/MacAssistant/audio")
                os.makedirs(audio_dir, exist_ok=True)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                file_path = os.path.join(audio_dir, f"audio_{timestamp}.wav")
            
            # In WAV-Format speichern
            with open(file_path, "wb") as f:
                f.write(audio_data.get_wav_data())
            
            logger.debug(f"Audio gespeichert: {file_path}")
            return file_path
        except Exception as e:
            logger.error(f"Fehler beim Speichern des Audios: {e}")
            return None
    
    def set_language(self, language_code):
        """
        Setzt die Sprache für Sprach-Ein- und Ausgabe
        
        Args:
            language_code: str - Sprachcode (z.B. 'de-DE', 'en-US')
        
        Returns:
            bool - Erfolgsstatus
        """
        if language_code in self.supported_languages:
            self.voice_language = language_code
            
            # TTS-Engine neu initialisieren mit neuer Sprache
            self.init_tts_engine()
            
            logger.info(f"Sprache auf {self.supported_languages[language_code]} ({language_code}) umgestellt")
            return True
        else:
            logger.warning(f"Nicht unterstützte Sprache: {language_code}")
            return False
    
    def set_wake_word(self, wake_word):
        """
        Setzt das Aktivierungswort
        
        Args:
            wake_word: str - Neues Aktivierungswort
        """
        if wake_word and len(wake_word) >= 3:
            self.wake_word = wake_word.lower()
            logger.info(f"Aktivierungswort auf '{self.wake_word}' gesetzt")
            return True
        else:
            logger.warning(f"Ungültiges Aktivierungswort: {wake_word}")
            return False
    
    def transcribe_audio_file(self, file_path, language=None) -> Dict[str, Any]:
        """
        Transkribiert eine Audiodatei
        
        Args:
            file_path: str - Pfad zur Audiodatei
            language: Optional[str] - Sprachcode (z.B. 'de-DE')
            
        Returns:
            Dict mit Transkriptionsergebnissen
        """
        if not os.path.exists(file_path):
            return {"error": f"Datei nicht gefunden: {file_path}"}
        
        if not language:
            language = self.voice_language
        
        # Audiodatei-Format überprüfen und konvertieren wenn nötig
        if not file_path.lower().endswith('.wav'):
            if PYDUB_AVAILABLE:
                try:
                    # Konvertieren in WAV
                    audio = AudioSegment.from_file(file_path)
                    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
                        temp_path = temp_file.name
                    audio.export(temp_path, format="wav")
                    file_path = temp_path
                except Exception as e:
                    return {"error": f"Fehler bei der Audiokonvertierung: {e}"}
            else:
                return {"error": "Pydub nicht verfügbar für Audiokonvertierung"}
        
        # Audiodatei transkribieren
        return self.recognize_text(file_path=file_path, language=language)
    
    def handle_voice_command(self, command_text: str) -> Dict[str, Any]:
        """
        Verarbeitet einen Sprachbefehl und gibt eine Antwort
        
        Args:
            command_text: str - Der Sprachbefehl als Text
            
        Returns:
            Dict mit Verarbeitungsergebnissen
        """
        try:
            # Sprachbefehl an den AI-Service zur Verarbeitung senden
            if self.ai_service:
                response = self.ai_service.process_text(command_text)
                
                # Antwort sprechen
                if response and 'response' in response:
                    self._speak(response['response'])
                
                return response
            else:
                logger.warning("Kein AI-Service verfügbar für die Befehlsverarbeitung")
                self._speak("Ich kann keine Befehle verarbeiten, da der KI-Dienst nicht verfügbar ist.")
                return {"error": "Kein AI-Service verfügbar"}
        except Exception as e:
            logger.error(f"Fehler bei der Verarbeitung des Sprachbefehls: {e}")
            self._speak("Es ist ein Fehler bei der Verarbeitung deines Befehls aufgetreten.")
            return {"error": str(e)}