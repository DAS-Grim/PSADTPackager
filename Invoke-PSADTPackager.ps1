<#
.Synopsis
    PSADT Packager Tool
.DESCRIPTION
    PSADT Packager Tool is a PowerShell script and templates written to automate the process of packaging software with the PowerShell App Deployment Toolkit in to Intune as much as possible.
.EXAMPLE
    Set-Location "$Env:OneDrive\Software Deployment\PSADT Packager"
    Invoke-PSADTPackager.ps1 -InstallerFile "C:\Users\david.sangan\OneDrive - Windward Group\Software Deployment\Microsoft\Global Secure Access Client\Install Files\GlobalSecureAccessClient.exe" -$TenantID "CONTRACT5.onmicrosoft.com"
.NOTES
    Author: David Sangan - C5 Alliance 
    Modified By: 
    Created: 1-07-2025
    Last Updated: 21-10-2025
#>

param(
    [Parameter(mandatory = $true)]
    $InstallerFile,
    [Parameter(mandatory = $true)]
    $TenantID,
    [Parameter(mandatory = $true)]
    $ClientID,
    $OutputPath,
    $AppVendor,
    $AppName,
    $AppVersion,
    $AppDetectionName,
    $AppDetectionVersion,
    $ScriptAuthorName,
    $IconPath,
    $AppDescription,
    $AppInstallArgs,
    $AppUninstallArgs,
    $AppUninstallCommand,
    $MSIProductCode,
    $Notes,
    $InstallExperience = "system",
    $CreatePackageOnly = $false,
    $UploadOnly = $false
)

# Check The specified installer file exists
If (!$(Test-Path $InstallerFile)) { Throw "The specified installer file could not be found" }

# Install required modules if not installed
If (!$(Get-Module -Name "PSAppDeployToolkit")) {
    Install-Module -Name "PSAppDeployToolkit" -Scope CurrentUser -Force
}
If (!$(Get-Module -Name "IntuneWin32App")) {
    Install-Module -Name "IntuneWin32App" -Scope CurrentUser -Force
}


# Set Installer Path for testing
# $InstallerFile = "C:\Users\david.sangan\OneDrive - Windward Group\Software Deployment\Igor Pavlov\7-Zip\Installer\7z2409-x64.msi"


# Set location to Script Root Directory
# Set-Location  "C:\Users\david.sangan\OneDrive - Windward Group\Software Deployment\PSADT Packager"
Set-Location "$PSScriptRoot"


$InstallerDir = $(Get-Item $InstallerFile).Directory.FullName
$InstallerParentDir = $(Get-Item $InstallerFile).Directory.Parent.FullName

$InstallerFileExtension = $(Get-Item $InstallerFile).Extension
If ($InstallerFileExtension -ne ".MSI" -and $InstallerFileExtension -ne ".EXE") { Throw "The specified installer file is not an MSI or EXE" }

$ISODate = $((Get-Date).ToString("yyyy-MM-dd"))

If ($InstallerFileExtension -eq ".MSI") {
    # Get Infomation from MSI
    # $MSIFileInformation = $(Get-MSIFileInformation -FilePath "C:\Users\david.sangan\OneDrive - Windward Group\Software Deployment\Oracle\MySQL ODBC\9.3.0\Files\mysql-connector-odbc-9.3.0-winx64.msi")
    $MSIFileInformation = $(Get-ADTMsiTableProperty -Path $InstallerFile)
    If (!$MSIProductCode) { $MSIProductCode = $MSIFileInformation.ProductCode }
    If (!$AppName) { $AppName = $MSIFileInformation.ProductName }
    If (!$AppVendor) { $AppVendor = $MSIFileInformation.Manufacturer }
    If ((!$AppVersion) -or ([System.Version]$MSIFileInformation.ProductVersion -gt [System.Version]$AppVersion)) { $AppVersion = $MSIFileInformation.ProductVersion }
}

