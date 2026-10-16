# Captures (and optionally clicks into) a window, for comparing the original Flash game with the port.
# Usage: wincap.ps1 -ProcId <pid> -Out <file.png> [-ClickX <x> -ClickY <y>]   (click coords are client-area pixels)
param([int]$ProcId, [string]$Out, [int]$ClickX = -1, [int]$ClickY = -1, [switch]$MoveOnly, [int]$Wait = 0)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class W {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(int f, int x, int y, int d, int e);
}
"@
$p = Get-Process -Id $ProcId
$h = $p.MainWindowHandle
[W]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 300
$r = New-Object W+RECT
[W]::GetClientRect($h, [ref]$r) | Out-Null
$pt = New-Object W+POINT
[W]::ClientToScreen($h, [ref]$pt) | Out-Null
if ($ClickX -ge 0) {
  [W]::SetCursorPos($pt.X + $ClickX, $pt.Y + $ClickY) | Out-Null
  Start-Sleep -Milliseconds 200
  if (-not $MoveOnly) { [W]::mouse_event(2, 0, 0, 0, 0); Start-Sleep -Milliseconds 80; [W]::mouse_event(4, 0, 0, 0, 0) }
  Start-Sleep -Milliseconds 300
}
if ($Wait -gt 0) { Start-Sleep -Milliseconds $Wait }
$w = $r.R - $r.L; $hgt = $r.B - $r.T
$bmp = New-Object System.Drawing.Bitmap $w, $hgt
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($pt.X, $pt.Y, 0, 0, (New-Object System.Drawing.Size $w, $hgt))
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"$w x $hgt"
