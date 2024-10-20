/**
 * Title:  Update Platform Device Type
 * Author:  Todd Butler
 * TODO:  Logging
 *
*/

# Set Variables
$BaseURI = "https://pvwa"
$exportPath = "C:\Temp"

#$platformID = "VMWareESX-API" # Set your platformID (not the Name) here
$platformID = Read-Host "What is the Platform ID you want to modify?"
#$NewDeviceTypeName = "Operating System"  # Set the new device type here
$NewDeviceTypeName = Read-Host "What is the new Device Type name?"

$platformIDPath = "$exportPath\$platformID"
$platformIDFilePath = "$exportPath\$platformID.zip"
$xmlFilePath = "$platformIDPath\Policy-$platformID.xml" # Path to the XML file
$iniFilePath = "$platformIDPath\Policy-$platformID.ini" # Path to the INI file

# Load the PSPAS module
Import-Module pspas

#New-PASSession -BaseURI "$BaseURI" -Credential (Get-Credential)
New-PASSession -BaseURI "$BaseURI" -Credential (Get-Credential) -SkipCertificateCheck

# Step 1: Export the platform
Export-PasPlatform -PlatformID "$platformID" -path "$exportPath"

if (-Not (Test-Path "$platformIDFilePath")) {
    Write-Host "Export failed, file not found at "$platformIDFilePath""
    exit 1
}

# Step 2: Extract the compressed file
Expand-Archive -Path "$platformIDFilePath" -DestinationPath "$platformIDPath" -Force

# Load the XML content
[xml]$xmlContent = Get-Content -Path "$xmlFilePath"

# Find the 'Device' element and update the 'Name' attribute
$deviceElement = $xmlContent.Device
if ($null -ne $deviceElement) {
    $deviceElement.Name = "$NewDeviceTypeName"
    $xmlContent.Save("$xmlFilePath")
    Write-Host "Device Name updated to '$NewDeviceTypeName'."
    Write-Host "XML file updated and saved successfully."
}
else {
    Write-Host "Device Name value not found in the XML."
    exit 1
}

# Step 5: Get PolicyName from *.ini file
# Use Get-Content to read the file and Select-String to search for 'PolicyName'
$policyNameLine = Get-Content $iniFilePath | Select-String -Pattern "^PolicyName\s*=\s*(.*)"

# Extract the value using regex and display it
if ($policyNameLine) {
    $policyName = $policyNameLine.Matches[0].Groups[1].Value.Trim()
    Write-Output "PolicyName: $policyName"
}
else {
    Write-Output "PolicyName not found in the file."
}

# Step 6: Compress the files back into a zip
Compress-Archive -Path "$platformIDPath\*" -DestinationPath "$platformIDPath" -Force

# Step 7 - Delete the original platform from EPV
#$result = Get-PASPlatform | Where-Object {$_.Details.Name -eq "$policyName"}
$result = Get-PASPlatform -Search "$policyName"
Remove-PASPlatform -TargetPlatform -ID $result.Details.ID

# Step 8: Import the updated platform back into the EPV vault
Import-PasPlatform -ImportFile "$platformIDFilePath"
if ($?) {
    Write-Host "Platform imported successfully."
}
else {
    Write-Host "Import failed."
}

Close-PASSession
