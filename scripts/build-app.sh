#!/usr/bin/env bash
# Baut "dist/PDF Werkstatt.app". Mit UNIVERSAL=1 für Apple Silicon und Intel.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
  ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

swift build -c release --product PDFWerkstatt ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

APP="dist/PDF Werkstatt.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/PDFWerkstatt" "$APP/Contents/MacOS/PDFWerkstatt"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
  <key>CFBundleExecutable</key><string>PDFWerkstatt</string>
  <key>CFBundleIdentifier</key><string>de.skocrea.pdfwerkstatt</string>
  <key>CFBundleName</key><string>PDF Werkstatt</string>
  <key>CFBundleDisplayName</key><string>PDF Werkstatt</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc-Signatur, damit macOS die App lokal startet.
codesign --force --sign - "$APP"
echo "Fertig: $APP"
