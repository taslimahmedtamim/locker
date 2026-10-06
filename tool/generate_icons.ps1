Add-Type -AssemblyName System.Drawing

$srcPath = "D:\Vautlkey\uiux\logo.png"
$src = [System.Drawing.Bitmap]::FromFile($srcPath)

function Save-Resized($bmp, $w, $h, $path, $isRound = $false) {
    $dest = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    if ($isRound) {
        $pathObj = New-Object System.Drawing.Drawing2D.GraphicsPath
        $pathObj.AddEllipse(0, 0, $w, $h)
        $g.SetClip($pathObj)
    }

    $g.DrawImage($bmp, 0, 0, $w, $h)
    $g.Dispose()

    $dir = [System.IO.Path]::GetDirectoryName($path)
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $dest.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $dest.Dispose()
}

function Save-Foreground($bmp, $size, $path) {
    $dest = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($dest)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    # Scale to ~76% safe zone inside 108dp canvas
    $innerSize = [int]($size * 0.76)
    $offset = [int](($size - $innerSize) / 2)

    $g.DrawImage($bmp, $offset, $offset, $innerSize, $innerSize)
    $g.Dispose()

    $dir = [System.IO.Path]::GetDirectoryName($path)
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    $dest.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $dest.Dispose()
}

$androidRes = "D:\Vautlkey\android\app\src\main\res"

# 1. Standard icons, Round icons, and Adaptive Foregrounds for Android
Save-Resized $src 48 48 "$androidRes\mipmap-mdpi\ic_launcher.png"
Save-Resized $src 48 48 "$androidRes\mipmap-mdpi\ic_launcher_round.png" $true
Save-Foreground $src 108 "$androidRes\mipmap-mdpi\ic_launcher_foreground.png"

Save-Resized $src 72 72 "$androidRes\mipmap-hdpi\ic_launcher.png"
Save-Resized $src 72 72 "$androidRes\mipmap-hdpi\ic_launcher_round.png" $true
Save-Foreground $src 162 "$androidRes\mipmap-hdpi\ic_launcher_foreground.png"

Save-Resized $src 96 96 "$androidRes\mipmap-xhdpi\ic_launcher.png"
Save-Resized $src 96 96 "$androidRes\mipmap-xhdpi\ic_launcher_round.png" $true
Save-Foreground $src 216 "$androidRes\mipmap-xhdpi\ic_launcher_foreground.png"

Save-Resized $src 144 144 "$androidRes\mipmap-xxhdpi\ic_launcher.png"
Save-Resized $src 144 144 "$androidRes\mipmap-xxhdpi\ic_launcher_round.png" $true
Save-Foreground $src 324 "$androidRes\mipmap-xxhdpi\ic_launcher_foreground.png"

Save-Resized $src 192 192 "$androidRes\mipmap-xxxhdpi\ic_launcher.png"
Save-Resized $src 192 192 "$androidRes\mipmap-xxxhdpi\ic_launcher_round.png" $true
Save-Foreground $src 432 "$androidRes\mipmap-xxxhdpi\ic_launcher_foreground.png"

# 2. iOS icons
$iosDir = "D:\Vautlkey\ios\Runner\Assets.xcassets\AppIcon.appiconset"
if (Test-Path $iosDir) {
    Save-Resized $src 20 20 "$iosDir\Icon-App-20x20@1x.png"
    Save-Resized $src 40 40 "$iosDir\Icon-App-20x20@2x.png"
    Save-Resized $src 60 60 "$iosDir\Icon-App-20x20@3x.png"
    Save-Resized $src 29 29 "$iosDir\Icon-App-29x29@1x.png"
    Save-Resized $src 58 58 "$iosDir\Icon-App-29x29@2x.png"
    Save-Resized $src 87 87 "$iosDir\Icon-App-29x29@3x.png"
    Save-Resized $src 40 40 "$iosDir\Icon-App-40x40@1x.png"
    Save-Resized $src 80 80 "$iosDir\Icon-App-40x40@2x.png"
    Save-Resized $src 120 120 "$iosDir\Icon-App-40x40@3x.png"
    Save-Resized $src 120 120 "$iosDir\Icon-App-60x60@2x.png"
    Save-Resized $src 180 180 "$iosDir\Icon-App-60x60@3x.png"
    Save-Resized $src 76 76 "$iosDir\Icon-App-76x76@1x.png"
    Save-Resized $src 152 152 "$iosDir\Icon-App-76x76@2x.png"
    Save-Resized $src 167 167 "$iosDir\Icon-App-83.5x83.5@2x.png"
    Save-Resized $src 1024 1024 "$iosDir\Icon-App-1024x1024@1x.png"
}

# 3. Web favicon & icons
$webDir = "D:\Vautlkey\web\icons"
if (Test-Path $webDir) {
    Save-Resized $src 192 192 "$webDir\Icon-192.png"
    Save-Resized $src 512 512 "$webDir\Icon-512.png"
    Save-Resized $src 192 192 "$webDir\Icon-maskable-192.png"
    Save-Resized $src 512 512 "$webDir\Icon-maskable-512.png"
    Save-Resized $src 32 32 "D:\Vautlkey\web\favicon.png"
}

$src.Dispose()
Write-Output "All platform icons generated successfully!"
