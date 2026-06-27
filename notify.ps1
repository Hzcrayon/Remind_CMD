#Requires -Version 5.1
# Remind Tool - é€šçŸ¥è§¦å‘è„šæœ¬ï¼ˆç”±è®¡åˆ’ä»»åŠ¡è°ƒç”¨ï¼‰
param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$Title,
    [Parameter(Mandatory = $true)][string]$Message,
    [string]$ScheduledTime = ''
)

$ErrorActionPreference = 'SilentlyContinue'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $ScriptRoot 'RemindToolData'
$RemindersFile = Join-Path $DataDir 'reminders.json'
$ConfigFile = Join-Path $ScriptRoot 'remind.config.json'
$TaskPrefix = 'RemindTool_'

function Get-NotifyConfig {
    $defaults = @{
        appDisplayName = 'Remind Tool'
        soundEnabled   = $true
        playSound      = 'ms-winsoundevent:Notification.Reminder'
    }
    if (Test-Path $ConfigFile) {
        try {
            $cfg = Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($key in $defaults.Keys) {
                if ($cfg.PSObject.Properties.Name -contains $key) {
                    $defaults[$key] = $cfg.$key
                }
            }
        }
        catch { }
    }
    return $defaults
}

function Remove-ReminderEntry {
    param([string]$ReminderId)
    if (Test-Path $RemindersFile) {
        try {
            $items = ConvertTo-ReminderArray -Items (Get-Content $RemindersFile -Raw -Encoding UTF8 | ConvertFrom-Json)
            $items = @($items | Where-Object { $_.id -ne $ReminderId })
            $items | ConvertTo-Json -Depth 5 | Set-Content $RemindersFile -Encoding UTF8
        }
        catch { }
    }
    $taskName = "$TaskPrefix$ReminderId"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

function ConvertTo-ReminderArray {
    param($Items)
    if ($null -eq $Items) { return @() }
    $result = @()
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        if ($item -is [System.Array]) {
            $result += ConvertTo-ReminderArray -Items $item
            continue
        }
        $props = @($item.PSObject.Properties.Name)
        if ($props -contains 'id') {
            $result += $item
            continue
        }
        if ($props -contains 'value') {
            $result += ConvertTo-ReminderArray -Items $item.value
        }
    }
    return @($result)
}

$config = Get-NotifyConfig
$appName = [string]$config.appDisplayName
$displayTitle = $Title
$displayMessage = $Message

try {
    if (-not [string]::IsNullOrWhiteSpace($ScheduledTime)) {
        $scheduledAt = [datetime]::ParseExact($ScheduledTime, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture)
        $delay = (Get-Date) - $scheduledAt
        if ($delay.TotalSeconds -ge 60) {
            $displayTitle = 'Missed reminder'
            $displayMessage = "Missed at $($scheduledAt.ToString('yyyy-MM-dd HH:mm:ss')): $Message"
        }
    }
}
catch { }

function Show-BalloonNotification {
    param(
        [string]$AppName,
        [string]$NotificationTitle,
        [string]$NotificationMessage
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
        $notifyIcon.Text = $AppName
        $notifyIcon.Visible = $true
        $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        $notifyIcon.BalloonTipTitle = $NotificationTitle
        $notifyIcon.BalloonTipText = $NotificationMessage
        $notifyIcon.ShowBalloonTip(10000)

        Start-Sleep -Seconds 12
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        return $true
    }
    catch {
        return $false
    }
}

function Show-ToastNotification {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue | Out-Null
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $safeTitle = [System.Security.SecurityElement]::Escape($displayTitle)
        $safeMessage = [System.Security.SecurityElement]::Escape($displayMessage)
        if (-not $safeTitle) { $safeTitle = $appName }
        if (-not $safeMessage) { $safeMessage = 'Reminder time is up' }

        $soundTag = ''
        if ($config.soundEnabled) {
            $soundTag = '<audio src="' + [string]$config.playSound + '"/>'
        }

        $xmlContent = '<toast activationType="foreground"><visual><binding template="ToastGeneric"><text>' +
            $safeTitle + '</text><text>' + $safeMessage + '</text></binding></visual>' +
            $soundTag + '</toast>'

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($xmlContent)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appName).Show($toast)
        return $true
    }
    catch {
        return $false
    }
}

function Show-SystemMessage {
    param(
        [string]$NotificationTitle,
        [string]$NotificationMessage
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            $NotificationMessage,
            $NotificationTitle,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button1,
            [System.Windows.Forms.MessageBoxOptions]::ServiceNotification
        ) | Out-Null
        return $true
    }
    catch {
        try {
            msg * "$NotificationTitle - $NotificationMessage" 2>$null
            return $true
        }
        catch {
            return $false
        }
    }
}
$toastShown = Show-ToastNotification
$messageShown = Show-SystemMessage -NotificationTitle $displayTitle -NotificationMessage $displayMessage
$balloonShown = Show-BalloonNotification -AppName $appName -NotificationTitle $displayTitle -NotificationMessage $displayMessage

if (-not $balloonShown -and -not $toastShown -and -not $messageShown) {
    [System.Media.SystemSounds]::Exclamation.Play()
}

Remove-ReminderEntry -ReminderId $Id


