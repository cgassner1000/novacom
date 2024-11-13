### INSTALL TOOL NOVACOM ###

Param (
    #[Parameter(Mandatory=$true)]
    [string]$mode,    # Nur dieser Parameter ist mandatory
    [string]$source
)
$expectedMsiFiles = @("novatouch.control", "novatouch.pos", "novatouch.oman.sol", "novatouch.voucher")
$nt2ExpectedServiceFiles = @("nt.fiscal", "nt.booking.svs", "nt.os.server", "nt.payment")
$nt3ExpectedServiceFiles = @("nt.server.suite")

Clear-Host
Write-Host "----------------------"
Write-Host "|\| () \/ /\ ( () |\/|"
Write-Host "----------------------"
Write-Host 
function mainMenu {
    Write-Host "### Auswahlmenü ###"
    Write-Host "1: Update ausführen"
    Write-Host "2: Version überprüfen"
    Write-Host ""
    Write-Host "q: Beenden"
    Write-Host
}

function GetNtBuildNumber {
    param (
        [Parameter(Mandatory = $true)]
        [String] $fileName
    )
    
    if ([string]::IsNullOrEmpty($fileName)) {
        Write-Host "File name is empty or null. Skipping."
        return ""
    }
    
    # Look for the version number pattern in the file name
    $versionMatch = $fileName -match "\d+\.\d+\.\d+"
    
    if ($versionMatch) {
        $version = $matches[0].Split(".")[2]        
        return $version
    }
    else {
        return ""
    }
}

function update {
    Write-Host "Update wird ausgeführt..."
    $source = Read-Host "Source-Pfad angeben:"
    $msiZipXmlFiles = Get-ChildItem -Path $source  -File | Where-Object { $_.Extension -eq '.zip' -or $_.Extension -eq '.msi' -or $_.Extension -eq '.xml' }

    foreach ($file in $msiZipXmlFiles) {
        $buildNumber = GetNtBuildNumber -fileName $file.Name
        
        if ($buildNumber -eq "") {
            continue
        }
        
        if ($lastBuildNumber -eq "") {
            Write-Host "Setting build number $( $file.Name) '$buildNumber'"
            $lastBuildNumber = $buildNumber
        }
        if ($lastBuildNumber -ne $buildNumber) {
            # LogMessage "Error: Different file versions found" $logFile
            # LogMessage "Quitting script..." $logFile
            Write-Host "Quitting script... $lastBuildNumber -ne $buildNumber"
            exit
        }    
    }
    ### DEPLOY MSI ###
    Write-Host "loop through each MSI file and install..."
    $msiFiles = Get-ChildItem -Path $source -Filter "*.msi" -File
    foreach ($msiFile in $msiFiles) {
        foreach ($serviceFile in $expectedMsiFiles) {
            if ($msiFile -like "$($serviceFile)*") {
                #LogMessage "Installing $($msiFile.FullName)..." $logFile
                Start-Process msiexec.exe -ArgumentList "/i $($msiFile.FullName) /passive /norestart /qn /l*v" -Wait
                #LogMessage "Installed $($msiFile.FullName)" $logFile
            }
        }
    }

    ### DEPLOY ZIP ###
    Write-Host "handle zip files and install"
    $zipFiles = Get-ChildItem -Path $source -Filter "*.zip" -File
    foreach ($zipFile in $zipFiles) {
           
        #deploy nt2 services
        foreach ($serviceFile in $nt2ExpectedServiceFiles) {
            if ($zipFile -like "$($serviceFile)*") {
                #LogMessage "Install service $($serviceFile)" $logFile

                $directoryPath = "$($nt2ServiceDir)\$($serviceFile)"

                # Check if the directory exists, create if it doesn't
                if (-not (Test-Path -Path $directoryPath -PathType Container)) {
                    New-Item -Path $directoryPath -ItemType Directory | Out-Null
                    LogMessage "Directory created: $directoryPath" $logFile
                }            


            }
        }
    }
    # deploy nt3 server suite
    foreach ($serviceFile in $nt3ExpectedServiceFiles) {
        if ($zipFile -like "$($serviceFile)*") {
            $buildNumber = ""
            if (Test-Path -Path "$nt3ServiceDir\apps\nt3-server-suite\version.txt") {
                $firstLineVersion = Get-Content -Path "$nt3ServiceDir\apps\nt3-server-suite\version.txt" -TotalCount 1
                $currentFileVersion = GetNtBuildNumber -fileName $firstLineVersion
                
                $currentFileVersion = $firstLineVersion.Split(".")

                if ($currentFileVersion.Count -le 3) {
                    continue
                }
                $buildNumber = $currentFileVersion[2]
            }
            if ($lastBuildNumber -ne $buildNumber) {
                LogMessage "Copy $nt3ServiceDir" $logFile
                #robocopy $extractedDestination $nt3ServiceDir /MIR
                xcopy /DEY $extractedDestination $nt3ServiceDir
                LogMessage "Install Python requirements" $logFile
                Start-Process "$IRISBASEDIR\bin\irispip.exe" -ArgumentList "install", "-r", "$nt3ServiceDir\apps\nt3-server-suite\requirements.txt" -Wait -PassThru
            }
        }
    }















    Write-Host "reading server.suite config..."
    $processName = "python"
    $pythoncommandLine = (Get-WmiObject Win32_Process -Filter "name = '$($processName).exe'").CommandLine
    $rootdirValue = $pythoncommandLine -match '--rootdir (.*?) --' | Out-Null
    $rootdirValue = $matches[1]
    Write-Output "Server.Suite rootdir: $($rootdirValue)"

    # Extrahieren der ZIP-Datei in das "rootdir"
    Expand-Archive -Path $source\nt.server.suite-$serverSuiteOnlineVersionOutput.zip -DestinationPath $rootdirValue -Force



    endFunction
}

function versionCheck {
    Write-Host "VersionCheck wird ausgeführt"
    endFunction
}

function endFunction {
    Write-Host "Vorgang abgeschlossen. Drücken Sie die Eingabetaste, um zum Hauptmenü zurückzukehren."
    Read-Host
}

# Hauptprogramm
do {
    mainMenu
    $mode = Read-Host "Bitte eine Auswahl treffen"

    switch ($mode) {
        "1" { update }
        "2" { versionCheck }
        "q" { Write-Output "Programm wird beendet."; break }
        default { Write-Output "Ungültige Auswahl, bitte erneut versuchen." }
    }

} while ($mode -ne "q")