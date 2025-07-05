<#
.SYNOPSIS
    Generates a device saturation report for Microsoft Intune configuration profiles
    and sends it via email.

.DESCRIPTION
    This script connects to the Microsoft Graph API to fetch all device configuration
    profiles. For each profile, it retrieves the device status overview (succeeded,
    failed, error, pending). It then compiles this data into an HTML report and
    emails it to a specified list of administrators.

    Prerequisites:
    1. An Azure AD App Registration with the following Application permissions for Microsoft Graph:
       - DeviceManagementConfiguration.Read.All
       - Mail.Send
    2. Admin consent granted for these permissions in Azure AD.
    3. The configuration variables below must be filled out.

.NOTES
    Author: Pragna Cherukuru
    Version: 1.0
    For production environments, consider storing secrets like ClientSecret and SmtpPassword
    in a secure location like Azure Key Vault instead of plain text.
#>

# ===================================================================================
# Configuration
# ===================================================================================
# Azure AD App Registration Details (Fill these in)
$TenantID      = "YOUR_TENANT_ID"
$ClientID      = "YOUR_CLIENT_ID"
$ClientSecret  = "YOUR_CLIENT_SECRET"

# Email Configuration (Fill these in)
$SmtpServer    = "your-smtp-server.com"
$SmtpPort      = 587
$SmtpUser      = "your-smtp-username"
$SmtpPassword  = "your-smtp-password"
$EmailFrom     = "intune-reports@your-domain.com"
$EmailTo       = "admin1@your-domain.com", "admin2@your-domain.com"
# ===================================================================================


# --- Script Body ---
try {
    # Step 1: Authenticate and get Access Token
    Write-Host "Attempting to get access token..." -ForegroundColor Cyan
    $tokenUrl = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token"
    $tokenBody = @{
        client_id     = $ClientID
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
    $accessToken = $tokenResponse.access_token

    if (-not $accessToken) {
        throw "Failed to acquire access token. Check your credentials and App Registration permissions."
    }
    Write-Host "Successfully acquired access token." -ForegroundColor Green

    # Step 2: Fetch Intune Configuration Profiles and their status
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    $graphApiEndpoint = "https://graph.microsoft.com/v1.0"
    $profilesUrl = "$graphApiEndpoint/deviceManagement/deviceConfigurations"

    Write-Host "Fetching device configuration profiles..." -ForegroundColor Cyan
    $allProfiles = [System.Collections.Generic.List[psobject]]::new()
    $nextLink = $profilesUrl

    # Loop to handle paged results from Graph API
    do {
        $response = Invoke-RestMethod -Uri $nextLink -Headers $headers -Method Get -ErrorAction Stop
        $allProfiles.AddRange($response.value)
        $nextLink = $response.'@odata.nextLink'
    } while ($null -ne $nextLink)

    $profiles = $allProfiles
    Write-Host "Found $($profiles.Count) total profiles."

    $reportData = foreach ($configProfile in $profiles) {
        $profileName = $configProfile.displayName
        Write-Host "  - Getting status for '$profileName'..."
        
        $statusUrl = "$profilesUrl/$($configProfile.id)/deviceStatusOverview"
        try {
            $statusResponse = Invoke-RestMethod -Uri $statusUrl -Headers $headers -Method Get -ErrorAction Stop
            
            # Output a custom object for each profile
            [PSCustomObject]@{
                "Profile Name"   = $profileName
                "Succeeded"      = $statusResponse.successCount
                "Pending"        = $statusResponse.pendingCount
                "Failed"         = $statusResponse.failedCount
                "Error"          = $statusResponse.errorCount
                "Not Applicable" = $statusResponse.notApplicableCount
            }
        }
        catch {
            Write-Warning "Could not get status for profile '$profileName'. Error: $($_.Exception.Message)"
        }

        # Add a small delay to avoid potential API throttling on tenants with many profiles.
        Start-Sleep -Milliseconds 50
    }

    # Step 3: Generate HTML Report
    Write-Host "Generating HTML report..." -ForegroundColor Cyan
    $reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC"
    $head = @"
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; box-shadow: 0 2px 3px #ccc; }
        th, td { border: 1px solid #dddddd; text-align: left; padding: 12px; }
        th { background-color: #005A9E; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        h1 { color: #005A9E; }
    </style>
"@
    $preContent = "<h1>Intune Configuration Profile Saturation Report</h1><p>Generated on: $reportDate</p>"
    $htmlReport = $reportData | Sort-Object "Profile Name" | ConvertTo-Html -Head $head -PreContent $preContent -Title "Intune Saturation Report"

    # Step 4: Send Email
    Write-Host "Sending email report to: $($EmailTo -join ', ')" -ForegroundColor Cyan
    $securePassword = ConvertTo-SecureString $SmtpPassword -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($SmtpUser, $securePassword)
    Send-MailMessage -To $EmailTo -From $EmailFrom -Subject "Intune Policy Saturation Report - $(Get-Date -Format 'yyyy-MM-dd')" -Body $htmlReport -SmtpServer $SmtpServer -Port $SmtpPort -Credential $credential -UseSsl -BodyAsHtml
    Write-Host "Email sent successfully." -ForegroundColor Green

    Write-Host "`nReport generation complete." -ForegroundColor Green
}
catch {
    Write-Error "An unrecoverable error occurred: $($_.Exception.Message)"
}
