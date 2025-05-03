#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
mac_control.py - Mac-Steuerungsmodul für die Mac-Assistenten-App
Erstellt am: 2025-05-03
Änderungen:
- Initiale Implementierung des Mac-Steuerungsmoduls
- Integration mit pyautogui und macOS-spezifischen Frameworks
"""

import os
import logging
import subprocess
import time
from typing import Optional, Tuple, List, Dict, Any

# macOS-spezifische Imports
import pyautogui
from AppKit import NSWorkspace, NSRunningApplication, NSApplicationActivationPolicyRegular
from Quartz import (
    CGWindowListCopyWindowInfo,
    kCGWindowListOptionOnScreenOnly,
    kCGNullWindowID
)

logger = logging.getLogger("MacAssistant.MacController")

class MacController:
    """Klasse zur Steuerung des Mac-Computers"""
    
    def __init__(self):
        """Initialisiert den Mac-Controller"""
        # PyAutoGUI-Sicherheitseinstellungen
        pyautogui.FAILSAFE = True
        
        # Bildschirmgröße ermitteln
        self.screen_width, self.screen_height = pyautogui.size()
        logger.info(f"Bildschirmgröße erkannt: {self.screen_width}x{self.screen_height}")
    
    def open_application(self, app_name: str) -> bool:
        """
        Öffnet eine Anwendung auf dem Mac
        
        Args:
            app_name: Name der zu öffnenden Anwendung
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            # Versuche die App zu öffnen
            result = subprocess.run(
                ["open", "-a", app_name],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                logger.info(f"Anwendung '{app_name}' erfolgreich geöffnet")
                return True
            else:
                logger.error(f"Fehler beim Öffnen von '{app_name}': {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Fehler beim Öffnen der Anwendung '{app_name}': {e}")
            return False
    
    def close_application(self, app_name: str) -> bool:
        """
        Schließt eine Anwendung auf dem Mac
        
        Args:
            app_name: Name der zu schließenden Anwendung
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            # Finde die laufende Anwendung
            running_apps = NSWorkspace.sharedWorkspace().runningApplications()
            app_to_close = None
            
            for app in running_apps:
                if app.localizedName() and app_name.lower() in app.localizedName().lower():
                    app_to_close = app
                    break
            
            if app_to_close:
                # Versuche die App zu schließen
                app_to_close.terminate()
                logger.info(f"Anwendung '{app_name}' wird geschlossen")
                return True
            else:
                logger.warning(f"Anwendung '{app_name}' nicht gefunden oder nicht aktiv")
                return False
                
        except Exception as e:
            logger.error(f"Fehler beim Schließen der Anwendung '{app_name}': {e}")
            return False
    
    def get_active_application(self) -> Optional[str]:
        """
        Gibt den Namen der aktuell aktiven Anwendung zurück
        
        Returns:
            Name der aktiven Anwendung oder None
        """
        try:
            active_app = NSWorkspace.sharedWorkspace().activeApplication()
            if active_app:
                return active_app["NSApplicationName"]
            return None
        except Exception as e:
            logger.error(f"Fehler beim Ermitteln der aktiven Anwendung: {e}")
            return None
    
    def list_running_applications(self) -> List[str]:
        """
        Gibt eine Liste aller laufenden Anwendungen zurück
        
        Returns:
            Liste der Namen aller laufenden Anwendungen
        """
        try:
            running_apps = NSWorkspace.sharedWorkspace().runningApplications()
            app_names = []
            
            for app in running_apps:
                if app.activationPolicy() == NSApplicationActivationPolicyRegular:
                    app_name = app.localizedName()
                    if app_name:
                        app_names.append(app_name)
            
            return app_names
        except Exception as e:
            logger.error(f"Fehler beim Auflisten der laufenden Anwendungen: {e}")
            return []
    
    def type_text(self, text: str) -> bool:
        """
        Gibt Text über die Tastatur ein
        
        Args:
            text: Einzugebender Text
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            pyautogui.write(text)
            logger.info(f"Text eingegeben: '{text}'")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Eingeben von Text: {e}")
            return False
    
    def press_key(self, key: str) -> bool:
        """
        Drückt eine Taste auf der Tastatur
        
        Args:
            key: Zu drückende Taste (z.B. 'enter', 'esc', 'cmd')
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            pyautogui.press(key)
            logger.info(f"Taste gedrückt: '{key}'")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Drücken der Taste '{key}': {e}")
            return False
    
    def key_combination(self, keys: List[str]) -> bool:
        """
        Drückt eine Tastenkombination
        
        Args:
            keys: Liste der zu drückenden Tasten (z.B. ['cmd', 'c'] für Copy)
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            # Tastenkombination drücken
            pyautogui.hotkey(*keys)
            logger.info(f"Tastenkombination gedrückt: {'-'.join(keys)}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Drücken der Tastenkombination {keys}: {e}")
            return False
    
    def click(self, x: Optional[int] = None, y: Optional[int] = None) -> bool:
        """
        Klickt an einer Position auf dem Bildschirm
        
        Args:
            x: X-Koordinate (wenn None, aktuelle Mausposition)
            y: Y-Koordinate (wenn None, aktuelle Mausposition)
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            if x is not None and y is not None:
                pyautogui.click(x, y)
                logger.info(f"Klick an Position ({x}, {y})")
            else:
                pyautogui.click()
                current_pos = pyautogui.position()
                logger.info(f"Klick an aktueller Position {current_pos}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Klicken: {e}")
            return False
    
    def move_mouse(self, x: int, y: int, duration: float = 0.5) -> bool:
        """
        Bewegt die Maus zu einer Position
        
        Args:
            x: X-Koordinate
            y: Y-Koordinate
            duration: Dauer der Bewegung in Sekunden
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            pyautogui.moveTo(x, y, duration=duration)
            logger.info(f"Maus bewegt zu ({x}, {y})")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Bewegen der Maus: {e}")
            return False
    
    def scroll(self, amount: int) -> bool:
        """
        Scrollt auf dem Bildschirm
        
        Args:
            amount: Scroll-Betrag (positiv = runter, negativ = hoch)
        
        Returns:
            True wenn erfolgreich, False wenn nicht
        """
        try:
            pyautogui.scroll(amount)
            scroll_direction = "runter" if amount < 0 else "hoch"
            logger.info(f"Scroll {scroll_direction} um {abs(amount)} Einheiten")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Scrollen: {e}")
            return False
    
    def take_screenshot(self, filename: Optional[str] = None) -> Optional[str]:
        """
        Erstellt einen Screenshot
        
        Args:
            filename: Optionaler Dateiname für den Screenshot
        
        Returns:
            Pfad zum Screenshot oder None bei Fehler
        """
        try:
            if not filename:
                timestamp = time.strftime("%Y%m%d-%H%M%S")
                filename = f"screenshot_{timestamp}.png"
            
            # Stelle sicher, dass wir einen absoluten Pfad haben
            if not os.path.isabs(filename):
                base_dir = os.path.join(os.path.expanduser("~"), "MacAssistant", "screenshots")
                os.makedirs(base_dir, exist_ok=True)
                filename = os.path.join(base_dir, filename)
            
            # Screenshot erstellen
            screenshot = pyautogui.screenshot()
            screenshot.save(filename)
            
            logger.info(f"Screenshot erstellt: {filename}")
            return filename
        
        except Exception as e:
            logger.error(f"Fehler beim Erstellen des Screenshots: {e}")
            return None
    
    def execute_command(self, command: str) -> Tuple[bool, str]:
        """
        Führt einen Terminal-Befehl aus
        
        Args:
            command: Auszuführender Befehl
        
        Returns:
            Tuple mit (Erfolg, Ausgabe/Fehlermeldung)
        """
        try:
            # Befehl ausführen
            result = subprocess.run(
                command, 
                shell=True, 
                capture_output=True, 
                text=True
            )
            
            if result.returncode == 0:
                logger.info(f"Befehl erfolgreich ausgeführt: '{command}'")
                return True, result.stdout
            else:
                logger.error(f"Befehl fehlgeschlagen: '{command}', Fehler: {result.stderr}")
                return False, result.stderr
                
        except Exception as e:
            logger.error(f"Fehler beim Ausführen des Befehls '{command}': {e}")
            return False, str(e)
    
    def get_window_info(self) -> List[Dict[str, Any]]:
        """
        Gibt Informationen über alle sichtbaren Fenster zurück
        
        Returns:
            Liste von Dictionaries mit Fensterinformationen
        """
        try:
            window_list = CGWindowListCopyWindowInfo(
                kCGWindowListOptionOnScreenOnly, kCGNullWindowID
            )
            
            windows = []
            for window in window_list:
                window_info = {
                    'app_name': window.get('kCGWindowOwnerName', ''),
                    'window_name': window.get('kCGWindowName', ''),
                    'position': window.get('kCGWindowBounds', {})
                }
                windows.append(window_info)
            
            return windows
            
        except Exception as e:
            logger.error(f"Fehler beim Abrufen von Fensterinformationen: {e}")
            return []
