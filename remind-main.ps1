#Requires -Version 5.1
<#
.SYNOPSIS
    Remind Tool - Windows reminder utility
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Script:ToolName      = 'RemindTool'
$Script:ToolVersion   = '1.0.0'
$Script:ScriptRoot    = $PSScriptRoot
$Script:ConfigFile    = Join-Path $ScriptRoot 'remind.config.json'
$Script:DataDir       = Join-Path $ScriptRoot 'RemindToolData'
$Script:RemindersFile = Join-Path $Script:DataDir 'reminders.json'
$Script:NotifyScript  = Join-Path $ScriptRoot 'notify.ps1'
$Script:NotifyRunner  = Join-Path $ScriptRoot 'run-notify-hidden.vbs'
$Script:TaskPrefix    = 'RemindTool_'

function Get-DefaultConfig {
    @{
        version        = $Script:ToolVersion
        appDisplayName = 'Remind Tool'
        soundEnabled   = $true
        playSound      = 'ms-winsoundevent:Notification.Reminder'
        dataDirectory  = $Script:DataDir
    }
}

function Read-Config {
    if (-not (Test-Path $Script:ConfigFile)) {
        return Get-DefaultConfig
    }
    try {
        $cfg = Get-Content -Path $Script:ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $defaults = Get-DefaultConfig
        foreach ($key in $defaults.Keys) {
            if (-not ($cfg.PSObject.Properties.Name -contains $key)) {
                $cfg | Add-Member -NotePropertyName $key -NotePropertyValue $defaults[$key] -Force
            }
        }
        return $cfg
    }
    catch {
        return Get-DefaultConfig
    }
}

function Ensure-DataDirectory {
    if (-not (Test-Path $Script:DataDir)) {
        New-Item -ItemType Directory -Path $Script:DataDir -Force | Out-Null
    }
}

function Read-Reminders {
    Ensure-DataDirectory
    if (-not (Test-Path $Script:RemindersFile)) {
        return @()
    }
    try {
        $raw = Get-Content -Path $Script:RemindersFile -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return @()
        }
        $parsed = ConvertFrom-Json -InputObject $raw
        return ConvertTo-ReminderArray -Items $parsed
    }
    catch {
        return @()
    }
}

