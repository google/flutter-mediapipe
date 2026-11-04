# Letterboxes the licensed portrait into the fixture camera's 640x480 frame
# the way the Linux job's ffmpeg filter does (scale to fit, centre, black
# bars) and writes it as top-down BGRX for the media source to embed.
param(
  [Parameter(Mandatory)][string]$Out,
  [string]$Portrait = (Join-Path $PSScriptRoot '../../../../packages/mediapipe-task-vision/test/fixtures/face_detection/landmark-ex1.jpg'),
  [int]$Width = 640,
  [int]$Height = 480
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$source = [System.Drawing.Image]::FromFile((Resolve-Path $Portrait).Path)
try {
  $scale = [Math]::Min($Width / $source.Width, $Height / $source.Height)
  $w = [int][Math]::Round($source.Width * $scale)
  $h = [int][Math]::Round($source.Height * $scale)
  $format = [System.Drawing.Imaging.PixelFormat]::Format32bppRgb
  $frame = New-Object System.Drawing.Bitmap $Width, $Height, $format
  $graphics = [System.Drawing.Graphics]::FromImage($frame)
  $graphics.Clear([System.Drawing.Color]::Black)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.DrawImage($source, [int][Math]::Floor(($Width - $w) / 2), [int][Math]::Floor(($Height - $h) / 2), $w, $h)
  $graphics.Dispose()

  $rect = New-Object System.Drawing.Rectangle 0, 0, $Width, $Height
  $data = $frame.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $format)
  $bytes = New-Object byte[] ($Width * $Height * 4)
  for ($y = 0; $y -lt $Height; $y++) {
    [Runtime.InteropServices.Marshal]::Copy([IntPtr]::Add($data.Scan0, $y * $data.Stride), $bytes, $y * $Width * 4, $Width * 4)
  }
  $frame.UnlockBits($data)
  $frame.Dispose()
} finally {
  $source.Dispose()
}
[IO.File]::WriteAllBytes($Out, $bytes)
"Fixture frame: ${Width}x${Height}, portrait ${w}x${h} centred, $($bytes.Length) bytes -> $Out"
