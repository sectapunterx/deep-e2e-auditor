<#
Drive a window with the mouse and keyboard. Coordinates are relative to the top-left of the
process's main window (outer rect, physical px) - the same frame as capture.ps1 -MainOnly.

Two modes:
  -Mode post  (default) PostMessage the input to the window. The user's own cursor and focus are
              untouched, so an audit can run while they work. Qt, WPF and most Win32 apps react to
              posted mouse messages; a few ignore them (raw input, DirectX) - then use send.
  -Mode send  real input: brings the window to the front and moves the system cursor (SendInput).
              Ask the user before using it - it takes over their mouse for the duration.

Actions:
  click X Y | rclick X Y | dclick X Y | move X Y | drag X Y X2 Y2 | wheel X Y DELTA
  key NAME [NAME...]   (Enter, Esc, Tab, Down, F2, Delete, a, ...; chords with +: Ctrl+K, Shift+F10)
  type "text"
Examples:
  pwsh -File input.ps1 -ProcessId 1234 rclick 400 300
  pwsh -File input.ps1 -ProcessId 1234 key Ctrl+K
  pwsh -File input.ps1 -ProcessId 1234 type "hello"
#>
param(
  [Parameter(Mandatory)] [int]$ProcessId,
  [ValidateSet("post", "send")] [string]$Mode = "post",
  [int]$DelayMs = 120,
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)] [string[]]$Cmd
)
. "$PSScriptRoot\Win32.ps1"

$WM = @{ MOUSEMOVE = 0x200; LBUTTONDOWN = 0x201; LBUTTONUP = 0x202; LBUTTONDBLCLK = 0x203; RBUTTONDOWN = 0x204; RBUTTONUP = 0x205;
         MOUSEWHEEL = 0x20A; KEYDOWN = 0x100; KEYUP = 0x101; CHAR = 0x102; SYSKEYDOWN = 0x104; SYSKEYUP = 0x105 }
$VK = @{ Enter = 0x0D; Return = 0x0D; Esc = 0x1B; Escape = 0x1B; Tab = 0x09; Space = 0x20; Backspace = 0x08; Delete = 0x2E; Del = 0x2E
         Up = 0x26; Down = 0x28; Left = 0x25; Right = 0x27; Home = 0x24; End = 0x23; PgUp = 0x21; PgDn = 0x22; Insert = 0x2D; Menu = 0x5D; Apps = 0x5D
         Ctrl = 0x11; Shift = 0x10; Alt = 0x12; Win = 0x5B }
for ($i = 1; $i -le 12; $i++) { $VK["F$i"] = 0x6F + $i }

$main = Get-MainWindow $ProcessId
if ($main -eq [IntPtr]::Zero) { Write-Error "no window for pid $ProcessId"; exit 2 }
$wr = Get-Rect $main

function Target([int]$x, [int]$y) {
    # Screen point -> the deepest child window under it, and the point in its client coords.
    $sx = $wr.L + $x; $sy = $wr.T + $y
    $h = $main
    $pt = New-Object DeW32+POINT; $pt.X = $sx; $pt.Y = $sy
    [DeW32]::ScreenToClient($h, [ref]$pt) | Out-Null
    return @{ h = $h; cx = $pt.X; cy = $pt.Y; sx = $sx; sy = $sy }
}
function LParam([int]$x, [int]$y) { return [IntPtr](($y -shl 16) -bor ($x -band 0xFFFF)) }

