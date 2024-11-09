# Hostnamen aus der Textdatei "hostlist.txt" laden
$hostnameList = Get-Content -Path "$PSScriptRoot\hostname.txt"
$credential = Get-Credential  # Anmeldeinformationen abfragen
#$sourcePath = "\\10.10.16.239\c$\install\novacom\2024.3\2024.3.9064\Nt.Services\*"  # Pfad zum Quellordner auf dem Server
$sourcePath = "\\10.1.80.11\c$\nc-install\Nt.Services\"
#$destinationPath = "C$\install"
$localInstallPath = "C:\install"
$paymentZIPvorhanden = $false
$fiskalZIPvorhanden = $false

$currentFormattedDate = Get-Date -Format "yyyy-MM-dd"
if ($logFileDir -eq "") {
    $logFileDir = "$PSScriptRoot\logs"
}

$logFile = "$PSScriptRoot\upgrade.log"

function LogMessage {
    param (        
        [String] $message = "",
        [String] $logFile = ""
    )
    $iso8601DateTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffffffzzz"
    $message = "$iso8601DateTime $message"
    Write-Host $message
    if ([string]::IsNullOrEmpty($logFile)) {
        exit
    }
    $message | Out-File -FilePath $logFile -Append     
}

function HandleLogFiles {
    param (        
        [String] $logFileDir = "",
        [String] $logFile = ""
    )
    if ([string]::IsNullOrEmpty($logFileDir)) {
        exit
    }
}


# Überprüfen, ob die Dateien im Quellordner vorhanden sind
if (Test-Path -Path "$sourcePath\nt.payment*.zip") {
    $paymentZIPvorhanden = $true
}
if (Test-Path -Path "$sourcePath\nt.fiscal*.zip") {
    $fiskalZIPvorhanden = $true
}


# Anmeldeinformationen festlegen
# $Username = "admin.nvc"
# $Password = 'n0V60$01nc' | ConvertTo-SecureString -AsPlainText -Force
# $credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
#

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
#

# Speichere die nicht erreichbaren Hostnamen in einer Datei
if ($failedHosts.Count -gt 0) {
    $failedHosts | Out-File -FilePath "$PSScriptRoot\failedhost.txt"
    Write-Output "Nicht erreichbare Hosts wurden in 'failedhost.txt' gespeichert."
    LogMessage "Nicht erreichbare Hosts wurden in 'failedhost.txt' gespeichert." $logFile
}


Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath, $localInstallPath)  # Sicherstellen, dass der Parameter $logMessage korrekt benannt ist
    
    $hostName = $env:COMPUTERNAME

    # LogMessage aufrufen, den korrekten Parameter verwenden
    #logMessage "Überprüfe Verzeichnis '$localInstallPath'." $logFile
    
    # Verzeichnis erstellen, falls es nicht existiert
    if (-Not (Test-Path -Path $localInstallPath)) {
        New-Item -ItemType Directory -Path $localInstallPath -Force
        # LogMessage für die Erstellung des Verzeichnisses aufrufen
        #logMessage "Verzeichnis '$localInstallPath' wurde erstellt." $logFile
    }
} -ArgumentList $sourcePath, $localInstallPath



#################################################### Zip übertragen START
#$hostnameList | ForEach-Object -Parallel {
#    $client = $_
#    Write-Output "Verbinde zu: $client"
#     try {
#        # Netzlaufwerk verbinden und Anmeldedaten angeben
#        New-PSDrive -Name "RemoteDrive" -PSProvider FileSystem -Root "\\$client\$using:destinationPath" -Credential $using:credential -ErrorAction Stop
#
#        # Dateien auf das verbundene Netzlaufwerk kopieren
#        Copy-Item -Path "$using:sourcePath\*" -Destination "RemoteDrive:\" -Force -Recurse
#        Write-Output $client": Dateien kopiert"
#        
#        # Netzlaufwerk entfernen
#        Remove-PSDrive -Name "RemoteDrive"
#    } catch {
#        Write-Output "Fehler beim Verbinden oder Kopieren auf $client : $_"
#        $failedHosts += $client
#    }
#}
#################################################### Zip übertragen END

