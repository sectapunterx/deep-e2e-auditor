<#
Capture every visible window of a process into one PNG, composited at their screen positions:
the main window plus any context menu, popup, tooltip or dialog the toolkit opened as a window of
its own. PrintWindow(PW_RENDERFULLCONTENT) renders each window even when another app covers it, so
this never grabs whatever happens to be on top of the screen (CopyFromScreen would).

Launch and capture:
  pwsh -NoProfile -File capture.ps1 -Exe app.exe -AppArgs "--data-dir C:\sandbox" -Out shot.png -Wait 5 [-Keep]
Attach to a running process:
  pwsh -NoProfile -File capture.ps1 -ProcessId 1234 -Out shot.png
Options:
  -MainOnly         only the biggest window (no popups)
  -Size 1400x900    resize the main window first (outer size, physical px)
  -Env "K=V;K2=V2"  environment for a launched app (e.g. QT_SCALE_FACTOR=1.5)
  -Json             print a JSON line: {pid, out, windows:[{hwnd,title,class,x,y,w,h}]}
Exit 2 when the process shows no window.
#>
param(
  [string]$Exe = "",
  [string]$AppArgs = "",   # the app's command line as ONE string: "--data-dir C:\sandbox --view board"
  [int]$ProcessId = 0,
  [Parameter(Mandatory)] [string]$Out,
  [int]$Wait = 4,
  [switch]$Keep,
  [switch]$MainOnly,
  [string]$Size = "",
  [string]$Env = "",
  [string]$LogDir = "",
  [switch]$Json
)
. "$PSScriptRoot\Win32.ps1"

$launched = $false
if ($ProcessId -eq 0) {
    if (-not $Exe) { Write-Error "give -Exe or -ProcessId"; exit 1 }
    foreach ($kv in ($Env -split ';' | Where-Object { $_ })) { $k, $v = $kv -split '=', 2; Set-Item -Path "env:$k" -Value $v }
    $sp = @{ FilePath = $Exe; PassThru = $true }
    if ($AppArgs) { $sp.ArgumentList = $AppArgs }
    if ($LogDir) {
        New-Item -ItemType Directory -Force $LogDir | Out-Null
        $sp.RedirectStandardError = (Join-Path $LogDir "stderr.txt"); $sp.RedirectStandardOutput = (Join-Path $LogDir "stdout.txt")
    }
    $p = Start-Process @sp
    $ProcessId = $p.Id; $launched = $true
    # Wait for a window, then the requested settle time.
    $deadline = (Get-Date).AddSeconds([Math]::Max(15, $Wait * 3))
    while ((Get-MainWindow $ProcessId) -eq [IntPtr]::Zero -and (Get-Date) -lt $deadline -and -not $p.HasExited) { Start-Sleep -Milliseconds 200 }
    Start-Sleep -Seconds $Wait
}

$main = Get-MainWindow $ProcessId
if ($main -eq [IntPtr]::Zero) {
    Write-Output "NO WINDOW for pid $ProcessId"
    if ($launched -and -not $Keep) { Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue }
    exit 2
}
if ($Size) {
    $w, $h = $Size -split 'x'; $r = Get-Rect $main
    [DeW32]::MoveWindow($main, $r.L, $r.T, [int]$w, [int]$h, $true) | Out-Null
    Start-Sleep -Milliseconds 800
}

$wins = if ($MainOnly) { @($main) } else { [DeW32]::Windows([uint32]$ProcessId) }
# Union of all window rects = the canvas.
$minX = [int]::MaxValue; $minY = [int]::MaxValue; $maxX = [int]::MinValue; $maxY = [int]::MinValue
$meta = @()
foreach ($h in $wins) {
    $r = Get-Rect $h
    if ($r.R - $r.L -le 1 -or $r.B - $r.T -le 1) { continue }
    $minX = [Math]::Min($minX, $r.L); $minY = [Math]::Min($minY, $r.T); $maxX = [Math]::Max($maxX, $r.R); $maxY = [Math]::Max($maxY, $r.B)
    $meta += [pscustomobject]@{ hwnd = [int64]$h; title = [DeW32]::Text($h); class = [DeW32]::Cls($h); x = $r.L; y = $r.T; w = $r.R - $r.L; h = $r.B - $r.T }
}
$canvas = New-Object System.Drawing.Bitmap ($maxX - $minX), ($maxY - $minY)
$cg = [System.Drawing.Graphics]::FromImage($canvas)
$cg.Clear([System.Drawing.Color]::FromArgb(255, 40, 40, 40))
# Biggest first, so popups land on top of the main window.
foreach ($m in $meta) {
    $bmp = New-Object System.Drawing.Bitmap $m.w, $m.h
    $g = [System.Drawing.Graphics]::FromImage($bmp); $hdc = $g.GetHdc()
    [DeW32]::PrintWindow([IntPtr]$m.hwnd, $hdc, 2) | Out-Null
    $g.ReleaseHdc($hdc); $g.Dispose()
    $cg.DrawImage($bmp, $m.x - $minX, $m.y - $minY); $bmp.Dispose()
}
$cg.Dispose()
New-Item -ItemType Directory -Force (Split-Path -Parent ([IO.Path]::GetFullPath($Out))) | Out-Null
$canvas.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $canvas.Dispose()

if ($Json) {
    [pscustomobject]@{ pid = $ProcessId; out = $Out; origin = @($minX, $minY); windows = $meta } | ConvertTo-Json -Compress -Depth 4
} else {
    Write-Output ("OK pid={0} windows={1} canvas={2}x{3} -> {4}" -f $ProcessId, $meta.Count, ($maxX - $minX), ($maxY - $minY), $Out)
}
if ($launched -and -not $Keep) { Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue }
