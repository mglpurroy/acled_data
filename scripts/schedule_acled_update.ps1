# PowerShell script to schedule ACLED updates in Windows Task Scheduler
# Run this script once to set up weekly automatic updates

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$updateScript = Join-Path $scriptDir "update_acled_scheduled.bat"

# Check if the update script exists
if (-not (Test-Path $updateScript)) {
    Write-Host "ERROR: update_acled_scheduled.bat not found at: $updateScript" -ForegroundColor Red
    exit 1
}

# Task Scheduler settings
$taskName = "ACLED Weekly Data Update"
$taskDescription = "Automatically updates ACLED conflict data every week"

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($existingTask) {
    Write-Host "Task '$taskName' already exists." -ForegroundColor Yellow
    $response = Read-Host "Do you want to update it? (Y/N)"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Removed existing task." -ForegroundColor Green
}

# Create the action (run the batch file)
$action = New-ScheduledTaskAction -Execute $updateScript -WorkingDirectory $scriptDir

# Create the trigger (weekly on Monday at 2:00 AM)
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 2am

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

# Create the principal (run as current user)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

# Register the task
try {
    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $taskDescription | Out-Null
    
    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host "Task scheduled successfully!" -ForegroundColor Green
    Write-Host "======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Name: $taskName" -ForegroundColor Cyan
    Write-Host "Schedule: Every Monday at 2:00 AM" -ForegroundColor Cyan
    Write-Host "Script: $updateScript" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To modify the schedule:" -ForegroundColor Yellow
    Write-Host "  1. Open Task Scheduler (taskschd.msc)" -ForegroundColor Yellow
    Write-Host "  2. Find task: '$taskName'" -ForegroundColor Yellow
    Write-Host "  3. Right-click > Properties > Triggers" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To view logs:" -ForegroundColor Yellow
    Write-Host "  Check the 'logs' folder in: $scriptDir" -ForegroundColor Yellow
    Write-Host ""
    
} catch {
    Write-Host "ERROR: Failed to schedule task" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

