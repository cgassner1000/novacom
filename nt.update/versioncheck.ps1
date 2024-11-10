$hostnameList = Get-Content -Path "$PSScriptRoot\hostname.txt"
$credential = Get-Credential  # Anmeldeinformationen abfragen
$expectedVersion = Read-Host "Erwartete Fiskal/Payment Version (zb. 2024.3.9064)"
$sessions = @()
$failedHosts = @()
$results = @()

if ($expectedVersion -eq "") {
    $expectedVersion = "2024.4.9064"
}

# Session erstellen
foreach ($hostname in $hostnameList) {
    try {
        $session = New-PSSession -ComputerName $hostname -Credential $credential -ThrottleLimit 500 -ErrorAction Stop
        #LogMessage "$hostname: Verbindung hergestellt." $logFile
        $sessions += $session
    } catch {
        #Write-Output "Host $hostname ist nicht erreichbar."
        #LogMessage "$hostname: Hostname nicht erreichbar." $logFile
        $failedHosts += $hostname
        # Zeile für nicht erreichbaren Host hinzufügen
        $results += [PSCustomObject]@{
            Hostname = $hostname
            NtPayment = ""
            NtFiscal = ""
            NtPOS = ""
            Status = "ERROR"
        }
    }
}

# Speichere die nicht erreichbaren Hostnamen in einer Datei
if ($failedHosts.Count -gt 0) {
    $failedHosts | Out-File -FilePath "$PSScriptRoot\failedhost.txt"
    #Write-Output "Nicht erreichbare Hosts wurden in 'failedhost.txt' gespeichert."
    #LogMessage "Nicht erreichbare Hosts wurden in 'failedhost.txt' gespeichert." $logFile
}

Write-Host "INFO: Erstelle Tabelle..."

# Führe den Befehl auf den Remote-Hosts aus und erfasse die Ausgabe
$commandResults = Invoke-Command -Session $sessions -ScriptBlock {
    param ($expectedVersion)
    $hostName = $env:COMPUTERNAME

    $paymentDienste = @(Get-Service | Where-Object { $_.Name -match 'nt.payment' -or $_.Name -match 'Nt.Payment' -or $_.Name -match 'NT.PAYMENT' -or $_.Name -match 'NT.payment' })
    $fiskalDienste = @(Get-Service | Where-Object { $_.Name -match 'nt.fiscal' -or $_.Name -match 'Nt.Fiscal' -or $_.Name -match 'NT.FISCAL' -or $_.Name -match 'NT.fiscal' })

    $ntService = @()
    $alleNtDienste = @($paymentDienste) + @($fiskalDienste)

    $paymentVersion = ""
    $fiscalVersion = ""
    $posVersion = ""

    foreach ($ntService in $alleNtDienste) {
        try {
            $servicePath = (Get-WmiObject -Class Win32_Service -Filter "Name='$($ntService.Name)'").PathName
            $exePath = $servicePath -replace '^(.*\.exe).*$', '$1'
            $versionInfo = (Get-Item $exePath).VersionInfo
            $serviceVersion = ($versionInfo.ProductVersion -split '\.')[0..2] -join '.'

            if ($ntService.Name -like "nt.payment*") {
                $paymentVersion = $serviceVersion
            } elseif ($ntService.Name -like "nt.fiscal*") {
                $fiscalVersion = $serviceVersion
            } elseif ($ntService.Name -like "nt.pos*") {
                $posVersion = $serviceVersion
            }
        } catch {
            Write-Host "Fehler beim Abrufen der Versionsnummer für $($ntService.Name): $_"
        }
    }

        # Abruf der Version von NovaTouch POS aus den installierten Programmen
        try {
            $posProgram = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "NovaTouch POS" }
            if ($posProgram) {
                $posVersion = $posProgram.Version
            } else {
                $posVersion = "Nicht installiert"
            }
        } catch {
            Write-Host "Fehler beim Abrufen der Version für NovaTouch POS: $_"
            $posVersion = "Unbekannt"
        }


    # Status festlegen
    $status = if ($paymentVersion -eq $expectedVersion -and $fiscalVersion -eq $expectedVersion -and $posVersion -eq $expectedVersion) { 
        "OK" 
    } elseif ($paymentVersion -ne $expectedVersion -or $fiscalVersion -ne $expectedVersion -or $posVersion -ne $expectedVersion) {
        "MISSMATCH"
    } else {
        "ERROR"
    }

    # Ergebnis als Objekt zurückgeben
    [PSCustomObject]@{
        Hostname = $hostName
        NtPayment = $paymentVersion
        NtFiscal = $fiscalVersion
        NtPOS = $posVersion
        Status = $status
    }
} -ArgumentList $expectedVersion

# Ergebnis zur lokalen $results-Liste hinzufügen
$results += $commandResults

# Tabelle in eine Textdatei schreiben
$results | Format-Table -AutoSize
$results | Format-Table -AutoSize | Out-File -FilePath "$PSScriptRoot\CheckVersion.txt"
$results | Export-Csv -Path "$PSScriptRoot\CheckVersion.csv" -NoTypeInformation -Encoding UTF8


Write-Host "INFO: Die CheckVersion-Ergebnisse wurden in 'CheckVersion.txt' und 'CheckVersion.csv' gespeichert."

# Sitzung schließen
Remove-PSSession -Session $sessions
