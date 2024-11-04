# Hostnamen aus der Textdatei "hostlist.txt" laden
$hostnameList = Get-Content -Path "$PSScriptRoot\hostlist.txt"
#$credential = Get-Credential  # Anmeldeinformationen abfragen
$sourcePath = "\\10.10.16.239\c$\install\novacom\2024.3\2024.3.9064\Nt.Services\*"  # Pfad zum Quellordner auf dem Server
$sourcePath = "\\10.1.80.11\c$\nc-install\Nt.Services\*"
$destinationPath = "C$\install"
$localInstallPath = "C:\install"

# Anmeldeinformationen festlegen
 $Username = "admin.nvc"
 $Password = 'n0V60$01nc' | ConvertTo-SecureString -AsPlainText -Force
 $credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)
#

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
#

# Speichere die nicht erreichbaren Hostnamen in einer Datei
if ($failedHosts.Count -gt 0) {
    $failedHosts | Out-File -FilePath "$PSScriptRoot\failedhost.txt"
    Write-Output "Nicht erreichbare Hosts wurden in 'failedhost.txt' gespeichert."
}


Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath, $localInstallPath)

    $hostName = $env:COMPUTERNAME

    # Verzeichnis erstellen, falls es nicht existiert
    if (-Not (Test-Path -Path $localInstallPath)) {
        New-Item -ItemType Directory -Path $localInstallPath -Force
    }
    
} -ArgumentList $sourcePath, $localInstallPath


#################################################### Zip übertragen START
$hostnameList | ForEach-Object -Parallel {
    $client = $_
    Write-Output "Verbinde zu: $client"
    $destinationPath = "C$\install"
    $sourcePath = "\\10.10.16.239\c$\install\novacom\2024.3\2024.3.9064\Nt.Services*"

    $Username = "admin.nvc"
    $Password = 'n0V60$01nc' | ConvertTo-SecureString -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($Username, $Password)



    try {
        # Netzlaufwerk verbinden und Anmeldedaten angeben
        New-PSDrive -Name "RemoteDrive" -PSProvider FileSystem -Root "\\$client\$destinationPath" -Credential $credential -ErrorAction Stop

        # Dateien auf das verbundene Netzlaufwerk kopieren
        Copy-Item -Path $sourcePath -Destination "RemoteDrive:\" -Force -Recurse
        Write-Output $client": Dateien kopiert"
        
        # Netzlaufwerk entfernen
        Remove-PSDrive -Name "RemoteDrive"
    } catch {
        Write-Output "Fehler beim Verbinden oder Kopieren auf $client : $_"
        $failedHosts += $client
    }
}
#################################################### Zip übertragen END

################################################### STOP,KILL,UPDATE SERVICE START
Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath, $localInstallPath)
    $hostName = $env:COMPUTERNAME
    $paymentDienste =@()
    $fiskalDienste = @()
    $paymentDienste = Get-Service | Where-Object { $_.Name -match 'nt.payment' -or $_.Name -match 'Nt.Payment' -or $_.Name -match 'NT.PAYMENT' -or $_.Name -match 'NT.payment' }
    $fiskalDienste = Get-Service | Where-Object { $_.Name -match 'nt.fiscal' -or $_.Name -match 'Nt.Fiscal' -or $_.Name -match 'NT.FISCAL' -or $_.Name -match 'NT.fiscal' }

    $ntService = @()
    $alleNtDienste = @()
	$alleNtDienste += $paymentDienste
	$alleNtDienste += $fiskalDienste

    Write-host
    Write-Host $hostName": Alle NtDienste: "$alleNtDienste
    Write-Host $hostName": PaymentDienste: "$paymentDienste
    Write-Host $hostName": FiskalDienste: "$fiskalDienste
    Write-Host
	
	#$paymentDienste + $fiskalDienste
	
	#$script:alleNtDienste = $alleNtDienste
    foreach ($ntService in $alleNtDienste) {
        Write-Host $hostName": ntService: "(Get-Service -Name $ntService.Name)$ntService
        try {
            Stop-Service -Name $ntService.Name -Force
            $allStopped = $false
            while (-not $allStopped) {
                $allStopped = $true
                foreach ($ntService in $alleNtDienste) {
                    if ((Get-Service -Name $ntService.Name).Status -ne 'Stopped') {
                        Stop-Service -Name $ntService.Name -Force
                        #$allStopped = $false
                        Start-Sleep -Seconds 0.1
                        break
                    }
                }
            }
            
            Write-Host $hostName": $($ntService.Name) gestoppt"

            
            if ($paymentDienste.Name -contains $ntService.Name) {
                $paymentConfigPath = (Get-WmiObject -Class Win32_Service -Filter "Name='$($ntService.Name)'").PathName
                $paymentExePath = $paymentConfigPath -replace '^(.*\.exe).*$', '$1'
                $paymentPath = $paymentExePath -replace '\\[^\\]+$','\'
                Write-Host $hostName": PAYMENT Entferne "$($ntService.Name)
                Remove-Item -Path "$paymentPath\*" -Recurse -Force
                Write-Host $hostName": PAYMENT Entpacke "$($ntService.Name)
                Get-ChildItem -Path "$localInstallPath" -Filter "nt.payment*.zip" | ForEach-Object {
                    $zipFilePath = $_.FullName
                    Expand-Archive -Path $zipFilePath -DestinationPath $paymentPath -Force
                }
            }
            
            if ($fiskalDienste.Name -contains $ntService.Name) {
                $fiskalConfigPath = (Get-WmiObject -Class Win32_Service -Filter "Name='$($ntService.Name)'").PathName
                $fiskalExePath = $fiskalConfigPath -replace '^(.*\.exe).*$', '$1'
                $fiskalPath = $fiskalExePath  -replace '\\[^\\]+$','\'
                #Write-Host "Fiskal Dienst: $fiskalPath"
                Write-Host $hostName": FISKAL Entferne "$($ntService.Name)
                Remove-Item -Path "$fiskalPath\*" -Recurse -Force
                Write-Host $hostName": FISKAL Entpacke "$($ntService.Name)

                Get-ChildItem -Path "$localInstallPath" -Filter "nt.fiscal*.zip" | ForEach-Object {                 #ändern für lutz! "$localInstallPath\Nt.Services\"
                    $zipFilePath = $_.FullName
                    Expand-Archive -Path $zipFilePath -DestinationPath $fiskalPath -Force
                }

            }
        } catch {
            $errors += "Fehler beim Verarbeiten von Nt.Service: $_"
        }
        Write-Host $hostName": $($ntService.Name) upgedated"
    }

    
} -ArgumentList $sourcePath, $localInstallPath
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
Write-Host

# Versionsnummern ausgeben und vergleichen
Invoke-Command -Session $sessions -ScriptBlock {
    param ($sourcePath)
    $sourcePath = "C:\install\"
    $hostName = $env:COMPUTERNAME
    
    # Versionsnummern aus den ZIP-Dateinamen extrahieren
 
    $paymentZipVersion = (Get-ChildItem -Path "$sourcePath" -Filter "nt.payment*.zip").Name -replace '.*nt.payment_(.*)_win7-x64.zip', '$1'
    $fiscalZipVersion = (Get-ChildItem -Path "$sourcePath" -Filter "nt.fiscal*.zip").Name -replace '.*nt.fiscal_(.*)_win7-x64.zip', '$1'

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
} -ArgumentList $sourcePath
Write-Host "INFO: update beendet"

Remove-PSSession -Session $sessions
