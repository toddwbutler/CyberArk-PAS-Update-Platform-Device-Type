# CyberArk-PAS-Update-Platform-Device-Type
Uses Powershell module PSPAS (https://pspas.pspete.dev) to change the Platform "Device Type"

Prerequisites:
1. Powershell v5+
2. CyberArk PAS
3. Installed Powershell module ps-PAS (https://pspas.pspete.dev)

Background:
1. Sometimes situations arise where the Device Type of the platform does not accurately reflect how it is used in your environment.
2. Sometimes you download a CPM Plugin from the CyberArk Marketplace and the "Device Type" is "Imported Platform".  Renaming the Device
Type to "Operating System" or "Network Device", etc is more helpful for CyberArk admins or operators for categorization purposes.
3. You simply need a platform to be under another Device Type.

Instructions:
1. Set Variables
      $BaseURI = "https://pvwa"
      $exportPath = "C:\Temp"
2. The authentication used in the script is CyberArk authentication.  So your user needs to have a CyberArk Administrator role.
3. The first question "What is the Platform ID you want to modify?"  This is the Platform ID and not the Platform Name.  PlatformID's do not have spaces.  Platform Names can have spaces.
4. The second question asks "What is the new Device Type name"?  The choices you have are "Operating System", "Network Device", "Database", "Directory", "Website", "Application", "Misc", "Cloud Service", and "Security Applicance".  There may be others that come and go through the versions.

Internals:
Step 1:  Prompted for the PlatformID you want to update, then the new Device Type.
Step 2:  Prompted for your cyberark credentials.
Step 3:  The platform is exported into a compressed file to your $exportPath location.
Step 4:  The file is expanded to a folder by the name of the Platform.
Step 5:  The XML is edited to update the new "Device Type" value, then the INI file is queried for the Platform Name used in a step below.
Step 6:  The files are re-compressed on top of the compressed file you downloaded in step 3.
Step 7:  The original platform is deleted from EPV to make space for the newly updated platform by the same name.
Step 8:  The new platform is imported back into the vault.
Step 9:  Logoff.