################################################### STOP,KILL,UPDATE SERVICE START
Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath, $localInstallPath, $paymentZIPvorhanden, $fiskalZIPvorhanden)
    $hostName = $env:COMPUTERNAME

    $paymentDienste = @(Get-Service | Where-Object { $_.Name -match 'nt.payment' -or $_.Name -match 'Nt.Payment' -or $_.Name -match 'NT.PAYMENT' -or $_.Name -match 'NT.payment' })
    $fiskalDienste = @(Get-Service | Where-Object { $_.Name -match 'nt.fiscal' -or $_.Name -match 'Nt.Fiscal' -or $_.Name -match 'NT.FISCAL' -or $_.Name -match 'NT.fiscal' })

    $ntService = @()
    $alleNtDienste = @()
	
	$alleNtDienste = @($paymentDienste)+@($fiskalDienste)

    Write-host
    Write-Host $hostName": Alle NtDienste: "$alleNtDienste
    Write-Host $hostName": Alle NtDienste Count: "($alleNtDienste).Count
    Write-Host $hostName": PaymentDienste: "$paymentDienste
    Write-Host $hostName": FiskalDienste: "$fiskalDienste
    Write-Host
	
	#$paymentDienste + $fiskalDienste
	
	#$script:alleNtDienste = $alleNtDienste
# Array für die Jobs erstellen
$jobs = @()

foreach ($ntService in $alleNtDienste) {
    try {
        # Job starten, um den Dienst zu stoppen
        $jobs += Start-Job -ScriptBlock {
            param ($serviceName)
            $hostName = $env:COMPUTERNAME

            Write-Host $hostname": STOP SERVICE: $serviceName"
            Stop-Service -Name $serviceName -Force
            
            # Warten, bis der Dienst gestoppt ist
            while ((Get-Service -Name $serviceName).Status -ne 'Stopped') {
                Start-Sleep -Seconds 0.1
            }
            
            Write-Host $hostname": STOP SERVICE: $serviceName > OK"
        } -ArgumentList $ntService.Name
    } catch {
        $errors += "ERROR: Fehler beim Verarbeiten von Nt.Service: $_"
    }
}

# Warten auf alle Jobs, bis sie abgeschlossen sind
$jobs | Wait-Job

# Optional: Ergebnisse abrufen
$jobs | Receive-Job