function Mouse([string]$what, [int]$x, [int]$y, [int]$x2 = 0, [int]$y2 = 0, [int]$delta = 0) {
    $t = Target $x $y
    if ($Mode -eq "send") {
        [DeW32]::SetForegroundWindow($main) | Out-Null; Start-Sleep -Milliseconds 80
        [DeW32]::SetCursorPos($t.sx, $t.sy) | Out-Null; Start-Sleep -Milliseconds 40
        switch ($what) {
            "click"  { [DeW32]::mouse_event(0x2, 0, 0, 0, [UIntPtr]::Zero); [DeW32]::mouse_event(0x4, 0, 0, 0, [UIntPtr]::Zero) }
            "dclick" { 1..2 | ForEach-Object { [DeW32]::mouse_event(0x2, 0, 0, 0, [UIntPtr]::Zero); [DeW32]::mouse_event(0x4, 0, 0, 0, [UIntPtr]::Zero) } }
            "rclick" { [DeW32]::mouse_event(0x8, 0, 0, 0, [UIntPtr]::Zero); [DeW32]::mouse_event(0x10, 0, 0, 0, [UIntPtr]::Zero) }
            "move"   { }
            "wheel"  { [DeW32]::mouse_event(0x800, 0, 0, [uint32]$delta, [UIntPtr]::Zero) }
            "drag"   {
                [DeW32]::mouse_event(0x2, 0, 0, 0, [UIntPtr]::Zero)
                $t2 = Target $x2 $y2
                for ($s = 1; $s -le 12; $s++) {
                    [DeW32]::SetCursorPos([int]($t.sx + ($t2.sx - $t.sx) * $s / 12), [int]($t.sy + ($t2.sy - $t.sy) * $s / 12)) | Out-Null
                    Start-Sleep -Milliseconds 25
                }
                [DeW32]::mouse_event(0x4, 0, 0, 0, [UIntPtr]::Zero)
            }
        }
        return
    }
    $lp = LParam $t.cx $t.cy
    [DeW32]::PostMessage($t.h, $WM.MOUSEMOVE, [IntPtr]0, $lp) | Out-Null; Start-Sleep -Milliseconds 30
    switch ($what) {
        "click"  { [DeW32]::PostMessage($t.h, $WM.LBUTTONDOWN, [IntPtr]1, $lp) | Out-Null; [DeW32]::PostMessage($t.h, $WM.LBUTTONUP, [IntPtr]0, $lp) | Out-Null }
        "dclick" { [DeW32]::PostMessage($t.h, $WM.LBUTTONDOWN, [IntPtr]1, $lp) | Out-Null; [DeW32]::PostMessage($t.h, $WM.LBUTTONUP, [IntPtr]0, $lp) | Out-Null
                   [DeW32]::PostMessage($t.h, $WM.LBUTTONDBLCLK, [IntPtr]1, $lp) | Out-Null; [DeW32]::PostMessage($t.h, $WM.LBUTTONUP, [IntPtr]0, $lp) | Out-Null }
        "rclick" { [DeW32]::PostMessage($t.h, $WM.RBUTTONDOWN, [IntPtr]2, $lp) | Out-Null; [DeW32]::PostMessage($t.h, $WM.RBUTTONUP, [IntPtr]0, $lp) | Out-Null }
        "move"   { }
        "wheel"  { $wp = [IntPtr](([int16]$delta) -shl 16); $slp = LParam $t.sx $t.sy; [DeW32]::PostMessage($t.h, $WM.MOUSEWHEEL, $wp, $slp) | Out-Null }
        "drag"   {
            [DeW32]::PostMessage($t.h, $WM.LBUTTONDOWN, [IntPtr]1, $lp) | Out-Null
            $t2 = Target $x2 $y2
            for ($s = 1; $s -le 12; $s++) {
                $ix = [int]($t.cx + ($t2.cx - $t.cx) * $s / 12); $iy = [int]($t.cy + ($t2.cy - $t.cy) * $s / 12)
                [DeW32]::PostMessage($t.h, $WM.MOUSEMOVE, [IntPtr]1, (LParam $ix $iy)) | Out-Null; Start-Sleep -Milliseconds 25
            }
            [DeW32]::PostMessage($t.h, $WM.LBUTTONUP, [IntPtr]0, (LParam $t2.cx $t2.cy)) | Out-Null
        }
    }
}

