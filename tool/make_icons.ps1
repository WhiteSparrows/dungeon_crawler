# Génère les icônes Android (mipmap-*/ic_launcher.png) à partir du sprite de MAESTRO.
# Usage (depuis la racine du projet) : powershell -File tool\make_icons.ps1
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$sheet = [Drawing.Image]::FromFile("$root\assets\sprites\tiny_dungeon.png")
$sprite = 84   # MAESTRO
$sx = ($sprite % 12) * 16; $sy = [Math]::Floor($sprite / 12) * 16
$sizes = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($k in $sizes.Keys) {
  $n = $sizes[$k]
  $bmp = New-Object Drawing.Bitmap $n, $n
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.Clear([Drawing.Color]::Transparent)
  $g.SmoothingMode = 'AntiAlias'
  # Fond violet arrondi + cadre doré.
  $r = [int]($n * 0.18)
  $path = New-Object Drawing.Drawing2D.GraphicsPath
  $path.AddArc(0, 0, $r * 2, $r * 2, 180, 90)
  $path.AddArc($n - 1 - $r * 2, 0, $r * 2, $r * 2, 270, 90)
  $path.AddArc($n - 1 - $r * 2, $n - 1 - $r * 2, $r * 2, $r * 2, 0, 90)
  $path.AddArc(0, $n - 1 - $r * 2, $r * 2, $r * 2, 90, 90)
  $path.CloseFigure()
  $g.FillPath((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 42, 20, 64))), $path)
  $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(255, 255, 201, 77)), ([Math]::Max(2, $n / 24))
  $g.DrawPath($pen, $path)
  # Point rouge « EN DIRECT ».
  $d = [int]($n * 0.13)
  $g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 224, 72, 72))), [int]($n * 0.72), [int]($n * 0.12), $d, $d)
  # Sprite en pixels nets.
  $g.SmoothingMode = 'None'
  $g.InterpolationMode = 'NearestNeighbor'
  $g.PixelOffsetMode = 'Half'
  $s = [int]($n * 0.72)
  $o = [int](($n - $s) / 2)
  $g.DrawImage($sheet, (New-Object Drawing.Rectangle $o, ($o + [int]($n * 0.03)), $s, $s), (New-Object Drawing.Rectangle $sx, $sy, 16, 16), 'Pixel')
  $out = "$root\android\app\src\main\res\mipmap-$k\ic_launcher.png"
  $bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "$out ($n px)"
}
$sheet.Dispose()
