#copy to local
$swAuslieferungRoot = "T:\builds"
$lokalDestinationPath = 
$archiv = "archiv"
$alpha = "alpha"
$beta = "beta"
$stable = "stable"
$excludeFolder = @("nt.fiscal.service_setup", "nt.legacy")
$userName = $env:UserName


$ntVersion = Get-ChildItem -Path "T:\builds\nt.control\alpha\" -Filter "*.msi" | Select-Object -ExpandProperty Name | ForEach-Object { GetNtBuildNumber -fileName $_ }
Write-Host $ntVersion
#
$modules = Get-ChildItem -Path $swAuslieferungRoot -Directory
#

# foreach ($module in $modules) {
#     #check alpha path, to ensure that there are files to move
#     $alphaSourcePath = Join-Path -Path $module.FullName -ChildPath $alpha
    
#     # Check if there are files in the alpha directory
#     if (Get-ChildItem -Path $alphaSourcePath -File) {
#         $betaSourcePath = Join-Path -Path $module.FullName -ChildPath $beta
#         $betaDestinationPath = Join-Path -Path $module.FullName -ChildPath "$beta\$archiv"

#         # Ensure the destination directory exists
#         if (-not (Test-Path -Path $betaDestinationPath)) {
#             New-Item -ItemType Directory -Path $betaDestinationPath
#         }

#     # Move all files from source to destination
#     Get-ChildItem -Path $betaSourcePath -File | Where-Object { $excludeFolders -notcontains $_.Name } | Move-Item -Destination $betaDestinationPath -Force
#     }
# }

# # COPY ALPHA
# foreach ($module in $modules) {
    
#     $alphaSourcePath = Join-Path -Path $module.FullName -ChildPath $alpha
#     $alphaDestinationPath = Join-Path -Path $module.FullName -ChildPath $beta

#     # Ensure the destination directory exists
#     if (-not (Test-Path -Path $alphaDestinationPath)) {
#         New-Item -ItemType Directory -Path $alphaDestinationPath
#     }

#     # Move all files from source to destination
#     Get-ChildItem -Path $alphaSourcePath -File | Where-Object { $excludeFolders -notcontains $_.Name } | Copy-Item -Destination $alphaDestinationPath -Force
# }

function GetNtBuildNumber {
    param (
        [Parameter(Mandatory = $false)]
        [String] $fileName
    )
    
    if ([string]::IsNullOrEmpty($fileName)) {
        Write-Host "File name is empty or null. Skipping."
        return ""
    }
    
    # Look for the version number pattern in the file name
    $versionMatch = $fileName -match "\d+\.\d+\.\d+"
    
    if ($versionMatch) {
        $fullVersion = $matches[1]
        $majorVersion = $matches[2]
        return [PSCustomObject]@{
            FullVersion = $fullVersion
            MajorVersion = $majorVersion
        }
    }
    else {
        return [PSCustomObject]@{
            FullVersion = ""
            MajorVersion = ""
        }
    }
}
