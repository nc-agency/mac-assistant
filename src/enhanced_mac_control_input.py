#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
enhanced_mac_control_input.py - Eingabesteuerungsmodul für Mac-Assistenten
Erstellt am: 2025-05-04
Änderungen:
- Initiale Implementierung der erweiterten Eingabesteuerung
- Tastatur- und Mausautomatisierung
- Fortschrittliche Texteingabefunktionen
- Automatisierung von Systemfunktionen und Shortcuts
"""

import os
import time
import logging
import subprocess
import threading
import json
import re
from typing import Dict, List, Optional, Tuple, Any, Union, Callable
from datetime import datetime
import pyautogui
import AppKit

# Für Tastenkombinationen und erweiterte Eingaben
try:
    import keyboard
    KEYBOARD_MODULE_AVAILABLE = True
except ImportError:
    KEYBOARD_MODULE_AVAILABLE = False
    logging.warning("Keyboard-Modul nicht verfügbar. Installation empfohlen für erweiterte Tastaturfunktionen.")

logger = logging.getLogger("MacAssistant.EnhancedMacControlInput")

class EnhancedMacControlInput:
    """Erweiterte Eingabesteuerung für Mac-Assistenten"""
    
    def __init__(self, main_controller=None):
        """
        Initialisiert den Enhanced Mac Control Input Manager
        
        Args:
            main_controller: Optional[EnhancedMacController] - Hauptcontroller für Referenzen
        """
        self.main_controller = main_controller
        
        # Bildschirmgröße abrufen
        self.update_screen_dimensions()
        
        # Sonderzeichen und -tasten
        self.special_keys = {
            "enter": "return",
            "return": "return",
            "tab": "tab",
            "space": "space",
            "backspace": "backspace",
            "delete": "delete",
            "escape": "escape",
            "up": "up",
            "down": "down",
            "left": "left",
            "right": "right",
            "home": "home",
            "end": "end",
            "page_up": "pageup",
            "page_down": "pagedown",
            "f1": "f1",
            "f2": "f2",
            "f3": "f3",
            "f4": "f4",
            "f5": "f5",
            "f6": "f6",
            "f7": "f7",
            "f8": "f8",
            "f9": "f9",
            "f10": "f10",
            "f11": "f11",
            "f12": "f12",
        }
        
        # Modifier-Tasten
        self.modifiers = {
            "command": "command",
            "cmd": "command",
            "shift": "shift",
            "option": "option",
            "alt": "option",
            "control": "ctrl",
            "ctrl": "ctrl",
            "fn": "fn"
        }
        
        # Häufig verwendete macOS-Tastenkombinationen
        self.common_shortcuts = {
            "copy": ["command", "c"],
            "cut": ["command", "x"],
            "paste": ["command", "v"],
            "select_all": ["command", "a"],
            "save": ["command", "s"],
            "save_as": ["command", "shift", "s"],
            "undo": ["command", "z"],
            "redo": ["command", "shift", "z"],
            "new": ["command", "n"],
            "open": ["command", "o"],
            "close": ["command", "w"],
            "quit": ["command", "q"],
            "print": ["command", "p"],
            "find": ["command", "f"],
            "find_next": ["command", "g"],
            "find_previous": ["command", "shift", "g"],
            "spotlight": ["command", "space"],
            "screenshot": ["command", "shift", "3"],
            "screenshot_selection": ["command", "shift", "4"],
            "screenshot_window": ["command", "shift", "4", "space"],
            "switch_app": ["command", "tab"],
            "switch_windows": ["command", "`"],
            "mission_control": ["control", "up"],
            "show_desktop": ["F11"]
        }
        
        # Eingabepuffer für verzögerte Eingaben
        self.input_buffer = []
        self.buffer_speed = 0.01  # Zeit zwischen Tastendrücken in Sekunden
        
        logger.info("Enhanced Mac Control Input initialisiert")
    
    def update_screen_dimensions(self):
        """Aktualisiert die Bildschirmdimensionen"""
        try:
            # Bildschirmgröße ermitteln
            screen_size = pyautogui.size()
            self.width = screen_size.width
            self.height = screen_size.height
        except Exception as e:
            logger.error(f"Fehler bei der Bildschirmgrößenerkennung: {e}")
            # Standardwerte setzen
            self.width = 1280
            self.height = 800
    
    # ===== Tastatureingabe =====
    
    def type_text(self, text, interval=0.01) -> bool:
        """
        Gibt Text über die Tastatur ein
        
        Args:
            text: str - Der einzugebende Text
            interval: float - Intervall zwischen Tastendrücken
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if not text:
                return True
            
            # Text eingeben
            pyautogui.write(text, interval=interval)
            logger.debug(f"Text eingegeben: {text}")
            return True
        except Exception as e:
            logger.error(f"Fehler bei der Texteingabe: {e}")
            return False
    
    def type_text_with_formatting(self, text, interval=0.01) -> bool:
        """
        Gibt formatierten Text über die Tastatur ein, mit Unterstützung für Sonderzeichen und Formatierungen
        
        Args:
            text: str - Der einzugebende Text mit Formatierungsanweisungen
            interval: float - Intervall zwischen Tastendrücken
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if not text:
                return True
            
            # Textblöcke und Formatierungsanweisungen trennen
            # Format: "normaler Text {cmd+b} fettgedruckter Text {/cmd+b} normaler Text"
            blocks = re.split(r'\{([^}]+)\}', text)
            
            current_modifiers = []
            
            for i, block in enumerate(blocks):
                if i % 2 == 0:
                    # Gerader Index = normaler Text
                    if block:
                        if current_modifiers:
                            # Text mit aktiven Modifiern eingeben
                            with self._hold_keys(current_modifiers):
                                pyautogui.write(block, interval=interval)
                        else:
                            # Normalen Text eingeben
                            pyautogui.write(block, interval=interval)
                else:
                    # Ungerader Index = Formatierungsanweisung
                    if block.startswith('/'):
                        # Formatierung beenden
                        format_key = block[1:].strip().lower()
                        keys = self._parse_key_combination(format_key)
                        # Entferne alle Tasten aus current_modifiers
                        for key in keys:
                            if key in current_modifiers:
                                current_modifiers.remove(key)
                    else:
                        # Formatierung beginnen
                        keys = self._parse_key_combination(block.strip().lower())
                        for key in keys:
                            if key not in current_modifiers:
                                current_modifiers.append(key)
            
            return True
        except Exception as e:
            logger.error(f"Fehler bei der formatierten Texteingabe: {e}")
            return False
    
    def press_key(self, key) -> bool:
        """
        Drückt eine Taste
        
        Args:
            key: str - Die zu drückende Taste
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            # Taste normalisieren
            normalized_key = self._normalize_key(key)
            
            # Taste drücken
            pyautogui.press(normalized_key)
            logger.debug(f"Taste gedrückt: {normalized_key}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Drücken der Taste '{key}': {e}")
            return False
    
    def press_keys(self, keys) -> bool:
        """
        Drückt mehrere Tasten gleichzeitig (Tastenkombination)
        
        Args:
            keys: List[str] - Die zu drückenden Tasten
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if not keys:
                return True
            
            # Tasten normalisieren
            normalized_keys = [self._normalize_key(key) for key in keys]
            
            # Tastenkombination drücken
            pyautogui.hotkey(*normalized_keys)
            logger.debug(f"Tastenkombination gedrückt: {'+'.join(normalized_keys)}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Drücken der Tastenkombination {keys}: {e}")
            return False
    
    def press_shortcut(self, shortcut_name) -> bool:
        """
        Führt einen vordefinierten Shortcut aus
        
        Args:
            shortcut_name: str - Name des Shortcuts
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            shortcut_name = shortcut_name.lower()
            if shortcut_name in self.common_shortcuts:
                keys = self.common_shortcuts[shortcut_name]
                return self.press_keys(keys)
            else:
                logger.warning(f"Unbekannter Shortcut: {shortcut_name}")
                return False
        except Exception as e:
            logger.error(f"Fehler beim Ausführen des Shortcuts '{shortcut_name}': {e}")
            return False
    
    def _normalize_key(self, key) -> str:
        """Normalisiert einen Tastennamen für pyautogui"""
        key = str(key).lower()
        
        # Sonderzeichen übersetzen
        if key in self.special_keys:
            return self.special_keys[key]
        
        # Modifier-Tasten übersetzen
        if key in self.modifiers:
            return self.modifiers[key]
        
        return key
    
    def _parse_key_combination(self, key_combo) -> List[str]:
        """
        Parst eine Tastenkombination wie "cmd+shift+s"
        
        Args:
            key_combo: str - Die Tastenkombination
            
        Returns:
            List[str] - Liste der normalisierten Tasten
        """
        keys = key_combo.lower().split('+')
        return [self._normalize_key(key.strip()) for key in keys]
    
    def _hold_keys(self, keys):
        """
        Context Manager zum Halten mehrerer Tasten
        
        Args:
            keys: List[str] - Liste der zu haltenden Tasten
        """
        class KeyHolder:
            def __init__(self, keys_to_hold, normalizer):
                self.keys = [normalizer(key) for key in keys_to_hold]
            
            def __enter__(self):
                for key in self.keys:
                    pyautogui.keyDown(key)
            
            def __exit__(self, exc_type, exc_val, exc_tb):
                for key in reversed(self.keys):  # Wichtig: Tasten in umgekehrter Reihenfolge loslassen
                    pyautogui.keyUp(key)
        
        return KeyHolder(keys, self._normalize_key)
    
    # ===== Maussteuerung =====
    
    def move_mouse(self, x, y, duration=0.2) -> bool:
        """
        Bewegt die Maus zu einer bestimmten Position
        
        Args:
            x, y: int - Zielkoordinaten
            duration: float - Dauer der Bewegung
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            pyautogui.moveTo(x, y, duration=duration)
            logger.debug(f"Maus zu Position ({x}, {y}) bewegt")
            return True
        except Exception as e:
            logger.error(f"Fehler bei der Mausbewegung: {e}")
            return False
    
    def move_mouse_relative(self, dx, dy, duration=0.2) -> bool:
        """
        Bewegt die Maus relativ zur aktuellen Position
        
        Args:
            dx, dy: int - Relative Bewegung
            duration: float - Dauer der Bewegung
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            pyautogui.moveRel(dx, dy, duration=duration)
            logger.debug(f"Maus relativ bewegt ({dx}, {dy})")
            return True
        except Exception as e:
            logger.error(f"Fehler bei der relativen Mausbewegung: {e}")
            return False
    
    def click(self, x=None, y=None, button='left', clicks=1, interval=0.0) -> bool:
        """
        Führt einen Mausklick aus
        
        Args:
            x, y: Optional[int] - Koordinaten (wenn None, wird aktuelle Position verwendet)
            button: str - 'left', 'right' oder 'middle'
            clicks: int - Anzahl der Klicks
            interval: float - Intervall zwischen Klicks
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if x is not None and y is not None:
                pyautogui.click(x, y, button=button, clicks=clicks, interval=interval)
                logger.debug(f"{button}-Klick an Position ({x}, {y})")
            else:
                pyautogui.click(button=button, clicks=clicks, interval=interval)
                logger.debug(f"{button}-Klick an aktueller Position")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Mausklick: {e}")
            return False
    
    def right_click(self, x=None, y=None) -> bool:
        """
        Führt einen Rechtsklick aus
        
        Args:
            x, y: Optional[int] - Koordinaten (wenn None, wird aktuelle Position verwendet)
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        return self.click(x, y, button='right')
    
    def double_click(self, x=None, y=None) -> bool:
        """
        Führt einen Doppelklick aus
        
        Args:
            x, y: Optional[int] - Koordinaten (wenn None, wird aktuelle Position verwendet)
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        return self.click(x, y, clicks=2)
    
    def click_and_drag(self, start_x, start_y, end_x, end_y, button='left', duration=0.5) -> bool:
        """
        Führt einen Klick-und-Ziehen-Vorgang aus
        
        Args:
            start_x, start_y: int - Startkoordinaten
            end_x, end_y: int - Zielkoordinaten
            button: str - 'left', 'right' oder 'middle'
            duration: float - Dauer des Ziehens
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            pyautogui.moveTo(start_x, start_y)
            pyautogui.mouseDown(button=button)
            pyautogui.moveTo(end_x, end_y, duration=duration)
            pyautogui.mouseUp(button=button)
            logger.debug(f"Drag & Drop von ({start_x}, {start_y}) nach ({end_x}, {end_y})")
            return True
        except Exception as e:
            logger.error(f"Fehler bei Drag & Drop: {e}")
            return False
    
    def scroll(self, clicks, x=None, y=None) -> bool:
        """
        Scrollt die Maus
        
        Args:
            clicks: int - Anzahl der Scrollschritte (positiv = hoch, negativ = runter)
            x, y: Optional[int] - Koordinaten (wenn None, wird aktuelle Position verwendet)
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if x is not None and y is not None:
                pyautogui.moveTo(x, y)
            
            pyautogui.scroll(clicks)
            direction = "hoch" if clicks > 0 else "runter"
            logger.debug(f"Maus {abs(clicks)} Schritte {direction} gescrollt")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Scrollen: {e}")
            return False
    
    def get_mouse_position(self) -> Optional[Tuple[int, int]]:
        """
        Gibt die aktuelle Mausposition zurück
        
        Returns:
            Tuple mit (x, y) Koordinaten oder None bei Fehler
        """
        try:
            pos = pyautogui.position()
            return (pos.x, pos.y)
        except Exception as e:
            logger.error(f"Fehler beim Abrufen der Mausposition: {e}")
            return None
    
    # ===== System-Aktionen =====
    
    def take_screenshot(self, region=None, filename=None) -> Optional[str]:
        """
        Nimmt einen Screenshot auf
        
        Args:
            region: Optional[Tuple[int, int, int, int]] - Region (x, y, width, height)
            filename: Optional[str] - Dateiname (wenn None, wird automatisch generiert)
            
        Returns:
            Pfad zum Screenshot oder None bei Fehler
        """
        try:
            if filename is None:
                # Automatischen Dateinamen generieren
                screenshots_dir = os.path.expanduser("~/Library/Application Support/MacAssistant/screenshots")
                os.makedirs(screenshots_dir, exist_ok=True)
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = os.path.join(screenshots_dir, f"screenshot_{timestamp}.png")
            
            # Screenshot aufnehmen
            if region:
                x, y, width, height = region
                screenshot = pyautogui.screenshot(region=(x, y, width, height))
            else:
                screenshot = pyautogui.screenshot()
            
            # Screenshot speichern
            screenshot.save(filename)
            logger.info(f"Screenshot gespeichert: {filename}")
            return filename
        except Exception as e:
            logger.error(f"Fehler beim Aufnehmen des Screenshots: {e}")
            return None
    
    def execute_system_command(self, command) -> Dict[str, Any]:
        """
        Führt einen Systembefehl aus
        
        Args:
            command: str - Der auszuführende Befehl
            
        Returns:
            Dict mit Ausführungsergebnissen
        """
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            
            return {
                'success': result.returncode == 0,
                'returncode': result.returncode,
                'stdout': result.stdout,
                'stderr': result.stderr
            }
        except Exception as e:
            logger.error(f"Fehler bei der Ausführung des Systembefehls '{command}': {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def run_applescript(self, script) -> Dict[str, Any]:
        """
        Führt ein AppleScript aus
        
        Args:
            script: str - Das auszuführende AppleScript
            
        Returns:
            Dict mit Ausführungsergebnissen
        """
        try:
            result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True)
            
            return {
                'success': result.returncode == 0,
                'returncode': result.returncode,
                'stdout': result.stdout.strip(),
                'stderr': result.stderr.strip()
            }
        except Exception as e:
            logger.error(f"Fehler bei der Ausführung des AppleScripts: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def toggle_system_preference(self, preference, value=None) -> bool:
        """
        Schaltet eine Systemeinstellung um
        
        Args:
            preference: str - Name der Einstellung
            value: Optional[Any] - Neuer Wert (wenn None, wird umgeschaltet)
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            # Die genaue Implementierung hängt stark von der jeweiligen Einstellung ab
            # Hier ein allgemeiner Ansatz mit AppleScript
            
            preference = preference.lower()
            
            if preference == "wifi":
                script = """
                tell application "System Preferences"
                    activate
                    set current pane to pane "com.apple.preference.network"
                end tell
                tell application "System Events"
                    tell process "System Preferences"
                        delay 0.5
                        tell window 1
                            select first row of table 1 of scroll area 1 where value of static text 1 is "Wi-Fi"
                            delay 0.2
                """
                if value is not None:
                    on_off = "check" if value else "uncheck"
                    script += f"""
                            {on_off} checkbox "Turn Wi-Fi On" of group 1
                    """
                else:
                    script += """
                            click checkbox "Turn Wi-Fi On" of group 1
                    """
                
                script += """
                        end tell
                    end tell
                end tell
                """
            
            elif preference == "bluetooth":
                script = """
                tell application "System Preferences"
                    activate
                    set current pane to pane "com.apple.preferences.Bluetooth"
                end tell
                tell application "System Events"
                    tell process "System Preferences"
                        delay 0.5
                """
                if value is not None:
                    on_off = "check" if value else "uncheck"
                    script += f"""
                        {on_off} checkbox "Turn Bluetooth On" of window 1
                    """
                else:
                    script += """
                        click checkbox "Turn Bluetooth On" of window 1
                    """
                
                script += """
                    end tell
                end tell
                """
            
            else:
                logger.warning(f"Unbekannte Systemeinstellung: {preference}")
                return False
            
            # AppleScript ausführen
            result = self.run_applescript(script)
            
            # System Preferences schließen
            self.run_applescript('tell application "System Preferences" to quit')
            
            return result['success']
        except Exception as e:
            logger.error(f"Fehler beim Umschalten der Systemeinstellung '{preference}': {e}")
            return False