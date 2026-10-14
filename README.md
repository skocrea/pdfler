# PDFler

Native macOS-App (Swift, SwiftUI, PDFKit) für die wichtigsten PDF-Aufgaben – inspiriert
vom Funktionsumfang des [PDF24 Creator](https://github.com/PDF24/PDF24-Creator), aber
eigenständig und lokal: Keine Datei verlässt deinen Mac.

| Werkzeug | Was es tut |
| --- | --- |
| **Zusammenfügen** | Beliebig viele PDFs per Drag & Drop sammeln, Reihenfolge ändern, als eine Datei speichern. |
| **Seiten löschen** | Seitenvorschau, Seiten anklicken oder als Bereich eingeben (`1, 3-5, 8-`), löschen, speichern. |
| **Komprimieren** | Stärke *Leicht / Mittel / Stark / Extrem* oder eigene Werte für Bildqualität (5–100 %) und Auflösung (50–300 DPI). Mehrere Dateien auf einmal. |

### Komprimierungsmodi

- **Text erhalten** – Text, Vektoren und Links bleiben unverändert; eingebettete Bilder
  werden mit einem Quartz-Filter (wie „Dateigröße reduzieren“ in Vorschau) neu als JPEG
  kodiert und herunterskaliert.
- **Seiten als Bilder** – jede Seite wird bei der gewählten Auflösung als JPEG neu
  aufgebaut. Größte Ersparnis bei Scans, danach ist Text aber nicht mehr markierbar.

Würde eine Datei durch die Komprimierung größer, wird automatisch das Original übernommen.

## Starten

Voraussetzung: macOS 13 (Ventura) oder neuer.

**In Xcode:** `Package.swift` öffnen (Doppelklick oder `open Package.swift`), oben das
Schema **PDFler** und „My Mac“ wählen, dann ⌘R.

**Im Terminal:**

```bash
swift run PDFler        # direkt starten
swift test                    # Tests ausführen
scripts/build-app.sh          # baut dist/PDFler.app
```

Die fertige `PDFler.app` kannst du in den Programme-Ordner ziehen.

**Fertige App aus GitHub Actions:** Jeder Push baut die App (Apple Silicon + Intel) und
hängt sie als Artefakt *PDFler* an den CI-Lauf. Da sie nur ad hoc signiert ist,
beim ersten Start Rechtsklick → *Öffnen* (oder `xattr -dr com.apple.quarantine "PDFler.app"`).

## Aufbau

```
Sources/PDFlerCore/   PDF-Logik ohne UI (zusammenfügen, Seiten löschen,
                            Seitenbereiche lesen, komprimieren) – vollständig getestet
Sources/PDFler/       SwiftUI-Oberfläche
Tests/PDFlerCoreTests XCTest mit selbst erzeugten Test-PDFs
scripts/build-app.sh        erzeugt das .app-Bundle
```

## Ideen für später (weitere PDF24-Funktionen)

- Seiten drehen, neu sortieren, extrahieren, PDF aufteilen
- Bilder → PDF und PDF → Bilder
- Texterkennung (OCR) mit Apples Vision-Framework
- Passwortschutz setzen/entfernen
- Finder-Schnellaktionen („Mit PDFler komprimieren“)
