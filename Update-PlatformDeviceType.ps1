<#
.SYNOPSIS
   Update the Device Type of a specific platform in the EPV vault with logging, log rotation, and email alerts on failure.
.DESCRIPTION
   This script exports a platform, modifies its device type, and re-imports it back to the vault. 
   It includes logging with log rotation and sends email alerts on critical failures.
#>

# Variables
$BaseURI = "https://pvwa"
$exportPath = "C:\Temp"
$logDirectory = Join-Path $exportPath "Logs"
$logFile = Join-Path $logDirectory "PlatformUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$archiveLogFile = Join-Path $logDirectory "OldLogs_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"

# Email Config
$smtpServer = "smtp.yourserver.com"
$smtpPort = 587
$emailFrom = "admin@yourdomain.com"
$emailTo = "alerts@yourdomain.com"
$emailSubjectFailure = "Critical Error: Platform Update Script Failed"
$emailBodyTemplateFailure = @"
A critical error occurred while executing the Platform Update script.

Error Details:
{0}
See the attached log file for more information.
"@

# Log Rotation Config
$maxLogCount = 5
$maxLogSizeMB = 2

function Write-Log {
    param ([string]$message, [string]$level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$level] $message"
    Add-Content -Path $logFile -Value $logEntry
    Write-Host $logEntry
}

function Send-FailureAlert {
    param ([string]$errorDetails)
    $body = $emailBodyTemplateFailure -f $errorDetails
    try {
        Send-MailMessage -From $emailFrom -To $emailTo -Subject $emailSubjectFailure `
                         -Body $body -SmtpServer $smtpServer -Port $smtpPort -UseSsl `
                         -Attachments $logFile -ErrorAction Stop
        Write-Log "Failure alert email sent."
    } catch {
        Write-Log "Failed to send email: $_" -Level "ERROR"
    }
}

function Rotate-Logs {
    $logFiles = Get-ChildItem -Path $logDirectory -Filter "*.log" | Sort-Object LastWriteTime -Descending
    foreach ($log in $logFiles) {
        if (($log.Length / 1MB) -ge $maxLogSizeMB) {
            Compress-Archive -Path $log.FullName -DestinationPath $archiveLogFile -Force
            Remove-Item -Path $log.FullName -Force
        }
    }
    if ($logFiles.Count -ge $maxLogCount) {
        $oldLogs = $logFiles[$maxLogCount..($logFiles.Count - 1)]
        Compress-Archive -Path $oldLogs.FullName -DestinationPath $archiveLogFile -Force
        $oldLogs | ForEach-Object { Remove-Item -Path $_.FullName -Force }
    }
}

function Update-Platform {
    param ($platformID, $newDeviceTypeName)
    Rotate-Logs
    Write-Log "Platform ID: $platformID, New Device Type: $newDeviceTypeName"
    try {
        Import-Module pspas -ErrorAction Stop
        $session = New-PASSession -BaseURI $BaseURI -Credential (Get-Credential) -SkipCertificateCheck
        Export-PasPlatform -PlatformID $platformID -Path $exportPath
        Write-Log "Platform exported."

        $platformIDPath = Join-Path $exportPath $platformID
        Expand-Archive -Path "$platformIDPath.zip" -DestinationPath $platformIDPath -Force
        [xml]$xmlContent = Get-Content -Path (Join-Path $platformIDPath "Policy-$platformID.xml")
        $xmlContent.Device.Name = $newDeviceTypeName
        $xmlContent.Save((Join-Path $platformIDPath "Policy-$platformID.xml"))
        Write-Log "Device type updated."

        Compress-Archive -Path "$platformIDPath\*" -DestinationPath "$platformIDPath.zip" -Force
        Remove-PASPlatform -ID (Get-PASPlatform -Search $newDeviceTypeName).Details.ID
        Import-PasPlatform -ImportFile "$platformIDPath.zip"
        Write-Log "Platform updated successfully."
    } catch {
        Write-Log "Error: $_" -Level "ERROR"
        Send-FailureAlert $_
    } finally {
        Close-PASSession
    }
}