# Prompt for AppVendor and AppName if not provided or detected
If (!$AppName) { $AppName = Read-Host "Please enter the Applicaiton Name" }
If (!$AppVendor) { $AppVendor = Read-Host "Please enter Application Vendor" }
If (!$AppVersion) { $AppVersion = Read-Host "Please enter the Applicaiton Version" }
If (!$AppDetectionName) { $AppDetectionName = $AppName }
If (!$AppDetectionVersion) { $AppDetectionVersion = $AppVersion }

# $OutputPath = "$((get-item "C:\Users\david.sangan\OneDrive - Windward Group\Software Deployment\PSADT Packager").Parent.FullName)"
If (!$OutputPath) { $OutputPath = "$((Get-Item $PSScriptRoot).Parent.FullName)" }
$OutputPath = "$OutputPath\$AppVendor\$AppName"
$OutputPath = $OutputPath -replace '[<>"/\|?*]', '_'
If (!$(Test-Path $OutputPath)) { New-Item -ItemType Directory -Path $OutputPath -Force }

$PSADTFolder = "$OutputPath\$AppVersion"
$PSADTInstallerFileName = $(Get-Item $InstallerFile -ErrorAction SilentlyContinue).Name
#$PSADTInstallerFileFullName = "$PSADTFolder\Files\$((Get-Item $InstallerFile -ErrorAction SilentlyContinue).Name)"
$PSADTInstallerFileBaseName = $(Get-Item $InstallerFile -ErrorAction SilentlyContinue).BaseName
$IntuneWinOut = "$OutputPath\IntuneWin"
$IntuneWinFile = "$IntuneWinOut\$PSADTInstallerFileBaseName.IntuneWin"

If (!$IconPath) { $IconPath = $(Get-ChildItem -Path "$InstallerParentDir\*" -Include logo.png, logo.jpeg, logo.JPG, icon.png, icon.jpeg, icon.JPG -Recurse -ErrorAction SilentlyContinue -Force).FullName | Select-Object -First 1 }
If (!$IconPath) { $IconPath = $(Get-ChildItem -Path "$OutputPath\*" -Include logo.png, logo.jpeg, logo.JPG, icon.png, icon.jpeg, icon.JPG -ErrorAction SilentlyContinue -Force).FullName | Select-Object -First 1 }
If (!$IconPath) { $IconPath = $(Get-ChildItem -Path "$InstallerParentDir\*" -Include *.png, *.jpeg, *.JPG -ErrorAction SilentlyContinue -Force).FullName | Select-Object -First 1 }
If (!$IconPath) { $IconPath = $(Get-ChildItem -Path "$OutputPath\*" -Include *.png, *.jpeg, *.JPG -ErrorAction SilentlyContinue -Force).FullName | Select-Object -First 1 }
If (!$IconPath) { $IconPath = "$PSScriptRoot\Templates\IconPlaceholder.png" }
If (!$DescriptionPath) { $DescriptionPath = $(Get-ChildItem -Path "$InstallerParentDir\*" -Include Description.txt -Recurse -Force).FullName | Select-Object -First 1 }
If (!$DescriptionPath) { $DescriptionPath = $(Get-ChildItem -Path "$OutputPath\*" -Include Description.txt -Force).FullName | Select-Object -First 1 }
If ($DescriptionPath) { $AppDescription = Try { Get-Content $DescriptionPath -Raw }  Catch {} }
If (!$AppDescription -and $AppName) { $AppDescription = "Installs $AppName" }
If (!$ScriptAuthorName) { $ScriptAuthorName = $(whoami /upn) }
If ($InstallExperience -eq "user") { $RequireAdmin = '$false' } else { $RequireAdmin = '$true' }

# Copy Icon and description from Installer source to out if pressent for future use
If ($(Get-Item $IconPath).Directory.FullName -ne $OutputPath) {
    Copy-Item -Path $IconPath -Destination $OutputPath -Force
}
IF ($DescriptionPath) {
    If ($(Get-Item $DescriptionPath).Directory.FullName -ne $OutputPath) {
        Copy-Item -Path $DescriptionPath -Destination $OutputPath -Force
    }
}

