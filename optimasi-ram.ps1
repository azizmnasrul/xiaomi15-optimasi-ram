<#
  Optimasi RAM Xiaomi 15 (HyperOS) via ADB
  Dibuat: 16 Nov 2026

  CARA PAKAI (di PowerShell):
    1. Sambungkan HP via USB, USB debugging aktif, tekan "Allow" di HP.
    2. Jalankan:
         powershell -ExecutionPolicy Bypass -File .\optimasi-ram.ps1
       Untuk melihat dulu tanpa mengubah apa pun:
         powershell -ExecutionPolicy Bypass -File .\optimasi-ram.ps1 -DryRun
       Untuk MENGEMBALIKAN semua pengaturan ke semula:
         powershell -ExecutionPolicy Bypass -File .\optimasi-ram.ps1 -Restore

  Edit daftar aplikasi di bagian KONFIGURASI di bawah sesuai kebutuhan.
#>
param(
    [switch]$Restore,
    [switch]$DryRun
)

# ===================== KONFIGURASI =====================

# Aplikasi yang HARUS tetap hidup di latar belakang (notifikasi penting)
$KeepAlive = @(
    'com.whatsapp'
)

# Aplikasi yang dibatasi di latar belakang (tidak jalan saat tidak dibuka)
$Restrict = @(
    # Media sosial
    'com.facebook.katana',              # Facebook
    'com.facebook.lite',                # Facebook Lite
    'com.instagram.android',            # Instagram
    'com.instagram.barcelona',          # Threads
    'com.instagram.basel',              # Edits
    'com.facebook.stella',              # Meta View (kacamata Meta)
    # Belanja
    'com.shopee.id',                    # Shopee
    'com.tokopedia.tkpd',               # Tokopedia
    'com.lazada.android',               # Lazada
    'blibli.mobile.commerce',           # Blibli
    # Video
    'com.google.android.youtube',       # YouTube
    'com.google.android.apps.youtube.creator', # YouTube Studio
    'com.lemon.lvoverseas',             # CapCut
    # Lainnya
    'com.telkomsel.telkomselcm',        # MyTelkomsel
    'com.casio.wac_app'                 # Casio Watches (jam bisa terputus!)
)

# Aplikasi sistem Xiaomi: dibatasi (tidak bisa di-uninstall / dinonaktifkan)
$RestrictSystem = @(
    'com.xiaomi.discover'               # Discover (rekomendasi/iklan)
)

# Aplikasi sistem yang di-"uninstall" untuk user 0 (file asli tetap di sistem)
$UninstallUser0 = @(
    'com.miui.msa.global',              # MSA - layanan iklan HyperOS
    'com.xiaomi.mipicks',               # GetApps
    'com.facebook.services',            # Layanan Facebook bawaan pabrik
    'com.facebook.appmanager',          # Facebook App Manager (bawaan pabrik)
    'com.facebook.system',              # Facebook App Installer (bawaan pabrik)
    'com.google.android.projection.gearhead' # Android Auto (hapus baris ini jika memakai Android Auto)
)

# Kode appop Autostart milik MIUI/HyperOS
$AUTOSTART_OP = '10008'

# ===================== FUNGSI =====================

function Find-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $p = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter adb.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p) { return $p.FullName }
    throw "adb tidak ditemukan. Install dengan: winget install Google.PlatformTools"
}

$adb = Find-Adb

function Sh([string]$c) {
    if ($DryRun -and $c -notmatch '^(getprop|pm path|pm list|cmd appops get|am get-standby-bucket|ps |dumpsys )') {
        Write-Host "   [dry-run] $c" -ForegroundColor DarkGray
        return ''
    }
    return ((& $adb shell "$c 2>&1") -join ' ').Trim()
}

function Is-Installed([string]$p) { return [bool](Sh "pm path $p") }

function Status([string]$p) {
    $bg = (Sh "cmd appops get $p RUN_ANY_IN_BACKGROUND") -replace ';.*','' -replace 'RUN_ANY_IN_BACKGROUND: ',''
    $bk = Sh "am get-standby-bucket $p"
    $as = (Sh "cmd appops get $p $AUTOSTART_OP") -replace ';.*','' -replace 'MIUIOP\(\d+\): ',''
    return "bg=$bg bucket=$bk autostart=$as"
}

# ===================== CEK PERANGKAT =====================

$dev = (& $adb devices) | Select-String "`tdevice$"
if (-not $dev) {
    Write-Host "HP belum terhubung / belum di-Allow. Output 'adb devices':" -ForegroundColor Red
    & $adb devices
    exit 1
}
$model = Sh "getprop ro.product.model"
$os = Sh "getprop ro.mi.os.version.incremental"
Write-Host "Terhubung: $model  (HyperOS $os)" -ForegroundColor Green
if ($DryRun) { Write-Host "MODE DRY-RUN: tidak ada yang diubah`n" -ForegroundColor Yellow }

