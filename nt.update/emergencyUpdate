# Hostnamen aus der Textdatei "hostlist.txt" laden
$hostnameList = Get-Content -Path "$PSScriptRoot\hostname.txt"
$credential = Get-Credential  # Anmeldeinformationen abfragen

$localInstallPath = "C:\install"

$sessions = @()
$failedHosts = @()
LogMessage "onStart" $logFile

# Session erstellen
foreach ($hostname in $hostnameList) {
    try {
        $session = New-PSSession -ComputerName $hostname -Credential $credential -ThrottleLimit 500 -ErrorAction Stop
        LogMessage $hostname": Verbindung hergestellt." $logFile
        $sessions += $session
    } catch {
        Write-Output "Host $hostname ist nicht erreichbar."
        LogMessage $hostname": Hostname nicht erreichbar." $logFile
        $failedHosts += $hostname
    }
}

# Speichere die nicht erreichbaren Hostnamen in einer Datei
if ($failedHosts.Count -gt 0) {
    $failedHosts | Out-File -FilePath "$PSScriptRoot\failedhost_emergency.txt"
    Write-Output "Nicht erreichbare Hosts wurden in 'failedhost_emergency.txt' gespeichert."
    LogMessage "Nicht erreichbare Hosts wurden in 'failedhost_emergency.txt' gespeichert." $logFile
}

Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath, $localInstallPath)
    $hostName = $env:COMPUTERNAME

    try {
        # Prozess "KassaPreh.exe" beenden
        $process = Get-Process -Name "KassaPreh" -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Name "KassaPreh" -Force
            Write-Output "Prozess 'KassaPreh.exe' auf $hostName beendet."

            # Stille Installation der MSI-Datei
            $msiPath = "C:\install\novatouch.pos-2024.3.9064.10541.msi"
            Start-Process msiexec.exe -ArgumentList "/i $msiPath /quiet /norestart" -Wait
            Write-Output "Installation von $msiPath auf $hostName abgeschlossen."

            # Starten der "KassaPreh.exe"
            $exePath = "C:\Program Files (x86)\novatouch\bin\KassaPreh.exe"
            Start-Process -FilePath $exePath
            Write-Output "'KassaPreh.exe' auf $hostName gestartet."
        } else {
            Write-Output "Prozess 'KassaPreh.exe' auf $hostName nicht gefunden."
        }
    } catch {
        $errors += "ERROR: $_"
    }
}

# Warten auf alle Jobs, bis sie abgeschlossen sind
$jobs | Wait-Job

# Optional: Ergebnisse abrufen
$jobs | Receive-Job

# Alle Jobs entfernen
$jobs | Remove-Job
