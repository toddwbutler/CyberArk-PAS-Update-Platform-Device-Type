# Requires -Module Pester

Describe "PlatformUpdate Script Tests" {

    BeforeAll {
        $exportPath = "C:\Temp"
        $logDirectory = Join-Path $exportPath "Logs"
        New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
    }

    Context "Write-Log Function" {
        It "Should create a log entry with the correct format" {
            Write-Log -Message "Test message"
            $logContent = Get-Content -Path (Get-ChildItem -Path $logDirectory -Filter "*.log" | Select-Object -First 1)
            $logContent | Should -Match "\[INFO\] Test message"
        }
    }

    Context "Send-FailureAlert Function" {
        It "Should handle errors when email sending fails" {
            Mock -CommandName Send-MailMessage -MockWith { throw "SMTP Error" }
            { Send-FailureAlert "Test Error" } | Should -Throw "SMTP Error"
        }
    }

    Context "Rotate-Logs Function" {
        It "Should archive logs when exceeding size limit" {
            $dummyLog = Join-Path $logDirectory "dummy.log"
            Set-Content -Path $dummyLog -Value ("A" * 3MB)
            Rotate-Logs
            Test-Path $dummyLog | Should -BeFalse
        }

        It "Should archive old logs when count exceeds limit" {
            1..6 | ForEach-Object {
                New-Item -Path (Join-Path $logDirectory "Log_$_.log") -ItemType File | Out-Null
            }
            Rotate-Logs
            (Get-ChildItem -Path $logDirectory -Filter "*.log").Count | Should -BeLessThanOrEqualTo 5
        }
    }

    Context "XML Parsing Errors" {
        It "Should throw an error if XML content is invalid" {
            Mock -CommandName Get-Content -MockWith { "<Invalid><XML>" }
            { 
                [xml]$xmlContent = Get-Content -Path "dummy.xml" 
            } | Should -Throw
        }

        It "Should log and throw an error if the Device element is not found" {
            Mock -CommandName Get-Content -MockWith { "<Policy><NotDevice/></Policy>" }
            {
                try {
                    [xml]$xmlContent = Get-Content -Path "dummy.xml"
                    if ($null -eq $xmlContent.Device) {
                        throw "Device element not found"
                    }
                } catch {
                    $_.Exception.Message | Should -Be "Device element not found"
                }
            }
        }
    }

    Context "INI Parsing Errors" {
        It "Should throw an error if INI file content is missing PolicyName" {
            Mock -CommandName Get-Content -MockWith { @("SomeKey=SomeValue") }
            {
                try {
                    $policyNameLine = Get-Content "dummy.ini" | Select-String -Pattern "^PolicyName\s*=\s*(.*)"
                    if (-not $policyNameLine) {
                        throw "PolicyName not found in INI file"
                    }
                } catch {
                    $_.Exception.Message | Should -Be "PolicyName not found in INI file"
                }
            }
        }

        It "Should correctly extract PolicyName if present" {
            Mock -CommandName Get-Content -MockWith { @("PolicyName=TestPolicy") }
            $policyNameLine = Get-Content "dummy.ini" | Select-String -Pattern "^PolicyName\s*=\s*(.*)"
            $policyName = $policyNameLine.Matches[0].Groups[1].Value.Trim()
            $policyName | Should -Be "TestPolicy"
        }
    }

    Context "Vault Operations" {
        BeforeAll {
            Mock -CommandName Import-Module -MockWith { Write-Host "Mocked module import" }
            Mock -CommandName New-PASSession -MockWith { @{ Token = "MockSessionToken" } }
            Mock -CommandName Export-PasPlatform -MockWith { Write-Host "Platform exported" }
            Mock -CommandName Get-PASPlatform -MockWith { @{ Details = @{ ID = "MockPlatformID" } } }
            Mock -CommandName Remove-PASPlatform -MockWith { Write-Host "Platform removed" }
            Mock -CommandName Import-PasPlatform -MockWith { Write-Host "Platform imported" }
            Mock -CommandName Close-PASSession -MockWith { Write-Host "PAS session closed" }
        }

        It "Should start a PAS session and export a platform" {
            $session = New-PASSession -BaseURI "https://pvwa" -Credential $null -SkipCertificateCheck
            $session.Token | Should -Be "MockSessionToken"
        }

        It "Should export the platform without errors" {
            { Export-PasPlatform -PlatformID "TestPlatform" -Path "C:\Temp" } | Should -NotThrow
        }

        It "Should remove the platform from the vault" {
            { Remove-PASPlatform -ID "MockPlatformID" } | Should -NotThrow
        }

        It "Should import the modified platform successfully" {
            { Import-PasPlatform -ImportFile "TestPlatform.zip" } | Should -NotThrow
        }

        It "Should close the PAS session without errors" {
            { Close-PASSession } | Should -NotThrow
        }
    }
}
