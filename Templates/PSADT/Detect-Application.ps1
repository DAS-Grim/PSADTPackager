#####################################################################################
#
#     Application Detection Wrapper: App
#     Author: David Sangan - C5 Alliance
#     Modified By: 
#     Date Packaged: 22-10-2025
#     Usage: Upload as script detection file in intune
#     Description: Script to detect the successful install of applicaiton via Intune
#
#####################################################################################


#Check Registry Keys
Function Test-Registry {
    $AppName = "<AppDetectionName>"
    $AppVersion = [System.Version]"<AppDetectionVersion>"
    $UninstallKeys = @(get-itemproperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "$([Regex]::Escape($AppName))" })[0]
    $Wow64UninstallKeys = @(get-itemproperty 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "$([Regex]::Escape($AppName))" })[0]
    #Test Registry
    try {
        if (!([System.Version]$($UninstallKeys.DisplayVersion) -ge $AppVersion) -and !([System.Version]$($Wow64UninstallKeys.DisplayVersion) -ge $AppVersion)) { return $false }
    }
    catch { return $false }
    return $true
}

if (Test-Registry) {
    #Report Successful detection
    Write-Output "App installed successefully."
    Exit 0
}
Else {
    Exit 1    
}