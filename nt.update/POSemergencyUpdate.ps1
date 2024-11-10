# Hostnamen aus der Textdatei "hostlist.txt" laden
$hostnameList = Get-Content -Path "$PSScriptRoot\hostname.txt"
$credential = Get-Credential  # Anmeldeinformationen abfragen

$localInstallPath = "C:\install"

$sessions = @()
$failedHosts = @()

# Session erstellen
foreach ($hostname in $hostnameList) {
    try {
        $session = New-PSSession -ComputerName $hostname -Credential $credential -ThrottleLimit 500 -ErrorAction Stop
        $sessions += $session
    } catch {
        Write-Output "Host $hostname ist nicht erreichbar."
        $failedHosts += $hostname
    }
}

# Speichere die nicht erreichbaren Hostnamen in einer Datei
if ($failedHosts.Count -gt 0) {
    $failedHosts | Out-File -FilePath "$PSScriptRoot\failedhost_emergency.txt"
    Write-Output "Nicht erreichbare Hosts wurden in 'failedhost_emergency.txt' gespeichert."
}

Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath, $localInstallPath)
    $hostName = $env:COMPUTERNAME

try {
        # Prozess "KassaPreh.exe" und alle untergeordneten Prozesse beenden
        $process = Get-Process -Name "KassaPreh" -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Name "KassaPREHPrinter" -Force 
			Stop-Process -Name "KassaPrehCtrl" -Force
			Stop-Process -Name "KassaPreh" -Force 
			
            Write-Output $hostname": Prozess 'KassaPreh.exe' und alle untergeordneten Prozesse auf $hostName beendet."
        } else {
            Write-Output $hostname": Prozess 'KassaPreh.exe' auf $hostName nicht gefunden."
        }

    } catch {
        $errors += "ERROR: $_"
    }
}

Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath, $localInstallPath)
    $hostName = $env:COMPUTERNAME

try {
 
        # Stille Installation der MSI-Datei
        $msiPath = "C:\install\novatouch.pos-2024.3.9064.10541.msi"
        Start-Process msiexec.exe -ArgumentList "/i $msiPath /quiet /norestart" -Wait
        Write-Output $hostname": Installation von $msiPath auf $hostName abgeschlossen."

    } catch {
        $errors += "ERROR: $_"
    }
}

 Invoke-Command -Session $sessions -ScriptBlock {
     param ($sourcePath, $localInstallPath)
     $hostName = $env:COMPUTERNAME


 try {
 
        # Starten der "KassaPreh.exe"
		 Restart-Computer -Force
     } catch {
         $errors += "ERROR: $_"
     }
 }

Write-Host "INFO: emergency update beendet"

Remove-PSSession -Session $sessions