function KeyChord([string]$chord) {
    $parts = $chord -split '\+'
    $mods = @(); $keyName = $parts[-1]
    foreach ($m in $parts[0..($parts.Count - 2)]) { if ($parts.Count -gt 1) { $mods += $VK[$m] } }
    $vk = if ($VK.ContainsKey($keyName)) { $VK[$keyName] } elseif ($keyName.Length -eq 1) { [int][char]$keyName.ToUpper() } else { throw "unknown key $keyName" }
    if ($Mode -eq "send") {
        [DeW32]::SetForegroundWindow($main) | Out-Null; Start-Sleep -Milliseconds 60
        foreach ($m in $mods) { [DeW32]::keybd_event([byte]$m, 0, 0, [UIntPtr]::Zero) }
        [DeW32]::keybd_event([byte]$vk, 0, 0, [UIntPtr]::Zero); [DeW32]::keybd_event([byte]$vk, 0, 2, [UIntPtr]::Zero)
        [array]::Reverse($mods); foreach ($m in $mods) { [DeW32]::keybd_event([byte]$m, 0, 2, [UIntPtr]::Zero) }
        return
    }
    # Posted modifiers do not change GetKeyState, so chords with Ctrl/Alt/Shift need send mode on
    # apps that read the modifier state (most). Plain keys work posted.
    if ($mods.Count -gt 0) { Write-Warning "posted chords are unreliable - rerun with -Mode send for $chord" }
    $scan = [DeW32]::MapVirtualKey([uint32]$vk, 0)
    $down = [IntPtr](1 -bor ($scan -shl 16)); $up = [IntPtr]((1 -bor ($scan -shl 16)) -bor 0xC0000000)
    foreach ($m in $mods) { [DeW32]::PostMessage($main, $WM.KEYDOWN, [IntPtr]$m, [IntPtr]1) | Out-Null }
    [DeW32]::PostMessage($main, $WM.KEYDOWN, [IntPtr]$vk, $down) | Out-Null
    if ($mods.Count -eq 0 -and $keyName.Length -eq 1) { [DeW32]::PostMessage($main, $WM.CHAR, [IntPtr][int][char]$keyName, $down) | Out-Null }
    [DeW32]::PostMessage($main, $WM.KEYUP, [IntPtr]$vk, $up) | Out-Null
    foreach ($m in $mods) { [DeW32]::PostMessage($main, $WM.KEYUP, [IntPtr]$m, [IntPtr]0xC0000001) | Out-Null }
}

function TypeText([string]$text) {
    if ($Mode -eq "send") {
        [DeW32]::SetForegroundWindow($main) | Out-Null
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.SendKeys]::SendWait(($text -replace '([+^%~(){}\[\]])', '{$1}'))
        return
    }
    foreach ($ch in $text.ToCharArray()) { [DeW32]::PostMessage($main, $WM.CHAR, [IntPtr][int]$ch, [IntPtr]1) | Out-Null; Start-Sleep -Milliseconds 15 }
}

if (-not $Cmd -or $Cmd.Count -eq 0) { Write-Error "no action"; exit 1 }
$a = $Cmd[0]; $n = @($Cmd[1..($Cmd.Count - 1)])
switch ($a) {
    { $_ -in "click", "rclick", "dclick", "move" } { Mouse $a ([int]$n[0]) ([int]$n[1]) }
    "drag"  { Mouse "drag" ([int]$n[0]) ([int]$n[1]) ([int]$n[2]) ([int]$n[3]) }
    "wheel" { Mouse "wheel" ([int]$n[0]) ([int]$n[1]) 0 0 ([int]$n[2]) }
    "key"   { foreach ($k in $n) { KeyChord $k; Start-Sleep -Milliseconds $DelayMs } }
    "type"  { TypeText ($n -join ' ') }
    default { Write-Error "unknown action $a"; exit 1 }
}
Start-Sleep -Milliseconds $DelayMs
Write-Output "OK $a $($n -join ' ') ($Mode)"
