<#
Dump the UI Automation tree of a process's windows: every element with its role, name, automation
id and bounding box relative to the main window (the frame input.ps1 and capture.ps1 -MainOnly use).
This is the "what is on screen and where" map the audit walks: every card, button, chip and row,
so it can right-click one of each kind, hover them, and find what has no accessible name.

  pwsh -NoProfile -File uia_tree.ps1 -ProcessId 1234 -Out tree.json [-MaxDepth 40] [-Visible]

Qt Quick exposes items that set Accessible.* (and all Controls); WPF, WinForms, Win32 and
Electron/Chromium (with --force-renderer-accessibility) expose their controls natively.
#>
param(
  [Parameter(Mandatory)] [int]$ProcessId,
  [Parameter(Mandatory)] [string]$Out,
  [int]$MaxDepth = 40,
  [switch]$Visible
)
. "$PSScriptRoot\Win32.ps1"
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$main = Get-MainWindow $ProcessId
if ($main -eq [IntPtr]::Zero) { Write-Error "no window for pid $ProcessId"; exit 2 }
$wr = Get-Rect $main
$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
$rows = New-Object System.Collections.Generic.List[object]

function Walk($el, [int]$depth, [string]$path) {
    if ($depth -gt $MaxDepth -or $null -eq $el) { return }
    try {
        $c = $el.Current
        $b = $c.BoundingRectangle
        $off = $c.IsOffscreen
        if (-not ($Visible -and $off) -and -not $b.IsEmpty) {
            $rows.Add([pscustomobject]@{
                depth = $depth; path = $path; role = ($c.ControlType.ProgrammaticName -replace '^ControlType\.', '')
                name = $c.Name; id = $c.AutomationId; cls = $c.ClassName; enabled = $c.IsEnabled; offscreen = $off
                focusable = $c.IsKeyboardFocusable; help = $c.HelpText
                x = [int]($b.X - $wr.L); y = [int]($b.Y - $wr.T); w = [int]$b.Width; h = [int]$b.Height
            })
        }
    } catch { return }
    $i = 0
    $child = $walker.GetFirstChild($el)
    while ($null -ne $child) { Walk $child ($depth + 1) "$path/$i"; $i++; $child = $walker.GetNextSibling($child) }
}

foreach ($h in [DeW32]::Windows([uint32]$ProcessId)) {
    $root = [System.Windows.Automation.AutomationElement]::FromHandle($h)
    Walk $root 0 ("w" + [int64]$h)
}
New-Item -ItemType Directory -Force (Split-Path -Parent ([IO.Path]::GetFullPath($Out))) | Out-Null
$rows | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 $Out
$byRole = $rows | Group-Object role | Sort-Object Count -Descending | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-Output ("OK {0} elements -> {1}  [{2}]" -f $rows.Count, $Out, ($byRole -join ' '))
