#!/bin/bash
# 
# create_app_icon.sh - Konvertiert SVG-Icon in ICNS und verschiedene Größen
# Erstellt am: 2025-05-04
# Änderungen:
# - Initialer Script für SVG zu ICNS-Konvertierung
# - Automatische Generierung der verschiedenen Icon-Größen für macOS
#

# Konstanten
SVG_PATH="../resources/icons/AppIcon.svg"
ICON_DIR="../resources/icons"
ICONSET_DIR="${ICON_DIR}/AppIcon.iconset"
ICNS_PATH="${ICON_DIR}/AppIcon.icns"

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

# Prüfen, ob das SVG existiert
if [ ! -f "${SVG_PATH}" ]; then
    log_error "SVG-Icon nicht gefunden: ${SVG_PATH}"
    exit 1
fi

# Prüfen, ob Konvertierungstools installiert sind
if ! command -v inkscape &> /dev/null && ! command -v rsvg-convert &> /dev/null && ! command -v convert &> /dev/null; then
    log_error "Kein SVG-Konvertierungstool gefunden. Bitte installiere Inkscape, librsvg oder ImageMagick."
    exit 1
fi

# iconutil überprüfen
if ! command -v iconutil &> /dev/null; then
    log_error "iconutil nicht gefunden. Dieses Tool ist Teil von macOS und wird für die ICNS-Konvertierung benötigt."
    exit 1
fi

# Iconset-Verzeichnis erstellen
log_status "Iconset-Verzeichnis erstellen..."
mkdir -p "${ICONSET_DIR}"

# Funktion zum Konvertieren von SVG in PNG
function convert_svg_to_png {
    local size=$1
    local output=$2
    
    if command -v inkscape &> /dev/null; then
        inkscape --export-filename="${output}" -w ${size} -h ${size} "${SVG_PATH}" > /dev/null 2>&1
    elif command -v rsvg-convert &> /dev/null; then
        rsvg-convert -w ${size} -h ${size} "${SVG_PATH}" -o "${output}" > /dev/null 2>&1
    elif command -v convert &> /dev/null; then
        convert -background none -resize ${size}x${size} "${SVG_PATH}" "${output}" > /dev/null 2>&1
    else
        return 1
    fi
    
    return $?
}

# Icon-Größen für macOS
# Format: Größe, Dateiname
ICON_SIZES=(
    "16,icon_16x16.png"
    "32,icon_16x16@2x.png"
    "32,icon_32x32.png"
    "64,icon_32x32@2x.png"
    "128,icon_128x128.png"
    "256,icon_128x128@2x.png"
    "256,icon_256x256.png"
    "512,icon_256x256@2x.png"
    "512,icon_512x512.png"
    "1024,icon_512x512@2x.png"
)

# Alle Größen konvertieren
log_status "Icon in verschiedene Größen konvertieren..."
for ICON_SIZE_PAIR in "${ICON_SIZES[@]}"; do
    size=$(echo $ICON_SIZE_PAIR | cut -d ',' -f 1)
    filename=$(echo $ICON_SIZE_PAIR | cut -d ',' -f 2)
    output_path="${ICONSET_DIR}/${filename}"
    
    log_status "Konvertiere ${size}x${size}px Icon: ${filename}"
    convert_svg_to_png $size $output_path
    
    if [ $? -ne 0 ]; then
        log_error "Konvertierung fehlgeschlagen für ${size}x${size}px"
        exit 1
    fi
done

# ICNS-Datei erstellen
log_status "ICNS-Datei erstellen..."
iconutil --convert icns --output "${ICNS_PATH}" "${ICONSET_DIR}"

if [ $? -ne 0 ]; then
    log_error "ICNS-Erstellung fehlgeschlagen."
    exit 1
else
    log_success "ICNS-Datei erfolgreich erstellt: ${ICNS_PATH}"
fi

# PNG-Versionen erstellen für Verwendung in der App
log_status "PNG-Versionen des Icons erstellen..."
SIZES=(16 32 64 128 256 512 1024)

for size in "${SIZES[@]}"; do
    output_path="${ICON_DIR}/app_icon_${size}x${size}.png"
    log_status "Erstelle ${size}x${size}px PNG-Icon"
    convert_svg_to_png $size $output_path
    
    if [ $? -ne 0 ]; then
        log_warning "Konvertierung fehlgeschlagen für PNG ${size}x${size}px"
    fi
done

# Aufräumen
log_status "Aufräumen..."
rm -rf "${ICONSET_DIR}"

log_success "App-Icon-Erstellung abgeschlossen."
exit 0