If (!$UploadOnly) {
    # Copy PSADT Template
    If (Test-Path $PSADTFolder) {
        try {
            Remove-Item -Path $PSADTFolder -Recurse -Force -ErrorAction Stop
        }
        catch {
            throw "$PSADTFolder exsists and could not be deleted."
        }  
    }
    # Copy-Item -Path "C:\Users\david.sangan\OneDrive - Windward Group\Clients\TGI\Projects\RM Repackerging\Templates\PSADT" -Destination $PSADTFolder -Recurse
    Copy-Item -Path "$PSScriptRoot\Templates\PSADT" -Destination $PSADTFolder -Recurse
    # Copy Install files to PSADT Files Dir
    Copy-Item -Path "$InstallerDir\*" -Destination "$PSADTFolder\Files" -Recurse #-WhatIf

    # Set Install and Uninstall Commands for EXEs
    If ($InstallerFileExtension -eq ".EXE") {
        If (!$AppInstallArgs) { $AppInstallArgs = Read-Host "Please enter the Applicaiton install Arguments for a silent install" }
        #If (!$AppUninstallArgs -and !$AppUninstallCommand) { $AppUninstallArgs = Read-Host "Please enter the Applicaiton install Arguments for a silent uninstall" }

        # Set Install Commands
        $InstallCommand = "Start-ADTProcess -FilePath '$PSADTInstallerFileName' -ArgumentList '$AppInstallArgs'"

        # Set Uninstall Commands
        If ($AppUninstallCommand) {
            $UninstallCommand = $AppUninstallCommand
        }
        ElseIf ($AppUninstallArgs) {
            $UninstallCommand = "Uninstall-ADTApplication -Name  '$PSADTInstallerFileName' -ArgumentList '$AppUninstallArgs'"
        }
        Else {
            $UninstallCommand = "Uninstall-ADTApplication -Name  '$PSADTInstallerFileName'"
        }
    }

    # Set Install and Uninstall Commands for MSIs
    If ($InstallerFileExtension -eq ".MSI") {
        # Set default MSI Arguments if not specified
        If (!$AppInstallArgs) {
            $AppInstallArgs = "/QN /norestart"
        }
        If (!$AppUninstallArgs) {
            $AppUninstallArgs = "/QN /norestart"
        }

        # Set Install Commands
        $InstallCommand = "Start-ADTMsiProcess -Action 'Install' -FilePath '$PSADTInstallerFileName' -ArgumentList '$AppInstallArgs'"

        # Set Uninstall Commands
        $UninstallCommand = "Start-ADTMsiProcess -Action 'Uninstall' -FilePath '$PSADTInstallerFileName' -ArgumentList '$AppUninstallArgs'"
    }

    # Read PSADT template Script, replace place holders and write back to the file
    $AppDeployToolkitScriptPath = "$PSADTFolder\Invoke-AppDeployToolkit.ps1"
    $AppDeployToolkitScript = Get-Content "$AppDeployToolkitScriptPath"

    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<AppVendor>", "$AppVendor"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<Name>", "$AppName"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<Version>", "$AppVersion"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<Date>", "$ISODate"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<AuthorName>", "$ScriptAuthorName"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<InstallCommand>", "$InstallCommand"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<UninstallCommand>", "$UninstallCommand"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<ShortcutInstallCommands>", "$ShortcutInstallCommands"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<ShortcutUninstallCommands>", "$ShortcutUninstallCommands"
    $AppDeployToolkitScript = $AppDeployToolkitScript -replace "<RequireAdmin>", "$RequireAdmin"

    $AppDeployToolkitScript | Out-File -FilePath "$AppDeployToolkitScriptPath" -Force

    # Read Detection template Script, replace place holders and write back to the file
    $AppDeployDetectionScriptPath = "$PSADTFolder\Detect-Application.ps1"
    $AppDeployDetectionScript = Get-Content "$AppDeployDetectionScriptPath"

    $AppDeployDetectionScript = $AppDeployDetectionScript -replace "<AppDetectionName>", "$AppDetectionName"
    $AppDeployDetectionScript = $AppDeployDetectionScript -replace "<AppDetectionVersion>", "$AppDetectionVersion"

    $AppDeployDetectionScript | Out-File -FilePath "$AppDeployDetectionScriptPath" -Force
}

