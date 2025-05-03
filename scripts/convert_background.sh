#!/bin/bash
# 
# convert_background.sh - Konvertiert SVG-Hintergrund in PNG für DMG
# Erstellt am: 2025-05-04
# Änderungen:
# - Initialer Script für SVG zu PNG-Konvertierung
# - Automatische Generierung des PNG-Hintergrunds mit der richtigen Auflösung
#

# Konstanten
SVG_PATH="../resources/dmg_background.svg"
PNG_PATH="../resources/dmg_background.png"
RESOLUTION="800x400"

# Farben für Statusmeldungen
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funktion für Statusmeldungen
function log_status {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function log_success {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function log_warning {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function log_error {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Überprüfen, ob Inkscape oder rsvg-convert installiert ist
if command -v inkscape &> /dev/null; then
    log_status "Verwende Inkscape für die Konvertierung..."
    inkscape --export-filename="${PNG_PATH}" -w 800 -h 400 "${SVG_PATH}"
    RESULT=$?
elif command -v rsvg-convert &> /dev/null; then
    log_status "Verwende rsvg-convert für die Konvertierung..."
    rsvg-convert -w 800 -h 400 "${SVG_PATH}" -o "${PNG_PATH}"
    RESULT=$?
elif command -v convert &> /dev/null; then
    log_status "Verwende ImageMagick convert für die Konvertierung..."
    convert -background none -size ${RESOLUTION} "${SVG_PATH}" "${PNG_PATH}"
    RESULT=$?
else
    log_error "Kein SVG-Konvertierungstool gefunden. Bitte installiere Inkscape, librsvg oder ImageMagick."
    exit 1
fi

# Prüfen, ob die Konvertierung erfolgreich war
if [ $RESULT -eq 0 ] && [ -f "${PNG_PATH}" ]; then
    log_success "Hintergrundbild erfolgreich konvertiert: ${PNG_PATH}"
    log_status "Auflösung: ${RESOLUTION}"
    exit 0
else
    log_error "Konvertierung fehlgeschlagen."
    exit 1
fi