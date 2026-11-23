# Moves the console window this script is attached to onto the second monitor.
# Called from Code.bat at startup. Safe to run with one monitor: it does nothing.
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms

$sig = @'
using System;
using System.Runtime.InteropServices;
public static class ConsoleMover {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@
Add-Type -TypeDefinition $sig

$target = [System.Windows.Forms.Screen]::AllScreens | Where-Object { -not $_.Primary } | Select-Object -First 1
if ($null -eq $target) { exit 0 }

$hwnd = [ConsoleMover]::GetConsoleWindow()
if ($hwnd -eq [IntPtr]::Zero) { exit 0 }

$area = $target.WorkingArea
$w = [int]($area.Width  * 0.9)
$h = [int]($area.Height * 0.9)
$x = $area.X + [int](($area.Width  - $w) / 2)
$y = $area.Y + [int](($area.Height - $h) / 2)

[void][ConsoleMover]::ShowWindow($hwnd, 9)
[void][ConsoleMover]::MoveWindow($hwnd, $x, $y, $w, $h, $true)
[void][ConsoleMover]::SetForegroundWindow($hwnd)
exit 0
