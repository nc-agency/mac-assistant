#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
screen.py - Bildschirmanalyse-Modul für die Mac-Assistenten-App
Erstellt am: 2025-05-03
Änderungen:
- Initiale Implementierung des Bildschirmanalyse-Moduls
- Integration mit macOS-spezifischen Frameworks für Bildschirmaufnahme
"""

import os
import logging
import threading
import time
from typing import Optional, List, Dict, Any
import queue
import tempfile

# macOS-spezifische Imports
from AppKit import NSScreen
from Quartz import CIFilter, CIImage, CGWindowListCreateImage, CGRectInfinite
from Quartz import kCGWindowListOptionOnScreenOnly, kCGNullWindowID

# Bildverarbeitung
from PIL import Image
import numpy as np

# Lokale Imports
from ai_service import AIService

logger = logging.getLogger("MacAssistant.ScreenManager")

class ScreenManager:
    """Klasse zur Analyse des Bildschirminhalts"""
    
    def __init__(self, ai_service: AIService):
        """
        Initialisiert den Screen Manager
        
        Args:
            ai_service: Instanz des AI-Service
        """
        self.ai_service = ai_service
        self.config = ai_service.config
        
        # Verzeichnis für temporäre Screenshots
        self.screenshots_dir = os.path.join(tempfile.gettempdir(), "mac_assistant_screenshots")
        os.makedirs(self.screenshots_dir, exist_ok=True)
        
        # Bildschirmgröße ermitteln
        self.screens = NSScreen.screens()
        self.main_screen = self.screens[0]
        self.screen_frame = self.main_screen.frame()
        self.screen_width = self.screen_frame.size.width
        self.screen_height = self.screen_frame.size.height
        
        logger.info(f"Bildschirmgröße: {self.screen_width}x{self.screen_height}")
        
        # Thread für kontinuierliche Bildschirmanalyse
        self.analysis_thread = None
        self.stop_analysis = threading.Event()
        self.analysis_interval = self.config.screen_capture_interval
        
        # Warteschlange für Bildschirmanalyse-Ereignisse
        self.analysis_queue = queue.Queue()
        
        logger.info("Screen Manager initialisiert")
    
    def start_analysis(self):
        """Startet die kontinuierliche Bildschirmanalyse im Hintergrund"""
        if self.analysis_thread and self.analysis_thread.is_alive():
            logger.warning("Bildschirmanalyse läuft bereits")
            return
        
        self.stop_analysis.clear()
        self.analysis_thread = threading.Thread(target=self._analyze_continuously)
        self.analysis_thread.daemon = True
        self.analysis_thread.start()
        logger.info("Bildschirmanalyse gestartet")
    
    def stop_analysis(self):
        """Stoppt die kontinuierliche Bildschirmanalyse"""
        if not self.analysis_thread or not self.analysis_thread.is_alive():
            logger.warning("Bildschirmanalyse läuft nicht")
            return
        
        self.stop_analysis.set()
        self.analysis_thread.join(timeout=2.0)
        logger.info("Bildschirmanalyse gestoppt")
    
    def _analyze_continuously(self):
        """Analysiert kontinuierlich den Bildschirminhalt (wird als Thread ausgeführt)"""
        logger.info("Kontinuierliche Bildschirmanalyse gestartet")
        
        while not self.stop_analysis.is_set():
            try:
                # Screenshot erstellen
                screenshot_path = self.take_screenshot()
                
                if screenshot_path:
                    # Bild analysieren
                    analysis = self.ai_service.analyze_image(screenshot_path)
                    
                    # Analyse in die Warteschlange stellen
                    if analysis:
                        self.analysis_queue.put({
                            'timestamp': time.time(),
                            'analysis': analysis,
                            'screenshot_path': screenshot_path
                        })
                    
                    # Alte Screenshots löschen, um Speicherplatz zu sparen
                    self._cleanup_old_screenshots()
                
            except Exception as e:
                logger.error(f"Fehler bei der kontinuierlichen Bildschirmanalyse: {e}")
            
            # Warten bis zum nächsten Intervall
            time.sleep(self.analysis_interval)
    
    def take_screenshot(self) -> Optional[str]:
        """
        Erstellt einen Screenshot des Bildschirms
        
        Returns:
            Pfad zum Screenshot oder None bei Fehler
        """
        try:
            # Zeitstempel für Dateinamen
            timestamp = time.strftime("%Y%m%d-%H%M%S")
            filename = os.path.join(self.screenshots_dir, f"screenshot_{timestamp}.png")
            
            # Screenshot mit Quartz erstellen
            image_ref = CGWindowListCreateImage(
                CGRectInfinite,
                kCGWindowListOptionOnScreenOnly,
                kCGNullWindowID,
                0
            )
            
            # In CIImage konvertieren
            ci_image = CIImage.imageWithCGImage_(image_ref)
            
            # In PIL Image konvertieren
            pixel_data = np.array(
                ci_image.toCVPixelBuffer().toNumpyArray()
            )
            
            # Farbreihenfolge anpassen (BGR -> RGB)
            pixel_data = pixel_data[:, :, ::-1]
            
            # Als Bilddatei speichern
            img = Image.fromarray(pixel_data)
            img.save(filename)
            
            logger.info(f"Screenshot erstellt: {filename}")
            return filename
            
        except Exception as e:
            logger.error(f"Fehler beim Erstellen des Screenshots: {e}")
            return None
    
    def analyze_screenshot(self, screenshot_path: str) -> Optional[str]:
        """
        Analysiert einen Screenshot mit dem AI-Service
        
        Args:
            screenshot_path: Pfad zum Screenshot
            
        Returns:
            Analyseergebnis oder None bei Fehler
        """
        try:
            return self.ai_service.analyze_image(screenshot_path)
        except Exception as e:
            logger.error(f"Fehler bei der Analyse des Screenshots: {e}")
            return None
    
    def get_latest_analysis(self, block: bool = True, timeout: Optional[float] = None) -> Optional[Dict[str, Any]]:
        """
        Holt die neueste Bildschirmanalyse aus der Warteschlange
        
        Args:
            block: Blockierender Modus
            timeout: Timeout in Sekunden (nur im blockierenden Modus)
            
        Returns:
            Analyseergebnis oder None bei Timeout/leerem Queue
        """
        try:
            return self.analysis_queue.get(block=block, timeout=timeout)
        except queue.Empty:
            return None
    
    def _cleanup_old_screenshots(self, max_age_seconds: int = 300):
        """
        Löscht alte Screenshots, um Speicherplatz zu sparen
        
        Args:
            max_age_seconds: Maximales Alter in Sekunden (Standard: 5 Minuten)
        """
        try:
            current_time = time.time()
            for filename in os.listdir(self.screenshots_dir):
                file_path = os.path.join(self.screenshots_dir, filename)
                if os.path.isfile(file_path):
                    # Prüfen, ob die Datei ein Screenshot ist
                    if filename.startswith("screenshot_") and filename.endswith(".png"):
                        # Prüfen, ob die Datei alt genug ist
                        file_age = current_time - os.path.getmtime(file_path)
                        if file_age > max_age_seconds:
                            os.remove(file_path)
                            logger.debug(f"Alter Screenshot gelöscht: {filename}")
        except Exception as e:
            logger.error(f"Fehler beim Bereinigen alter Screenshots: {e}")
    
    def get_screen_info(self) -> Dict[str, Any]:
        """
        Gibt Informationen über den Bildschirm zurück
        
        Returns:
            Dictionary mit Bildschirminformationen
        """
        screen_info = {
            'width': self.screen_width,
            'height': self.screen_height,
            'scale_factor': self.main_screen.backingScaleFactor(),
            'color_space': str(self.main_screen.colorSpace()),
            'frame': {
                'x': self.screen_frame.origin.x,
                'y': self.screen_frame.origin.y,
                'width': self.screen_frame.size.width,
                'height': self.screen_frame.size.height
            }
        }
        
        return screen_info
