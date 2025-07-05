# Intune Configuration Profile Saturation Reporter

This project provides scripts in both Python and PowerShell to automatically generate and email a device saturation report for Microsoft Intune configuration profiles. It helps administrators quickly assess the compliance status of their policies across all managed devices.

## Features

*   Connects to Microsoft Graph API using secure app-only authentication.
*   Fetches all device configuration profiles in your tenant.
*   Gathers device status counts (Succeeded, Pending, Failed, Error, Not Applicable) for each profile.
*   Generates a clean, easy-to-read HTML report.
*   Sends the report to a configurable list of email recipients via SMTP.
*   Available in both Python and PowerShell for flexibility.

---

## Prerequisites: Azure AD App Registration

Before using either script, you must register an application in Azure Active Directory to grant the necessary permissions.

1.  **Navigate to Azure Portal**: Log in to the [Azure Portal](https://portal.azure.com) and go to **Azure Active Directory** > **App registrations**.

2.  **New Registration**:
    *   Click **+ New registration**.
    *   Give it a descriptive name, like `IntunePolicyReporter`.
    *   Under "Supported account types," select **Accounts in this organizational directory only**.
    *   Click **Register**.

3.  **Get Credentials**: On the app's overview page, copy the following values. You will need them to configure the script.
    *   **Application (client) ID**
    *   **Directory (tenant) ID**

4.  **Create a Client Secret**:
    *   In your app registration, go to **Certificates & secrets** > **Client secrets**.
    *   Click **+ New client secret**.
    *   Provide a description and choose an expiry duration.
    *   **Important**: Immediately after creation, copy the secret's **Value**. This value will be hidden after you leave the page.

5.  **Grant API Permissions**:
    *   Go to **API permissions** > **+ Add a permission**.
    *   Select **Microsoft Graph**.
    *   Choose **Application permissions**.
    *   Search for and add the following permissions:
        *   `DeviceManagementConfiguration.Read.All`: Allows reading all Intune configuration policies.
        *   `Mail.Send`: Allows the application to send emails on behalf of a user or mailbox.
    *   After adding the permissions, you must grant consent. Click the **Grant admin consent for [Your Tenant]** button and confirm. The status for the permissions should change to "Granted".

---

## Setup and Usage

Choose the version of the script you wish to use.

### Python Version (`intune_reporter.py`)

This version is cross-platform and uses a `.env` file for configuration.

1.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

2.  **Configure Credentials**:
    Create a file named `.env` in the same directory as the script and populate it with your credentials.

    ```ini
    # Azure AD App Registration Details
    TENANT_ID="YOUR_TENANT_ID"
    CLIENT_ID="YOUR_CLIENT_ID"
    CLIENT_SECRET="YOUR_CLIENT_SECRET"

    # Email Configuration
    SMTP_HOST="your-smtp-server.com"
    SMTP_PORT=587
    SMTP_USER="your-smtp-username"
    SMTP_PASSWORD="your-smtp-password"
    EMAIL_FROM="intune-reports@your-domain.com"
    EMAIL_TO="admin1@your-domain.com,admin2@your-domain.com"
    ```

3.  **Run the Script**:
    ```bash
    python intune_reporter.py
    ```

### PowerShell Version (`IntunePolicyReporter.ps1`)

This version is ideal for Windows environments and is configured directly within the script file.

1.  **Configure Credentials**:
    Open `IntunePolicyReporter.ps1` in an editor (like VS Code or PowerShell ISE) and fill in the variables in the **Configuration** section at the top of the file.

2.  **Run the Script**:
    Open a PowerShell terminal, navigate to the script's directory, and run it.
    ```powershell
    .\IntunePolicyReporter.ps1
    ```
    If you encounter an error about script execution being disabled, you may need to bypass the execution policy for the current process:
    ```powershell
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
    .\IntunePolicyReporter.ps1
    ```

---

## Automation

You can schedule these scripts to run on a recurring basis to fully automate your reporting:
*   **Windows**: Use **Task Scheduler** to run the `IntunePolicyReporter.ps1` script.
*   **Linux/macOS**: Use a **cron job** to run the `intune_reporter.py` script.

## Security Note

It is critical that you **do not** commit your credentials (like the `.env` file or the populated PowerShell script) to a public or shared source control repository (e.g., GitHub).

If you are using Git, create a `.gitignore` file and add the following lines to prevent accidental commits of sensitive information:

```
.env
```