function Save-Reminders {
    param([array]$Reminders)
    Ensure-DataDirectory
    $payload = @(ConvertTo-ReminderArray -Items $Reminders | Where-Object {
        $null -ne $_ -and $_.PSObject.Properties.Name -contains 'id'
    })
    if (@($payload).Count -eq 0) {
        '[]' | Set-Content -Path $Script:RemindersFile -Encoding UTF8
        return
    }
    ConvertTo-Json -InputObject @($payload) -Depth 5 | Set-Content -Path $Script:RemindersFile -Encoding UTF8
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

function Test-InPath {
    param([string]$Directory)
    $paths = ($env:PATH -split ';') | ForEach-Object { $_.TrimEnd('\') }
    $target = $Directory.TrimEnd('\')
    return ($paths -contains $target)
}

function Install-RemindTool {
    Write-Host ''
    Write-Host "  Remind Tool v$Script:ToolVersion - Install" -ForegroundColor Cyan
    Write-Host ('  ' + ('=' * 40)) -ForegroundColor DarkGray
    Write-Host ''

    Ensure-DataDirectory

    if (-not (Test-Path $Script:ConfigFile)) {
        $defaultConfig = Get-DefaultConfig
        $defaultConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $Script:ConfigFile -Encoding UTF8
        Write-Host '  [OK] Created remind.config.json' -ForegroundColor Green
    }
    else {
        Write-Host '  [OK] Config file exists' -ForegroundColor Green
    }

    if (-not (Test-Path $Script:RemindersFile)) {
        '[]' | Set-Content -Path $Script:RemindersFile -Encoding UTF8
        Write-Host "  [OK] Created data directory: $Script:DataDir" -ForegroundColor Green
    }
    else {
        Write-Host "  [OK] Data directory exists: $Script:DataDir" -ForegroundColor Green
    }

    if (-not (Test-Path $Script:NotifyScript)) {
        Write-Host '  [!!] Missing notify.ps1 - ensure all tool files are present' -ForegroundColor Red
    }
    else {
        Write-Host '  [OK] Notification script ready' -ForegroundColor Green
    }

    if (-not (Test-Path $Script:NotifyRunner)) {
        Write-Host '  [!!] Missing run-notify-hidden.vbs - hidden notification runner unavailable' -ForegroundColor Red
    }
    else {
        Write-Host '  [OK] Hidden notification runner ready' -ForegroundColor Green
    }

    if (Test-InPath -Directory $Script:ScriptRoot) {
        Write-Host "  [OK] Script folder is in PATH: $Script:ScriptRoot" -ForegroundColor Green
    }
    else {
        Write-Host '  [!!] Script folder is NOT in PATH yet' -ForegroundColor Yellow
        Write-Host '       Add this folder to your PATH environment variable:' -ForegroundColor Yellow
        Write-Host "       $Script:ScriptRoot" -ForegroundColor White
        Write-Host ''
        Write-Host '       Optional command (user PATH):' -ForegroundColor DarkGray
        $setxHint = 'setx PATH "%PATH%;' + $Script:ScriptRoot + '"'
        Write-Host "       $setxHint" -ForegroundColor DarkGray
    }

    Write-Host ''
    Write-Host '  Done! Try: remind 5m "test reminder"' -ForegroundColor Cyan
    Write-Host '  Help:   remind help' -ForegroundColor DarkGray
    Write-Host ''
}

function Show-Help {
    Write-Host ''
    Write-Host "  Remind Tool v$Script:ToolVersion - Windows Reminder Utility" -ForegroundColor Cyan
    Write-Host ('  ' + ('=' * 44)) -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Usage:' -ForegroundColor Yellow
    Write-Host '    remind TIME MESSAGE          Create a relative-time reminder'
    Write-Host '    remind at TIME MESSAGE       Create an absolute-time reminder'
    Write-Host '    remind list                  List pending reminders'
    Write-Host '    remind cancel ID             Cancel one reminder'
    Write-Host '    remind cancel all            Cancel all reminders'
    Write-Host '    remind install               Initialize / install the tool'
    Write-Host '    remind help                  Show this help'
    Write-Host ''
    Write-Host '  Relative time:' -ForegroundColor Yellow
    Write-Host '    30s          30 seconds'
    Write-Host '    5m / 5min    5 minutes'
    Write-Host '    1h           1 hour'
    Write-Host '    1h20m        1 hour 20 minutes'
    Write-Host '    1h20min      same as above'
    Write-Host '    1d           1 day'
    Write-Host '    1:30         1 hour 30 minutes'
    Write-Host '    90m          90 minutes'
    Write-Host ''
    Write-Host '  Absolute time:' -ForegroundColor Yellow
    Write-Host '    remind at 15:30 "meeting"              Today at 15:30'
    Write-Host '    remind at 2025-06-28 09:00 "submit"    Specific date and time'
    Write-Host ''
    Write-Host '  Examples:' -ForegroundColor Yellow
    Write-Host '    remind 1h "wake up"'
    Write-Host '    remind 1h20m "drink water"'
    Write-Host '    remind 30m "take a break"'
    Write-Host '    remind at 18:00 "leave work"'
    Write-Host '    remind list'
    Write-Host '    remind cancel abc12345'
    Write-Host ''
    Write-Host '  Notes:' -ForegroundColor DarkGray
    Write-Host '    - Uses Windows Task Scheduler; works after closing CMD'
    Write-Host '    - Shows Windows Toast notifications when triggered'
    Write-Host "    - Data stored in $Script:DataDir"
    Write-Host ''
}

function Parse-RelativeDuration {
    param([string]$DurationText)

    $text = $DurationText.Trim().ToLower()
    $text = $text -replace '\s+', ''

    if ($text -match '^(\d+):(\d{1,2})$') {
        $hours = [int]$Matches[1]
        $minutes = [int]$Matches[2]
        return [TimeSpan]::FromMinutes($hours * 60 + $minutes)
    }

    if ($text -match '^(\d+)h(\d+)(?:m|min)?$') {
        return [TimeSpan]::FromMinutes([int]$Matches[1] * 60 + [int]$Matches[2])
    }

    $pattern = '(?:(\d+)d)?(?:(\d+)h)?(?:(\d+)m(?:in)?|(\d+)min)?(?:(\d+)s)?'
    if ($text -notmatch "^$pattern`$") {
        throw "Cannot parse duration: $DurationText"
    }

    $days    = if ($Matches[1]) { [int]$Matches[1] } else { 0 }
    $hours   = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
    $minutes = if ($Matches[3]) { [int]$Matches[3] } elseif ($Matches[4]) { [int]$Matches[4] } else { 0 }
    $seconds = if ($Matches[5]) { [int]$Matches[5] } else { 0 }

    if ($days -eq 0 -and $hours -eq 0 -and $minutes -eq 0 -and $seconds -eq 0) {
        throw "Duration must be greater than zero: $DurationText"
    }

    return New-TimeSpan -Days $days -Hours $hours -Minutes $minutes -Seconds $seconds
}

function Parse-AbsoluteTime {
    param([string]$TimeText)

    $text = $TimeText.Trim()
    $formats = @(
        'yyyy-MM-dd HH:mm',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy/MM/dd HH:mm',
        'HH:mm',
        'H:mm'
    )

    foreach ($fmt in $formats) {
        $culture = [System.Globalization.CultureInfo]::InvariantCulture
        $styles = [System.Globalization.DateTimeStyles]::None
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact($text, $fmt, $culture, $styles, [ref]$parsed)) {
            if ($fmt -match '^H') {
                $now = Get-Date
                $parsed = Get-Date -Year $now.Year -Month $now.Month -Day $now.Day `
                    -Hour $parsed.Hour -Minute $parsed.Minute -Second 0
                if ($parsed -le $now) {
                    $parsed = $parsed.AddDays(1)
                }
            }
            return $parsed
        }
    }

    throw "Cannot parse absolute time: $TimeText"
}

function Format-TimeSpanHuman {
    param([TimeSpan]$Span)
    $parts = @()
    if ($Span.Days -gt 0)    { $parts += "$($Span.Days)d" }
    if ($Span.Hours -gt 0)   { $parts += "$($Span.Hours)h" }
    if ($Span.Minutes -gt 0) { $parts += "$($Span.Minutes)m" }
    if ($Span.Seconds -gt 0 -and $Span.TotalMinutes -lt 1) { $parts += "$($Span.Seconds)s" }
    if ($parts.Count -eq 0) { return 'less than 1 minute' }
    return ($parts -join ' ')
}

function New-ShortId {
    return ([guid]::NewGuid().ToString('N')).Substring(0, 8)
}

function Register-ReminderTask {
    param(
        [string]$Id,
        [string]$Title,
        [string]$Message,
        [datetime]$TriggerTime
    )

    Ensure-DataDirectory

    $taskName = "$Script:TaskPrefix$Id"
    $argList = @(
        $Script:NotifyRunner
        '-Id', $Id
        '-Title', $Title
        '-Message', $Message
        '-ScheduledTime', $TriggerTime.ToString('yyyy-MM-dd HH:mm:ss')
    )
    $arguments = ($argList | ForEach-Object {
        if ($_ -match '\s') { "`"$_`"" } else { $_ }
    }) -join ' '

    $action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument $arguments
    $trigger = New-ScheduledTaskTrigger -Once -At $TriggerTime
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
}

function Add-Reminder {
    param(
        [datetime]$TriggerTime,
        [string]$Message,
        [string]$Title = 'Reminder'
    )

    if ($TriggerTime -le (Get-Date)) {
        throw 'Reminder time must be in the future'
    }

    $id = New-ShortId
    Register-ReminderTask -Id $id -Title $Title -Message $Message -TriggerTime $TriggerTime

    $reminder = [PSCustomObject]@{
        id          = $id
        title       = $Title
        message     = $Message
        triggerTime = $TriggerTime.ToString('yyyy-MM-dd HH:mm:ss')
        createdAt   = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        status      = 'pending'
    }

    $reminders = @(Read-Reminders)
    $reminders += $reminder
    Save-Reminders -Reminders $reminders

    $remaining = $TriggerTime - (Get-Date)
    Write-Host ''
    Write-Host '  Reminder created' -ForegroundColor Green
    Write-Host "  ID:      $id" -ForegroundColor White
    Write-Host "  Message: $Message" -ForegroundColor White
    Write-Host "  At:      $($TriggerTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
    Write-Host "  In:      $(Format-TimeSpanHuman -Span $remaining)" -ForegroundColor Cyan
    Write-Host ''
    Write-Host "  Cancel: remind cancel $id" -ForegroundColor DarkGray
    Write-Host ''
}

function Show-ReminderList {
    $reminders = @(Read-Reminders)
    $now = Get-Date

    $active = @($reminders | Where-Object {
        try { [datetime]::Parse($_.triggerTime) -gt $now } catch { $false }
    })

    if (@($active).Count -ne @($reminders).Count) {
        Save-Reminders -Reminders $active
        $reminders = $active
    }

    Write-Host ''
    Write-Host '  Pending reminders' -ForegroundColor Cyan
    Write-Host ('  ' + ('=' * 60)) -ForegroundColor DarkGray

    if (@($reminders).Count -eq 0) {
        Write-Host ''
        Write-Host '  (none)' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '  Example: remind 1h "wake up"' -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    Write-Host ''
    Write-Host ('  {0,-10} {1,-22} {2,-19} {3}' -f 'ID', 'Message', 'Trigger', 'Remaining') -ForegroundColor Yellow
    Write-Host ('  ' + ('-' * 58)) -ForegroundColor DarkGray

    foreach ($item in ($reminders | Sort-Object { [datetime]::Parse($_.triggerTime) })) {
        $trigger = [datetime]::Parse($item.triggerTime)
        $remaining = $trigger - $now
        $remainText = if ($remaining.TotalSeconds -gt 0) { Format-TimeSpanHuman -Span $remaining } else { 'soon' }
        $msg = [string]$item.message
        if ($msg.Length -gt 20) { $msg = $msg.Substring(0, 18) + '..' }

        Write-Host ('  {0,-10} {1,-22} {2,-19} {3}' -f $item.id, $msg, $item.triggerTime, $remainText)
    }

    Write-Host ''
    Write-Host "  Total: $(@($reminders).Count)" -ForegroundColor DarkGray
    Write-Host '  Cancel one: remind cancel ID  |  Cancel all: remind cancel all' -ForegroundColor DarkGray
    Write-Host ''
}

function Remove-Reminder {
    param([string]$Id)

    $reminders = @(Read-Reminders)
    $target = $reminders | Where-Object { $_.id -eq $Id }

    if (-not $target) {
        Write-Host ''
        Write-Host "  Reminder not found: $Id" -ForegroundColor Red
        Write-Host '  Use remind list to see active reminders' -ForegroundColor DarkGray
        Write-Host ''
        exit 1
    }

    $taskName = "$Script:TaskPrefix$Id"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

    $reminders = @($reminders | Where-Object { $_.id -ne $Id })
    Save-Reminders -Reminders $reminders

    Write-Host ''
    Write-Host "  Cancelled [$Id]: $($target.message)" -ForegroundColor Green
    Write-Host ''
}

function Remove-AllReminders {
    $reminders = @(Read-Reminders)

    foreach ($item in $reminders) {
        $taskName = "$Script:TaskPrefix$($item.id)"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }

    Save-Reminders -Reminders @()

    Write-Host ''
    Write-Host "  Cancelled all reminders ($(@($reminders).Count) total)" -ForegroundColor Green
    Write-Host ''
}

function Invoke-RemindCommand {
    $CommandArgs = $Script:IncomingArgs
    $argCount = $CommandArgs.Length

    if ($argCount -eq 0) {
        Show-Help
        return
    }

    $command = $CommandArgs[0].ToLower()

    switch ($command) {
        { $_ -in 'help', '-h', '--help', '/?' } { Show-Help; return }

        'install' {
            Install-RemindTool
            return
        }

        'list' {
            Ensure-DataDirectory
            Show-ReminderList
            return
        }

        'cancel' {
            if ($argCount -lt 2) {
                Write-Host ''
                Write-Host '  Usage: remind cancel ID  |  remind cancel all' -ForegroundColor Yellow
                Write-Host ''
                exit 1
            }
            if ($CommandArgs[1].ToLower() -eq 'all') {
                Remove-AllReminders
            }
            else {
                Remove-Reminder -Id $CommandArgs[1]
            }
            return
        }

        'at' {
            if ($argCount -lt 3) {
                Write-Host ''
                Write-Host '  Usage: remind at TIME MESSAGE' -ForegroundColor Yellow
                Write-Host '  Example: remind at 15:30 "meeting"' -ForegroundColor DarkGray
                Write-Host ''
                exit 1
            }
            $timeText = $CommandArgs[1]
            $message = ($CommandArgs[2..($argCount - 1)] -join ' ').Trim('"', "'")
            $triggerTime = Parse-AbsoluteTime -TimeText $timeText
            Add-Reminder -TriggerTime $triggerTime -Message $message
            return
        }

        default {
            if ($argCount -lt 2) {
                Write-Host ''
                Write-Host "  Unknown command or not enough arguments: $($CommandArgs -join ' ')" -ForegroundColor Red
                Write-Host '  Run remind help for usage' -ForegroundColor DarkGray
                Write-Host ''
                exit 1
            }

            $durationText = $CommandArgs[0]
            $message = ($CommandArgs[1..($argCount - 1)] -join ' ').Trim('"', "'")

            if ([string]::IsNullOrWhiteSpace($message)) {
                Write-Host ''
                Write-Host '  Please provide a message, e.g. remind 1h "wake up"' -ForegroundColor Yellow
                Write-Host ''
                exit 1
            }

            $duration = Parse-RelativeDuration -DurationText $durationText
            $triggerTime = (Get-Date).Add($duration)
            Add-Reminder -TriggerTime $triggerTime -Message $message
        }
    }
}

function Initialize-Silently {
    Ensure-DataDirectory
    if (-not (Test-Path $Script:RemindersFile)) {
        '[]' | Set-Content -Path $Script:RemindersFile -Encoding UTF8
    }
}

try {
    if ($null -eq $args -or $args.Count -eq 0) {
        $Script:IncomingArgs = @()
    }
    else {
        $Script:IncomingArgs = [string[]]@($args | ForEach-Object { [string]$_ })
    }
    $firstArg = if ($Script:IncomingArgs.Length -gt 0) { $Script:IncomingArgs[0].ToLower() } else { '' }
    if ($firstArg -ne 'install') {
        Initialize-Silently
    }

    Invoke-RemindCommand
}
catch {
    Write-Host ''
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    exit 1
}