function Show-Ram {
    $m = & $adb shell "dumpsys meminfo" | Select-String 'Total RAM|Free RAM|Used RAM'
    $m | ForEach-Object { Write-Host "   $($_.Line.Trim())" }
}

Write-Host "`n== RAM SEBELUM ==" -ForegroundColor Cyan
Show-Ram

# ===================== RESTORE =====================

if ($Restore) {
    Write-Host "`n== MENGEMBALIKAN PENGATURAN ==" -ForegroundColor Cyan
    foreach ($p in $UninstallUser0) {
        Write-Host " $p -> $(Sh "cmd package install-existing $p")"
    }
    foreach ($p in $Restrict + $RestrictSystem) {
        if (-not (Is-Installed $p)) { continue }
        Sh "cmd appops set $p RUN_ANY_IN_BACKGROUND allow" | Out-Null
        Sh "am set-standby-bucket $p active" | Out-Null
        Write-Host " $p -> $(Status $p)"
    }
    Write-Host "`nSelesai. Autostart tidak diubah balik (atur manual di Settings bila perlu)." -ForegroundColor Green
    exit 0
}

# ===================== 1. KEEP ALIVE =====================

Write-Host "`n== 1. Aplikasi yang dijaga tetap hidup ==" -ForegroundColor Cyan
foreach ($p in $KeepAlive) {
    if (-not (Is-Installed $p)) { Write-Host " $p (tidak terpasang, lewati)"; continue }
    Sh "cmd deviceidle whitelist +$p" | Out-Null
    Sh "cmd appops set $p RUN_ANY_IN_BACKGROUND allow" | Out-Null
    Sh "cmd appops set $p RUN_IN_BACKGROUND allow" | Out-Null
    Sh "cmd appops set $p $AUTOSTART_OP allow" | Out-Null
    Write-Host " $p -> $(Status $p)"
}

# ===================== 2. RESTRICT =====================

Write-Host "`n== 2. Membatasi latar belakang ==" -ForegroundColor Cyan
foreach ($p in $Restrict) {
    if (-not (Is-Installed $p)) { Write-Host " $p (tidak terpasang, lewati)"; continue }
    Sh "cmd appops set $p RUN_ANY_IN_BACKGROUND ignore" | Out-Null
    Sh "am set-standby-bucket $p restricted" | Out-Null
    Sh "cmd appops set $p $AUTOSTART_OP ignore" | Out-Null
    Sh "cmd deviceidle whitelist -$p" | Out-Null
    Sh "am force-stop $p" | Out-Null
    Write-Host " $p -> $(Status $p)"
}

# ===================== 3. RESTRICT SYSTEM =====================

Write-Host "`n== 3. Membatasi aplikasi sistem Xiaomi ==" -ForegroundColor Cyan
foreach ($p in $RestrictSystem) {
    if (-not (Is-Installed $p)) { Write-Host " $p (tidak terpasang, lewati)"; continue }
    Sh "cmd appops set $p RUN_ANY_IN_BACKGROUND ignore" | Out-Null
    Sh "am set-standby-bucket $p restricted" | Out-Null   # sering ditolak utk app sistem, tidak apa-apa
    Sh "cmd appops set $p $AUTOSTART_OP ignore" | Out-Null
    Sh "cmd deviceidle whitelist -$p" | Out-Null
    Sh "am force-stop $p" | Out-Null
    Write-Host " $p -> $(Status $p)"
}

# ===================== 4. UNINSTALL USER 0 =====================

Write-Host "`n== 4. Uninstall untuk user 0 (MSA, GetApps, layanan Facebook, Android Auto) ==" -ForegroundColor Cyan
foreach ($p in $UninstallUser0) {
    if (-not (Is-Installed $p)) { Write-Host " $p sudah tidak terpasang untuk user (OK)"; continue }
    Write-Host " $p -> $(Sh "pm uninstall -k --user 0 $p")"
}

# ===================== HASIL =====================

Start-Sleep -Seconds 3
Write-Host "`n== RAM SESUDAH ==" -ForegroundColor Cyan
Show-Ram

Write-Host "`n== Aplikasi yang dibatasi tapi masih berjalan ==" -ForegroundColor Cyan
$names = ($Restrict + $RestrictSystem + $UninstallUser0) -join '|'
$running = Sh "ps -A -o RSS,NAME | grep -E '$names'"
if ($running) { Write-Host " $running" } else { Write-Host " (tidak ada)" -ForegroundColor Green }

Write-Host "`nSelesai. Jangan lupa langkah MANUAL di README.md (kunci WhatsApp di Recent Apps, dll)." -ForegroundColor Green
