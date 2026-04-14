# Restart the TP-Link BT adapter to recover a hung BLE HID link.
# Run as Administrator.
#
# Strategy: pnputil /disable-device + /enable-device is the most reliable
# soft-cycle on Windows 11. Falls back to /restart-device if disable fails.

$ErrorActionPreference = 'Stop'
$instanceId = 'USB\VID_2357&PID_0604\6C4CBC09ECB2'

function Invoke-PnpUtil {
    param([string]$Args)
    $out = & pnputil.exe $Args.Split(' ') 2>&1
    return @{ Code = $LASTEXITCODE; Out = ($out -join "`n") }
}

Write-Host "Disabling $instanceId ..." -ForegroundColor Cyan
$r = Invoke-PnpUtil "/disable-device `"$instanceId`""
Write-Host $r.Out

if ($r.Code -eq 0) {
    Start-Sleep -Seconds 2
    Write-Host "Enabling $instanceId ..." -ForegroundColor Cyan
    $r = Invoke-PnpUtil "/enable-device `"$instanceId`""
    Write-Host $r.Out
    if ($r.Code -eq 0) {
        Write-Host "BT adapter cycled. Give it ~5s to re-enumerate." -ForegroundColor Green
        Start-Sleep -Seconds 5
        exit 0
    }
}

Write-Host "disable/enable path failed, trying /restart-device ..." -ForegroundColor Yellow
$r = Invoke-PnpUtil "/restart-device `"$instanceId`""
Write-Host $r.Out

if ($r.Code -eq 0) {
    Write-Host "BT adapter restarted. Give it ~5s to re-enumerate." -ForegroundColor Green
    Start-Sleep -Seconds 5
    exit 0
}

if ($r.Out -match 'pending system reboot') {
    Write-Host ""
    Write-Host "Adapter is in 'pending reboot' state (DEVPKEY_Device_IsRebootRequired=True)." -ForegroundColor Red
    Write-Host "One full Windows reboot is required to clear this. After that, this script will work." -ForegroundColor Red
    exit 2
}

Write-Host "All recovery paths failed. See output above." -ForegroundColor Red
exit 1