If (!$CreatePackageOnly) {

    ### Run Microsoft-Win32-Content-Prep-Tool-master ####
    # Start-Process -NoNewWindow -FilePath "C:\Users\david.sangan\OneDrive - Windward Group\Clients\TGI\Projects\RM Repackerging\Microsoft-Win32-Content-Prep-Tool-master\IntuneWinAppUtil.exe" -ArgumentList "-c ""$PSADTFolder""", "-s ""Files\$AppExec""", "-o ""$OutputPath""", "-q"
    Start-Process -NoNewWindow `
        -FilePath "$PSScriptRoot\Microsoft-Win32-Content-Prep-Tool-master\IntuneWinAppUtil.exe" `
        -ArgumentList "-c `"$PSADTFolder`"", "-s `"Files\$PSADTInstallerFileName`"", "-o `"$IntuneWinOut`"", "-q" `
        -Wait

    "IntuneWin File; $IntuneWinFile"
    If ($MSIProductCode) { "MSI Product Code; $MSIProductCode" }


    ### Upload IntuneWin to Intune####
    # Connect to Custom app
    Connect-MSIntuneGraph -TenantID $TenantID -ClientID $ClientID -RedirectUri "https://login.microsoftonline.com/common/oauth2/nativeclient"

    # Create requirement rule for all platforms and Windows 10 20H2
    $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture "All" -MinimumSupportedWindowsRelease "W10_1607"

    # If MSI Product code is known create MSI detection rule with it else create place holder rule to be updated manualy later.
    if ($MSIProductCode) {
        $DetectionRule = New-IntuneWin32AppDetectionRuleMSI -ProductCode $MSIProductCode -ProductVersionOperator "greaterThanOrEqual" -ProductVersion $AppVersion
    }
    else {
        $DetectionRule = New-IntuneWin32AppDetectionRuleScript -ScriptFile $AppDeployDetectionScriptPath -RunAs32Bit $false -EnforceSignatureCheck $false   
    }

    # Prepare Icon
    If ($IconPath) {
        $Icon = New-IntuneWin32AppIcon -FilePath $IconPath
    }

    # Set defaults for required variables still null
    If (!$Notes) { $Notes = "Uploaded by $ScriptAuthorName on $ISODate" }

    # Add new Win32 app
    If ($InstallExperience -eq "user") {
        $InstallCommandLine = "Invoke-AppDeployToolkit.exe"
        $UninstallCommandLine = "Invoke-AppDeployToolkit.exe -DeploymentType Uninstall"
    }
    Else {
        $InstallCommandLine = "Invoke-AppDeployToolkit.exe"
        $UninstallCommandLine = "Invoke-AppDeployToolkit.exe -DeploymentType Uninstall"
    }

    <#
    If (Get-IntuneWin32App -DisplayName "$AppName" | Where {$_.displayVersion -eq "$AppVersion" -and $_.publisher -eq "$AppVendor"}) {
        "App $AppVendor $AppVersion $AppVersion already exsists, update exsisting deployment?"
    }
    #>

    $Win32App = Add-IntuneWin32App `
        -FilePath $IntuneWinFile `
        -DisplayName $AppName `
        -Description $AppDescription `
        -Publisher $AppVendor `
        -AppVersion $AppVersion `
        -InstallExperience $InstallExperience `
        -RestartBehavior "suppress" `
        -DetectionRule $DetectionRule `
        -RequirementRule $RequirementRule `
        -InstallCommandLine $InstallCommandLine `
        -UninstallCommandLine $UninstallCommandLine `
        -Icon $Icon `
        -Notes $Notes

    Add-IntuneWin32AppAssignmentAllUsers -ID $Win32App.id -Intent available -Notification showReboot
}