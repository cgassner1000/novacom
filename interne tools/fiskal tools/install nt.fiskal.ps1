# Lade die Assembly für Windows Forms
Add-Type -AssemblyName System.Windows.Forms

# Erstelle ein neues OpenFileDialog-Objekt und setze Filter und Titel
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.Filter = "ZIP files (*.zip)|*.zip"
$OpenFileDialog.Title = "Nt.Fiscal ZIP auswählen"
$OpenFileDialog.ShowHelp = $true # Dies wird benötigt, damit das Fenster im Vordergrund angezeigt wird

# Zeige den Dialog an und prüfe, ob der Benutzer eine Datei ausgewählt hat
if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $selectedNtFiscal = $OpenFileDialog.FileName
    Write-Output "Ausgewählte Datei: $selectedNtFiscal"
} else {
    Write-Output "Keine Datei ausgewählt."
    exit
}


function installNtFiscal {
    param (
        $selectedNtFiscal
    )
# Installationspfad abfragen
$installPath = Read-Host "Installationspfad angeben [C:\novacom\novatouch2\nt.services\nt.fiscal\]"
if ([string]::IsNullOrWhiteSpace($installPath)) {
    $installPath = "C:\novacom\novatouch2\nt.services\nt.fiscal\"
}
$serviceName = Read-Host "Welcher Name [nt.fiscal.[CashboxID]]?"
if ([string]::IsNullOrWhiteSpace($serviceName)) {
    $serviceName = "Nt.Fiscal"
}
$ntFiscalPort = Read-Host "Port [5010]?"
if ([string]::IsNullOrWhiteSpace($ntFiscalPort)) {
    $ntFiscalPort = 5010
}

getVersion $selectedNtFiscal

checkIfInstalled -installPath $installPath

# Überprüfen, ob der Installationspfad existiert, ansonsten erstellen
if (!(Test-Path -Path $installPath)) {
    try {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        #Write-Output "Installationsverzeichnis $installPath wurde erstellt."
    } catch {
        Write-Output "Fehler beim Erstellen des Installationspfads: $_"
        exit
    }
} else {
    #Write-Output "Installationsverzeichnis $installPath existiert bereits."
}

Expand-Archive -path $selectedNtFiscal -DestinationPath $installPath -Force

sc.exe create $serviceName binPath="$installPath\nt.fiscal $servicename" start= Auto

}

function getVersion {
    param (
        $selectedNtFiscal
    )
    if ($selectedNtFiscal -match "(\d{4}\.\d\.\d{4})") {
        $version = $matches[1]
        Write-Output "Versionsnummer: $version"
        return $version
    } else {
        Write-Output "Keine Versionsnummer gefunden."
        exit
    }
}

function updateNtFiscal {
    
}

function checkIfInstalled {
    param (
        $installPath
    )
    $filePath = Join-Path -Path $installPath -ChildPath "nt.fiscal.exe"
    
    if (Test-Path -Path $filePath) {
        $response = Read-Host "$filePath bereits vorhanden! Soll ein Update durchgeführt werden? (Y/N)"
        if ($response -eq 'Y') {
            updateNtFiscal -installPath $installPath -FilePath $filePath
        } else {
            exit
        }
    } else {
        return
    }
}

installNtFiscal -selectedNtFiscal $selectedNtFiscal

checkIfInstalled $installPath

$shouldUpdate = checkIfInstalled -installPath $installPath

if ($shouldUpdate) {
    #Update-NtFiscal
    Write-Host "Update-Routine"
} else {
    installNtFiscal -selectedNtFiscal $selectedNtFiscal
}