# Alle Jobs entfernen
$jobs | Remove-Job

    foreach ($ntService in $alleNtDienste) {        
        try {    
            if ($paymentZIPvorhanden) {
                if ($paymentDienste.Name -contains $ntService.Name) {
                    $paymentPath = Split-Path -Path ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($ntService.Name)" -Name "ImagePath").ImagePath) #-replace '\"(.*?)\".*', '$1' -replace '(.*?) .*', '$1')
                    #Write-Host $hostName": PAYMENT Entferne "$($ntService.Name)
                    #Write-Host $hostName": PAYMENT Path: "$paymentPath
                    #Remove-Item -Path "$paymentPath\*" -Recurse -Force
                    Write-Host $hostName": PAYMENT Entpacke "$($ntService.Name)
                    Get-ChildItem -Path "$localInstallPath" -Filter "nt.payment*.zip" | ForEach-Object {
                        $zipFilePath = $_.FullName
                        Expand-Archive -Path $zipFilePath -DestinationPath $paymentPath -Force
                    }
                }
            }
            if ($fiskalZIPvorhanden) {
                if ($fiskalDienste.Name -contains $ntService.Name) {
                    $fiskalPath = Split-Path -Path ((Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($ntService.Name)" -Name "ImagePath").ImagePath) #-replace '\"(.*?)\".*', '$1' -replace '(.*?) .*', '$1')
                    #Write-Host $hostName": FISKAL Entferne "$($ntService.Name)
                    #Write-Host $hostName": FISKAL Path: "$fiskalPath
                    #Remove-Item -Path "$fiskalPath\*" -Recurse -Force
                    Write-Host $hostName": FISKAL Entpacke "$($ntService.Name)
                    Get-ChildItem -Path "$localInstallPath" -Filter "nt.fiscal*.zip" | ForEach-Object {                
                        $zipFilePath = $_.FullName
                        Expand-Archive -Path $zipFilePath -DestinationPath $fiskalPath -Force
                    }
                }
            }
        } catch {
            $errors += "ERROR: Fehler beim Verarbeiten von Nt.Service: $_"
        }
        Write-Host $hostName": $($ntService.Name) upgedated"
    } 
} -ArgumentList $sourcePath, $localInstallPath, $paymentZIPvorhanden, $fiskalZIPvorhanden
################################################### STOP, KILL, UPDATE SERVICE END

Invoke-Command -Session $sessions -ScriptBlock {
    $hostName = $env:COMPUTERNAME
    foreach ($ntService in $script:alleNtDienste) {
        try {
            Write-Host $hostName": Starte "$ntService.Name
            Start-Service -Name $ntService.Name 
            $allStarted = $false
            while (-not $allStarted) {
                $allStarted = $true
                foreach ($ntService in $alleNtDienste) {
                    if ((Get-Service -Name $ntService.Name).Status -ne 'Running') {
                        Start-Service -Name $ntService.Name
                        $allStarted = $false
                        Start-Sleep -Seconds 0.1
                        break
                    }
                }
            }



        } catch {
            $errors += "Fehler beim starten der Dienste"
        }
        Write-Host $hostname": $($ntService.Name) gestartet"
    }

}

$paymentZipVersion = (Get-ChildItem -Path "$sourcePath" -Filter "nt.payment*.zip").Name -replace '.*?nt\.payment_(.*?)_win.*', '$1'
$fiscalZipVersion = (Get-ChildItem -Path "$sourcePath" -Filter "nt.fiscal*.zip").Name -replace '.*?nt\.fiscal_(.*?)_win.*', '$1'
Write-Host
Write-Host "Expected Payment Version: "$paymentZipVersion
Write-Host "Expected Fiskal Version:  "$fiscalZipVersion
Write-Host
# Versionsnummern ausgeben und vergleichen
Invoke-Command -Session $sessions -ScriptBlock {
    param ($localInstallPath)
    $sourcePath = "C:\install\"
    $hostName = $env:COMPUTERNAME
    
    # Versionsnummern aus den ZIP-Dateinamen extrahieren
 
    $paymentZipVersion = (Get-ChildItem -Path "$localInstallPath" -Filter "nt.payment*.zip").Name -replace '.*?nt\.payment_(.*?)_win.*', '$1'
    $fiscalZipVersion = (Get-ChildItem -Path "$localInstallPath" -Filter "nt.fiscal*.zip").Name -replace '.*?nt\.fiscal_(.*?)_win.*', '$1'

    foreach ($ntService in $script:alleNtDienste) {
        try {
            $servicePath = (Get-WmiObject -Class Win32_Service -Filter "Name='$($ntService.Name)'").PathName
            $exePath = $servicePath -replace '^(.*\.exe).*$', '$1'
            $versionInfo = (Get-Item $exePath).VersionInfo
            $serviceVersion = $versionInfo.ProductVersion

            if ($ntService.Name -like "nt.payment*") {
                if ($serviceVersion -eq $paymentZipVersion) {
                    Write-Host $hostName": $($ntService.Name) Version: $serviceVersion" -ForegroundColor Green
                } else {
                    Write-Host $hostName": $($ntService.Name) Version: $serviceVersion" -ForegroundColor Red
                }
            } elseif ($ntService.Name -like "nt.fiscal*") {
                if ($serviceVersion -eq $fiscalZipVersion) {
                    Write-Host $hostName": $($ntService.Name) Version: $serviceVersion" -ForegroundColor Green
                } else {
                    Write-Host $hostName": $($ntService.Name) Version: $serviceVersion" -ForegroundColor Red
                }
            }
        } catch {
            Write-Host "Fehler beim Abrufen der Versionsnummer für $($ntService.Name): $_"
        }
    }
} -ArgumentList $localInstallPath
Write-Host "INFO: update beendet"

Remove-PSSession -Session $sessions
