#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
enhanced_mac_control.py - Erweiterte Mac-Steuerung für Mac-Assistenten
Erstellt am: 2025-05-04
Änderungen:
- Initiale Implementierung der erweiterten Mac-Steuerung
- Unterstützung für Systemsteuerung in allen gängigen Anwendungen
- Implementierung von Fensternavigation und -verwaltung
- Entwicklung von Tastatur- und Mausautomatisierung
"""

import os
import time
import logging
import subprocess
import threading
import json
from typing import Dict, List, Optional, Tuple, Any, Union, Callable
from datetime import datetime
import pyautogui
import AppKit
from Quartz import (
    CGWindowListCopyWindowInfo,
    kCGWindowListOptionOnScreenOnly,
    kCGNullWindowID,
    CGWindowListCreateImage,
    CGRectNull,
    kCGWindowImageDefault
)

# Versuche, macOS-spezifische Module zu importieren
try:
    import Cocoa
    import Foundation
    import Quartz
    import PyObjCTools.AppHelper
    OBJC_AVAILABLE = True
except ImportError:
    OBJC_AVAILABLE = False
    logging.warning("PyObjC-Module nicht verfügbar. Installation empfohlen.")

logger = logging.getLogger("MacAssistant.EnhancedMacController")

class EnhancedMacController:
    """Erweiterte Mac-Steuerung für Mac-Assistenten"""
    
    def __init__(self, config=None):
        """Initialisiert den Enhanced Mac Controller"""
        self.config = config
        
        # Bildschirmgröße ermitteln
        self.update_screen_dimensions()
        logger.info(f"Bildschirmgröße erkannt: {self.width}x{self.height}")
        
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
        
        # Anwendungs-Cache für schnelleren Zugriff
        self.app_cache = {}
        self.window_cache = {}
        self.cache_lifetime = 5  # Cache-Gültigkeit in Sekunden
        self.last_cache_update = 0
        
        logger.info("Enhanced Mac Controller initialisiert")
    
    def update_screen_dimensions(self):
        """Aktualisiert die Bildschirmdimensionen"""
        try:
            # Bildschirmgröße ermitteln
            screen_size = pyautogui.size()
            self.width = screen_size.width
            self.height = screen_size.height
            
            # Mehrere Bildschirme erkennen
            if OBJC_AVAILABLE:
                screens = Cocoa.NSScreen.screens()
                if len(screens) > 1:
                    logger.info(f"Multi-Display-Setup erkannt: {len(screens)} Displays")
                    self.displays = []
                    for i, screen in enumerate(screens):
                        frame = screen.frame()
                        self.displays.append({
                            'index': i,
                            'x': frame.origin.x,
                            'y': frame.origin.y,
                            'width': frame.size.width,
                            'height': frame.size.height
                        })
                else:
                    self.displays = [{
                        'index': 0,
                        'x': 0,
                        'y': 0,
                        'width': self.width,
                        'height': self.height
                    }]
        except Exception as e:
            logger.error(f"Fehler bei der Bildschirmgrößenerkennung: {e}")
            # Standardwerte setzen
            self.width = 1280
            self.height = 800
            self.displays = [{
                'index': 0,
                'x': 0,
                'y': 0,
                'width': self.width,
                'height': self.height
            }]
    
    # ===== Anwendungs- und Fensterverwaltung =====
    
    def get_running_applications(self) -> List[Dict[str, Any]]:
        """
        Gibt eine Liste aller laufenden Anwendungen zurück
        
        Returns:
            Liste von Dictionaries mit Anwendungsinformationen
        """
        # Cache überprüfen
        current_time = time.time()
        if current_time - self.last_cache_update < self.cache_lifetime and self.app_cache:
            return self.app_cache
        
        apps = []
        try:
            if OBJC_AVAILABLE:
                workspace = Cocoa.NSWorkspace.sharedWorkspace()
                running_apps = workspace.runningApplications()
                
                for app in running_apps:
                    app_info = {
                        'name': app.localizedName(),
                        'bundle_id': app.bundleIdentifier(),
                        'pid': app.processIdentifier(),
                        'executable_url': str(app.executableURL()),
                        'icon': None,  # Icons könnten hinzugefügt werden, sind aber recht groß
                        'active': app.isActive(),
                        'hidden': app.isHidden()
                    }
                    apps.append(app_info)
            else:
                # Fallback über Terminal
                ps_command = "ps -eo pid,command | grep -v grep"
                output = subprocess.check_output(ps_command, shell=True).decode('utf-8')
                
                for line in output.split('\n'):
                    if line.strip():
                        parts = line.strip().split(maxsplit=1)
                        if len(parts) >= 2:
                            pid = parts[0]
                            command = parts[1]
                            executable = command.split()[0]
                            app_name = os.path.basename(executable)
                            
                            app_info = {
                                'name': app_name,
                                'pid': pid,
                                'command': command,
                                'active': False  # Können wir ohne PyObjC nicht genau bestimmen
                            }
                            apps.append(app_info)
            
            # Cache aktualisieren
            self.app_cache = apps
            self.last_cache_update = current_time
            
            return apps
        except Exception as e:
            logger.error(f"Fehler beim Abrufen der laufenden Anwendungen: {e}")
            return []
    
    def get_active_application(self) -> Optional[Dict[str, Any]]:
        """
        Gibt Informationen über die aktuell aktive Anwendung zurück
        
        Returns:
            Dictionary mit Informationen oder None bei Fehler
        """
        try:
            if OBJC_AVAILABLE:
                workspace = Cocoa.NSWorkspace.sharedWorkspace()
                active_app = workspace.frontmostApplication()
                
                if active_app:
                    return {
                        'name': active_app.localizedName(),
                        'bundle_id': active_app.bundleIdentifier(),
                        'pid': active_app.processIdentifier(),
                        'executable_url': str(active_app.executableURL()),
                        'active': active_app.isActive(),
                        'hidden': active_app.isHidden()
                    }
            else:
                # Fallback mit AppleScript
                script = 'tell application "System Events" to get name of first process where frontmost is true'
                output = subprocess.check_output(['osascript', '-e', script]).decode('utf-8').strip()
                
                if output:
                    return {
                        'name': output,
                        'active': True
                    }
            
            return None
        except Exception as e:
            logger.error(f"Fehler beim Abrufen der aktiven Anwendung: {e}")
            return None
    
    def get_windows(self) -> List[Dict[str, Any]]:
        """
        Gibt eine Liste aller sichtbaren Fenster zurück
        
        Returns:
            Liste von Dictionaries mit Fensterinformationen
        """
        # Cache überprüfen
        current_time = time.time()
        if current_time - self.last_cache_update < self.cache_lifetime and self.window_cache:
            return self.window_cache
        
        windows = []
        try:
            window_list = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID)
            
            for window in window_list:
                try:
                    bounds = window.get('kCGWindowBounds', {})
                    window_info = {
                        'id': window.get('kCGWindowNumber', 0),
                        'name': window.get('kCGWindowName', ''),
                        'owner_name': window.get('kCGWindowOwnerName', ''),
                        'owner_pid': window.get('kCGWindowOwnerPID', 0),
                        'bounds': {
                            'x': bounds.get('X', 0),
                            'y': bounds.get('Y', 0),
                            'width': bounds.get('Width', 0),
                            'height': bounds.get('Height', 0)
                        },
                        'alpha': window.get('kCGWindowAlpha', 1.0),
                        'is_on_screen': window.get('kCGWindowIsOnscreen', True),
                        'layer': window.get('kCGWindowLayer', 0)
                    }
                    windows.append(window_info)
                except Exception as e:
                    logger.warning(f"Fehler bei Fensterinfo: {e}")
            
            # Nach Layer sortieren (Vordergrund zuerst)
            windows.sort(key=lambda w: w['layer'])
            
            # Cache aktualisieren
            self.window_cache = windows
            self.last_cache_update = current_time
            
            return windows
        except Exception as e:
            logger.error(f"Fehler beim Abrufen der Fenster: {e}")
            return []
    
    def get_active_window(self) -> Optional[Dict[str, Any]]:
        """
        Gibt Informationen über das aktuell aktive Fenster zurück
        
        Returns:
            Dictionary mit Informationen oder None bei Fehler
        """
        try:
            windows = self.get_windows()
            
            # Das erste Fenster mit Layer 0 ist normalerweise das aktive
            for window in windows:
                if window['layer'] == 0 and window['is_on_screen']:
                    return window
            
            return None
        except Exception as e:
            logger.error(f"Fehler beim Abrufen des aktiven Fensters: {e}")
            return None
    
    def open_application(self, app_name) -> bool:
        """
        Öffnet eine Anwendung
        
        Args:
            app_name: str - Name oder Bundle-ID der Anwendung
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            # Zuerst versuchen, per NSWorkspace zu öffnen (bevorzugt)
            if OBJC_AVAILABLE:
                workspace = Cocoa.NSWorkspace.sharedWorkspace()
                
                # Prüfen, ob es eine Bundle-ID ist
                if '.' in app_name:
                    success = workspace.launchAppWithBundleIdentifier_options_additionalEventParamDescriptor_launchIdentifier_(
                        app_name,
                        Cocoa.NSWorkspaceLaunchDefault,
                        None,
                        None
                    )
                    if success:
                        logger.info(f"Anwendung geöffnet (Bundle-ID): {app_name}")
                        return True
                
                # Als Anwendungsname versuchen
                app_path = workspace.fullPathForApplication_(app_name)
                if app_path:
                    success = workspace.launchApplication_(app_path)
                    if success:
                        logger.info(f"Anwendung geöffnet: {app_name}")
                        return True
            
            # Fallback auf AppleScript
            script = f'tell application "{app_name}" to activate'
            subprocess.run(['osascript', '-e', script], check=True, capture_output=True)
            logger.info(f"Anwendung geöffnet (AppleScript): {app_name}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Öffnen der Anwendung '{app_name}': {e}")
            # Letzter Versuch mit open
            try:
                subprocess.run(['open', '-a', app_name], check=True, capture_output=True)
                logger.info(f"Anwendung geöffnet (open): {app_name}")
                return True
            except Exception as e2:
                logger.error(f"Fehler beim Öffnen mit 'open': {e2}")
                return False
    
    def close_application(self, app_name) -> bool:
        """
        Schließt eine Anwendung
        
        Args:
            app_name: str - Name oder Bundle-ID der Anwendung
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            # Versuchen, die laufende Anwendung zu finden
            if OBJC_AVAILABLE:
                workspace = Cocoa.NSWorkspace.sharedWorkspace()
                running_apps = workspace.runningApplications()
                
                for app in running_apps:
                    if app.localizedName() == app_name or app.bundleIdentifier() == app_name:
                        # Anwendung beenden
                        app.terminate()
                        logger.info(f"Anwendung geschlossen: {app_name}")
                        return True
            
            # Fallback auf AppleScript
            script = f'tell application "{app_name}" to quit'
            subprocess.run(['osascript', '-e', script], check=True, capture_output=True)
            logger.info(f"Anwendung geschlossen (AppleScript): {app_name}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Schließen der Anwendung '{app_name}': {e}")
            # Letzter Versuch mit killall
            try:
                subprocess.run(['killall', app_name], check=True, capture_output=True)
                logger.info(f"Anwendung beendet (killall): {app_name}")
                return True
            except Exception as e2:
                logger.error(f"Fehler beim Beenden mit 'killall': {e2}")
                return False
    
    def focus_application(self, app_name) -> bool:
        """
        Fokussiert eine Anwendung (bringt sie in den Vordergrund)
        
        Args:
            app_name: str - Name oder Bundle-ID der Anwendung
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if OBJC_AVAILABLE:
                workspace = Cocoa.NSWorkspace.sharedWorkspace()
                running_apps = workspace.runningApplications()
                
                for app in running_apps:
                    if app.localizedName() == app_name or app.bundleIdentifier() == app_name:
                        # Anwendung aktivieren
                        app.activateWithOptions_(Cocoa.NSApplicationActivateIgnoringOtherApps)
                        logger.info(f"Anwendung fokussiert: {app_name}")
                        return True
            
            # Fallback auf AppleScript
            script = f'tell application "{app_name}" to activate'
            subprocess.run(['osascript', '-e', script], check=True, capture_output=True)
            logger.info(f"Anwendung fokussiert (AppleScript): {app_name}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Fokussieren der Anwendung '{app_name}': {e}")
            return False
    
    def hide_application(self, app_name) -> bool:
        """
        Versteckt eine Anwendung
        
        Args:
            app_name: str - Name oder Bundle-ID der Anwendung
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if OBJC_AVAILABLE:
                workspace = Cocoa.NSWorkspace.sharedWorkspace()
                running_apps = workspace.runningApplications()
                
                for app in running_apps:
                    if app.localizedName() == app_name or app.bundleIdentifier() == app_name:
                        # Anwendung verstecken
                        app.hide()
                        logger.info(f"Anwendung versteckt: {app_name}")
                        return True
            
            # Fallback auf AppleScript
            script = f'tell application "{app_name}" to set visible to false'
            subprocess.run(['osascript', '-e', script], check=True, capture_output=True)
            logger.info(f"Anwendung versteckt (AppleScript): {app_name}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Verstecken der Anwendung '{app_name}': {e}")
            return False
    
    def show_application(self, app_name) -> bool:
        """
        Zeigt eine versteckte Anwendung an
        
        Args:
            app_name: str - Name oder Bundle-ID der Anwendung
            
        Returns:
            bool - True bei Erfolg, False bei Fehler
        """
        try:
            if OBJC_AVAILABLE:
                workspace = Cocoa.NSWorkspace.sharedWorkspace()
                running_apps = workspace.runningApplications()
                
                for app in running_apps:
                    if app.localizedName() == app_name or app.bundleIdentifier() == app_name:
                        # Anwendung anzeigen
                        app.unhide()
                        logger.info(f"Anwendung angezeigt: {app_name}")
                        return True
            
            # Fallback auf AppleScript
            script = f'tell application "{app_name}" to set visible to true'
            subprocess.run(['osascript', '-e', script], check=True, capture_output=True)
            logger.info(f"Anwendung angezeigt (AppleScript): {app_name}")
            return True
        except Exception as e:
            logger.error(f"Fehler beim Anzeigen der Anwendung '{app_name}': {e}")
            return False