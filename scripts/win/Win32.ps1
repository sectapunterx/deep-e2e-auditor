# Shared Win32 interop for the Windows driver scripts. Dot-source it:  . "$PSScriptRoot\Win32.ps1"
# Works in Windows PowerShell 5.1 and PowerShell 7. Run from PowerShell, not git-bash: an MSYS
# toolchain on PATH (LIB/INCLUDE) breaks Add-Type.
$env:LIB = $null; $env:INCLUDE = $null
Add-Type -AssemblyName System.Drawing
if (-not ("DeW32" -as [type])) {
Add-Type @"
using System; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Text;
public class DeW32 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
  [DllImport("user32.dll")] public static extern IntPtr GetWindow(IntPtr h, uint cmd);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool repaint);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }

  // Every visible top-level window of a process, biggest first. Menus, popups and tooltips of
  // native toolkits are top-level windows of their own; a capture has to include them.
  public static List<IntPtr> Windows(uint pid) {
    var list = new List<KeyValuePair<long, IntPtr>>();
    EnumWindows((h, l) => { uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) { RECT r; GetWindowRect(h, out r);
        long a = (long)(r.R - r.L) * (r.B - r.T); if (a > 0) list.Add(new KeyValuePair<long, IntPtr>(a, h)); }
      return true; }, IntPtr.Zero);
    list.Sort((x, y) => y.Key.CompareTo(x.Key));
    var o = new List<IntPtr>(); foreach (var kv in list) o.Add(kv.Value); return o;
  }
  public static string Text(IntPtr h) { var s = new StringBuilder(512); GetWindowText(h, s, 512); return s.ToString(); }
  public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassName(h, s, 256); return s.ToString(); }
}
"@
}
[DeW32]::SetProcessDPIAware() | Out-Null

function Get-MainWindow([int]$ProcessId) {
    $all = [DeW32]::Windows([uint32]$ProcessId)
    if ($all.Count -eq 0) { return [IntPtr]::Zero }
    return $all[0]
}

function Get-Rect([IntPtr]$h) {
    $r = New-Object DeW32+RECT; [DeW32]::GetWindowRect($h, [ref]$r) | Out-Null; return $r
}
