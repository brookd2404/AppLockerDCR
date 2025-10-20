<#
.SYNOPSIS
    This remediation is used to gather App Locker events and send them to a 
.DESCRIPTION
    This remediation script gathers App Locker events from the local machine, processes the data to extract relevant information, and sends it to a specified function endpoint for further analysis or action.
.NOTES
    This script requires administrative privileges to access App Locker events. The Intune Remediation should be run in the system context.

    Version: 1.0
    Author: David Brook
    GitHub: BROOKD2404

    Change History:
    Version 1.0 - Initial script creation
.LINK
    https://github.com/brookd2404/AppLockerDCR
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $dcrImmutableId = "<Your DCR Immutable ID Here>",
    [Parameter()]
    [string]
    $functionURI = "<Your Function URI Here>"
)

#Check for Null or Empty parameters
if ([string]::IsNullOrEmpty($dcrImmutableId) -or [string]::IsNullOrEmpty($functionURI)) {
    Write-Error "Both 'dcrImmutableId' and 'functionURI' parameters must be provided and cannot be null or empty."
    return
} else {
    Write-Verbose "Parameters validated. Proceeding with remediation."
    $sendURI = "$($functionURI)&DCR=$($dcrImmutableId)"
}

#Gather Entra ID Device ID
$entraDeviceID = (dsregcmd /status | Select-String "DeviceId" | ForEach-Object { $_.ToString().Split(":")[1].Trim() })

#Obtain AppLocker Events
try {
    Write-Verbose "Gathering AppLocker Events"
    $AppLockerEvents = Get-AppLockerFileInformation -EventLog -EventType Audited -Statistics
    Write-Verbose "AppLocker Events gathered: $($AppLockerEvents.Count)"
    $AppLockerArray = @()
    foreach ($App in $AppLockerEvents) {
        # Sanitise file path
        $AppPath = ($([string]$App.FilePath).Replace('%OSDRIVE%', "$env:SystemDrive"))
		
        # Check if file still is present and obtain info 
        if (Test-Path -Path $AppPath) {
            # Obtain file and audit log properties
            $AppProperties = Get-ItemProperty -Path $AppPath | Select-Object -ExpandProperty VersionInfo
            $AppEventProperties = Get-AppLockerFileInformation -Path $AppPath
			
            # Obtain file hash
            $AppFileHash = Get-FileHash -Path $AppPath -Algorithm SHA256
			
            # Set file properties formatting
            $AppPublisher = $AppEventProperties.Publisher.PublisherName
            if ([string]::IsNullOrEmpty($AppPublisher)) {
                $AppPublisher = "Unsigned"
                $AppFullPublisherDetails = "N/A"
            } elseif ($AppPublisher -match "O=") {
                $AppPublisher = $AppEventProperties.Publisher.PublisherName.Split(",")[0]
                $AppPublisher = $AppPublisher.TrimStart("O=")
                $AppFullPublisherDetails = $AppEventProperties.Publisher
            }
			
            $AppFileDescription = $($AppProperties.FileDescription)
            if ([string]::IsNullOrEmpty($AppFileDescription)) {
                $AppFileDescription = ($AppPath | Split-Path -Leaf)
            }
			
            $AppProductName = $($AppProperties.ProductName)
            if ([string]::IsNullOrEmpty($AppProductName)) {
                $AppProductName = $AppFileDescription
            }
			
            $AppProductVersion = $($AppProperties.FileVersion)
            if ([string]::IsNullOrEmpty($AppProductVersion)) {
                $AppProductVersion = "Unavailable"
            }
			
            # Obtain file monitoring count from AppLocker events
            $AppUseStatistics = $AppLockerEvents | Where-Object { $_.FilePath -eq $($App.FilePath) } | Select-Object -ExpandProperty Counter
			
            $tempapp = New-Object -TypeName PSObject
            $tempapp | Add-Member -MemberType NoteProperty -Name "Computer" -Value $env:COMPUTERNAME -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "ManagedDeviceID" -Value $ManagedDeviceID -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "FileDescription" -Value $AppFileDescription -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "FileVersion" -Value $AppProductVersion -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "ProductName" -Value $AppProductName -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "FileHash" -Value $AppFileHash -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "Publisher" -Value $AppPublisher -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "FullPublisherName" -Value $AppFullPublisherDetails -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "FileUseCount" -Value $AppUseStatistics -Force
            $tempapp | Add-Member -MemberType NoteProperty -Name "EntraDeviceID" -Value $entraDeviceID -Force
            $AppLockerArray += $tempapp
        }
    }
} catch {
    Write-Error "An error occurred while gathering AppLocker events: $_"
    return
}

#Send AppLocker Data to the Function Endpoint
try {
    Write-Verbose "Sending AppLocker data to function endpoint: $sendURI"
    $resp = Invoke-WebRequest -Uri $sendURI -Method Post -Body ($AppLockerArray | ConvertTo-Json) -ContentType "application/json"
    Write-Verbose "Data sent. Response Status Code: $($resp.StatusCode)"
    if ($resp.StatusCode -ne 200) {
        Write-Error "Failed to send data. Status Code: $($resp.StatusCode)"
    }
} catch {
    Write-Error "An error occurred while sending AppLocker data: $_"
}