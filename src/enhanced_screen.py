#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
enhanced_screen.py - Erweiterte Bildschirmanalyse für Mac-Assistenten
Erstellt am: 2025-05-04
Änderungen:
- Initiale Implementierung der erweiterten Bildschirmanalyse
- Verbesserte Bild-zu-Text-Extraktion mit OCR
- Implementierung von Anwendungskontext-Erkennung
- Integration mit OpenAI Vision API und Google Gemini für erweiterte Analyse
"""

import os
import time
import logging
import threading
import base64
import io
import json
from typing import Dict, List, Optional, Tuple, Any, Union
from queue import Queue, Empty
from datetime import datetime
from PIL import Image, ImageGrab
import pyautogui
import pytesseract
from Quartz import (
    CGDisplayBounds,
    CGMainDisplayID,
    CGGetActiveDisplayList,
    CGDisplayPixelsHigh,
    CGDisplayPixelsWide
)

logger = logging.getLogger("MacAssistant.EnhancedScreenManager")

class EnhancedScreenManager:
    """Erweiterte Bildschirmanalyse für Mac-Assistenten"""
    
    def __init__(self, ai_service, config=None):
        """Initialisiert den Enhanced Screen Manager"""
        self.ai_service = ai_service
        self.config = config
        
        # Zustandsvariablen
        self.running = False
        self.capture_interval = config.screen_capture_interval if config else 5
        self.max_history = 10
        self.screen_history = []
        self.text_history = []
        self.app_history = []
        
        # Ereignis-Queue für Analysen
        self.analysis_queue = Queue()
        
        # Bildschirmgröße ermitteln
        self.update_screen_dimensions()
        logger.info(f"Bildschirmgröße: {self.width}x{self.height}")
        
        # OCR-Engine konfigurieren
        try:
            # Pfad zu Tesseract überprüfen/setzen
            if os.path.exists('/usr/local/bin/tesseract'):
                pytesseract.pytesseract.tesseract_cmd = r'/usr/local/bin/tesseract'
            elif os.path.exists('/opt/homebrew/bin/tesseract'):
                pytesseract.pytesseract.tesseract_cmd = r'/opt/homebrew/bin/tesseract'
            
            # Tesseract-Version ausgeben
            logger.info(f"Tesseract-Version: {pytesseract.get_tesseract_version()}")
        except Exception as e:
            logger.warning(f"Tesseract könnte nicht richtig konfiguriert sein: {e}")
        
        # Thread für die kontinuierliche Analyse
        self.analysis_thread = None
        
        logger.info("Enhanced Screen Manager initialisiert")
    
    def update_screen_dimensions(self):
        """Aktualisiert die Bildschirmdimensionen"""
        try:
            # Aktive Displays abrufen
            (error, displays, count) = CGGetActiveDisplayList(32, None, None)
            if error:
                raise Exception(f"Fehler beim Abrufen der Displays: {error}")
            
            # Hauptdisplay-Info abrufen
            main_display = CGMainDisplayID()
            bounds = CGDisplayBounds(main_display)
            self.width = CGDisplayPixelsWide(main_display)
            self.height = CGDisplayPixelsHigh(main_display)
            
            # Multi-Display-Setup erkennen
            self.displays = []
            if count > 1:
                logger.info(f"Multi-Display-Setup erkannt: {count} Displays")
                for i in range(count):
                    display_id = displays[i]
                    width = CGDisplayPixelsWide(display_id)
                    height = CGDisplayPixelsHigh(display_id)
                    bounds = CGDisplayBounds(display_id)
                    self.displays.append({
                        'id': display_id,
                        'width': width,
                        'height': height,
                        'bounds': bounds
                    })
        except Exception as e:
            logger.error(f"Fehler bei der Bildschirmgrößenerkennung: {e}")
            # Fallback auf pyautogui
            screen_size = pyautogui.size()
            self.width = screen_size.width
            self.height = screen_size.height
    
    def start(self):
        """Startet die kontinuierliche Bildschirmanalyse"""
        if self.running:
            logger.warning("Bildschirmanalyse läuft bereits")
            return
        
        self.running = True
        
        # Thread für die kontinuierliche Analyse starten
        self.analysis_thread = threading.Thread(target=self._continuous_analysis, daemon=True)
        self.analysis_thread.start()
        
        logger.info("Kontinuierliche Bildschirmanalyse gestartet")
    
    def stop(self):
        """Stoppt die kontinuierliche Bildschirmanalyse"""
        self.running = False
        if self.analysis_thread and self.analysis_thread.is_alive():
            self.analysis_thread.join(timeout=2.0)
        logger.info("Bildschirmanalyse gestoppt")
    
    def take_screenshot(self, region=None, display_id=None) -> Optional[Image.Image]:
        """
        Nimmt einen Screenshot auf
        
        Args:
            region: Optional[Tuple[int, int, int, int]] - Region (x, y, width, height)
            display_id: Optional[int] - ID des Displays (für Multi-Display-Setups)
            
        Returns:
            PIL.Image oder None bei Fehler
        """
        try:
            if region:
                # Spezifische Region aufnehmen
                x, y, width, height = region
                screenshot = ImageGrab.grab(bbox=(x, y, x+width, y+height))
            elif display_id and len(self.displays) > 1:
                # Spezifisches Display aufnehmen
                for display in self.displays:
                    if display['id'] == display_id:
                        bounds = display['bounds']
                        x, y = bounds.origin.x, bounds.origin.y
                        width, height = bounds.size.width, bounds.size.height
                        screenshot = ImageGrab.grab(bbox=(x, y, x+width, y+height))
                        break
                else:
                    screenshot = ImageGrab.grab()
            else:
                # Gesamter Bildschirm
                screenshot = ImageGrab.grab()
            
            return screenshot
        except Exception as e:
            logger.error(f"Fehler beim Screenshot: {e}")
            return None
    
    def save_screenshot(self, screenshot: Image.Image, filename=None) -> Optional[str]:
        """
        Speichert einen Screenshot in einer Datei
        
        Args:
            screenshot: PIL.Image - Der Screenshot
            filename: Optional[str] - Dateiname (wenn None, wird automatisch generiert)
            
        Returns:
            Pfad zur gespeicherten Datei oder None bei Fehler
        """
        try:
            if filename is None:
                # Automatischen Dateinamen generieren
                screenshots_dir = os.path.expanduser("~/Library/Application Support/MacAssistant/screenshots")
                os.makedirs(screenshots_dir, exist_ok=True)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = os.path.join(screenshots_dir, f"screenshot_{timestamp}.png")
            
            # Screenshot speichern
            screenshot.save(filename)
            logger.debug(f"Screenshot gespeichert: {filename}")
            return filename
        except Exception as e:
            logger.error(f"Fehler beim Speichern des Screenshots: {e}")
            return None
    
    def extract_text_from_image(self, image: Image.Image, lang='deu+eng') -> str:
        """
        Extrahiert Text aus einem Bild mittels OCR
        
        Args:
            image: PIL.Image - Das Bild
            lang: str - Sprache(n) für OCR (default: 'deu+eng')
            
        Returns:
            Extrahierter Text
        """
        try:
            # OCR mit pytesseract
            text = pytesseract.image_to_string(image, lang=lang)
            return text
        except Exception as e:
            logger.error(f"Fehler bei OCR: {e}")
            return ""
    
    def detect_active_application(self) -> Dict[str, Any]:
        """
        Erkennt die aktive Anwendung und Fensterinformationen
        
        Returns:
            Dict mit Anwendungsinformationen
        """
        try:
            from Cocoa import NSWorkspace, NSRunningApplication, NSApplicationActivationPolicyRegular
            
            # Aktive Anwendung abrufen
            workspace = NSWorkspace.sharedWorkspace()
            active_app = workspace.frontmostApplication()
            
            if active_app:
                app_info = {
                    'name': active_app.localizedName(),
                    'bundle_id': active_app.bundleIdentifier(),
                    'pid': active_app.processIdentifier(),
                    'activationPolicy': active_app.activationPolicy(),
                    'active': active_app.activationPolicy() == NSApplicationActivationPolicyRegular,
                    'timestamp': datetime.now().isoformat()
                }
                return app_info
            else:
                return {
                    'name': 'Unknown',
                    'bundle_id': '',
                    'active': False,
                    'timestamp': datetime.now().isoformat()
                }
        except Exception as e:
            logger.error(f"Fehler bei Anwendungserkennung: {e}")
            return {
                'name': 'Error',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def analyze_image_with_ai(self, image: Image.Image) -> Dict[str, Any]:
        """
        Analysiert einen Screenshot mit der gewählten KI
        
        Args:
            image: PIL.Image - Das Bild
            
        Returns:
            Dict mit Analyseergebnissen
        """
        try:
            # Bild für API vorbereiten und an KI-Service übergeben
            buffered = io.BytesIO()
            image.save(buffered, format="JPEG")
            img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
            
            # Screenshot-Pfad temporär speichern (für APIs, die Dateipfade benötigen)
            temp_path = self.save_screenshot(image, filename=None)
            
            # Analyse mit dem KI-Service
            if temp_path:
                analysis_result = self.ai_service.analyze_image(temp_path)
                
                # Temporäre Datei löschen
                try:
                    os.remove(temp_path)
                except Exception:
                    pass
                
                return analysis_result
            else:
                return {"error": "Konnte temporären Screenshot nicht speichern"}
        except Exception as e:
            logger.error(f"Fehler bei KI-Bildanalyse: {e}")
            return {"error": str(e)}
    
    def create_context_from_screen(self, image=None) -> Dict[str, Any]:
        """
        Erstellt einen umfassenden Kontext aus dem aktuellen Bildschirminhalt
        
        Args:
            image: Optional[PIL.Image] - Bereits aufgenommener Screenshot (wenn None, wird neu aufgenommen)
            
        Returns:
            Dict mit Kontextinformationen
        """
        # Screenshot aufnehmen, falls noch nicht vorhanden
        if image is None:
            image = self.take_screenshot()
            if image is None:
                return {"error": "Konnte keinen Screenshot aufnehmen"}
        
        # Aktive Anwendung erkennen
        app_info = self.detect_active_application()
        
        # Text aus Bild extrahieren
        text = self.extract_text_from_image(image)
        
        # KI-Analyse des Bildes
        ai_analysis = self.analyze_image_with_ai(image)
        
        # Kontextinformationen zusammenfassen
        context = {
            "timestamp": datetime.now().isoformat(),
            "application": app_info,
            "extracted_text": text,
            "ai_analysis": ai_analysis,
            "screen_dimensions": {
                "width": self.width,
                "height": self.height
            }
        }
        
        return context
    
    def _continuous_analysis(self):
        """Thread-Funktion für kontinuierliche Bildschirmanalyse"""
        logger.info("Bildschirmanalyse gestartet")
        
        last_capture_time = 0
        
        while self.running:
            current_time = time.time()
            
            # Nur in den konfigurierten Intervallen Screenshots aufnehmen
            if current_time - last_capture_time >= self.capture_interval:
                try:
                    # Screenshot aufnehmen
                    screenshot = self.take_screenshot()
                    if screenshot:
                        # Kontext erstellen
                        context = self.create_context_from_screen(screenshot)
                        
                        # Kontextanalyse zur Queue hinzufügen
                        self.analysis_queue.put(context)
                        
                        # Historie aktualisieren
                        self.update_history(screenshot, context)
                        
                        # Zeit aktualisieren
                        last_capture_time = current_time
                except Exception as e:
                    logger.error(f"Fehler bei kontinuierlicher Analyse: {e}")
            
            # Kurze Pause, um CPU-Last zu reduzieren
            time.sleep(0.1)
    
    def update_history(self, screenshot, context):
        """Aktualisiert die Historie mit einem neuen Screenshot und Kontext"""
        # Screenshot zur Historie hinzufügen
        self.screen_history.append({
            'image': screenshot,
            'timestamp': datetime.now().isoformat()
        })
        
        # Text zur Historie hinzufügen
        if 'extracted_text' in context:
            self.text_history.append({
                'text': context['extracted_text'],
                'timestamp': context['timestamp']
            })
        
        # App zur Historie hinzufügen
        if 'application' in context:
            self.app_history.append(context['application'])
        
        # Historie auf maximale Größe begrenzen
        while len(self.screen_history) > self.max_history:
            self.screen_history.pop(0)
        
        while len(self.text_history) > self.max_history:
            self.text_history.pop(0)
            
        while len(self.app_history) > self.max_history:
            self.app_history.pop(0)
    
    def get_latest_analysis(self, timeout=0.5) -> Optional[Dict[str, Any]]:
        """
        Holt die neueste Bildschirmanalyse aus der Queue
        
        Args:
            timeout: float - Timeout in Sekunden für die Queue
            
        Returns:
            Dict mit Analysedaten oder None, wenn keine Daten verfügbar sind
        """
        try:
            analysis = self.analysis_queue.get(block=True, timeout=timeout)
            self.analysis_queue.task_done()
            return analysis
        except Empty:
            return None
    
    def get_screen_history(self) -> List[Dict[str, Any]]:
        """Gibt die Bildschirmhistorie zurück (ohne die Bilder selbst)"""
        # Nur Metadaten ohne die tatsächlichen Bilder zurückgeben, um Speicher zu sparen
        return [{
            'timestamp': item['timestamp']
        } for item in self.screen_history]
    
    def get_text_history(self) -> List[Dict[str, str]]:
        """Gibt die Texthistorie zurück"""
        return self.text_history
    
    def get_app_history(self) -> List[Dict[str, Any]]:
        """Gibt die Anwendungshistorie zurück"""
        return self.app_history
    
    def analyze_current_screen(self) -> Dict[str, Any]:
        """
        Sofortige Analyse des aktuellen Bildschirms
        
        Returns:
            Dict mit Kontextinformationen
        """
        screenshot = self.take_screenshot()
        if screenshot:
            return self.create_context_from_screen(screenshot)
        else:
            return {"error": "Konnte keinen Screenshot aufnehmen"}
    
    def analyze_region(self, x, y, width, height) -> Dict[str, Any]:
        """
        Analysiert eine spezifische Region auf dem Bildschirm
        
        Args:
            x, y, width, height: Koordinaten und Größe der Region
            
        Returns:
            Dict mit Kontextinformationen
        """
        screenshot = self.take_screenshot(region=(x, y, width, height))
        if screenshot:
            return self.create_context_from_screen(screenshot)
        else:
            return {"error": "Konnte keinen Screenshot der Region aufnehmen"}