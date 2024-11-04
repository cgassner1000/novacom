# Nt.Upgrade

## Übersicht
`Nt.Upgrade` ist ein PowerShell-Skript, das entwickelt wurde, um alle `nt.payment` und `nt.fiskal` Dienste durch Eingabe von Hostnamen zu aktualisieren. Dies ist besonders nützlich für große Installationen wie bei XXXLutz, um nicht alle 400 Kassen manuell aktualisieren zu müssen.

## Voraussetzungen
- min. PowerShell 7.0.0 muss auf dem System installiert sein.
- Eine Textdatei namens `hostname.txt` muss im selben Verzeichnis wie `nt.upgrade.ps1` vorhanden sein. Diese Datei sollte die Hostnamen der Geräte enthalten, die aktualisiert werden sollen.

## Verwendung
1. **Vorbereitung**:
   - Sicherstellen, das mindestens Powershell 7.0.0 installiert ist (Unerlässlich für parallele ausführung)
   - Stellen Sie sicher, dass `nt.upgrade.ps1` und `hostname.txt` im selben Verzeichnis liegen.
   - `hostname.txt` sollte eine Liste der Hostnamen enthalten, die aktualisiert werden sollen, jeweils ein Hostname pro Zeile.

3. **Ausführung**:
   - Öffnen Sie PowerShell und navigieren Sie zu dem Verzeichnis, in dem sich `nt.upgrade.ps1` befindet.
   - Führen Sie das Skript mit folgendem Befehl aus:
     .\nt.upgrade.ps1

4. **Fehlerbehandlung**:
   - Wenn einige Hostnamen aufgrund von Unerreichbarkeit nicht aktualisiert werden können, wird eine neue Datei namens `failedhost.txt` erstellt. Diese Datei enthält eine Liste aller Hostnamen, bei denen das Update fehlgeschlagen ist.

## Beispiel für `hostname.txt`
hostname1  
hostname2  
hostname3  
