# Optimasi RAM Xiaomi 15 (HyperOS)

Catatan langkah optimasi yang dilakukan pada 16 Nov 2026. Ulangi setelah **update HyperOS**,
karena update besar bisa mengembalikan aplikasi yang sudah di-uninstall dan mereset izin.

Hasil saat itu: RAM yang bisa dipakai naik dari **4,0 GB → 6,7 GB** (dari total 11,4 GB).

---

## A. Persiapan (sekali saja per laptop)

1. Install ADB di laptop (PowerShell):
   ```
   winget install Google.PlatformTools
   ```
   Tutup & buka ulang terminal, lalu cek: `adb version`

2. Di HP:
   - **Settings → About phone → ketuk "OS version" 7×** → Developer options aktif
   - **Settings → Additional settings → Developer options**:
     - **USB debugging** → ON
     - **USB debugging (Security settings)** → ON (perlu Mi Account + SIM aktif)
3. Colok kabel USB → di HP muncul "Allow USB debugging?" → centang *Always allow* → **Allow**
4. Cek di laptop: `adb devices` → harus muncul status `device` (bukan `unauthorized`)

> Jika `adb devices` kosong: ubah mode USB ke **File transfer**, matikan-nyalakan USB debugging,
> cabut-colok kabel.

---

## B. Jalankan skrip otomatis

Di folder ini, buka PowerShell lalu:

```powershell
# Lihat dulu apa yang akan dilakukan (tidak mengubah apa pun)
powershell -ExecutionPolicy Bypass -File .\optimasi-ram.ps1 -DryRun

# Terapkan optimasi
powershell -ExecutionPolicy Bypass -File .\optimasi-ram.ps1

# Batalkan / kembalikan semua
powershell -ExecutionPolicy Bypass -File .\optimasi-ram.ps1 -Restore
```

Skrip melakukan:

| Langkah | Aplikasi | Tindakan |
|---|---|---|
| 1. Jaga tetap hidup | WhatsApp | Dikecualikan dari Doze, boleh jalan di latar belakang, Autostart ON |
| 2. Batasi latar belakang | Facebook, FB Lite, Instagram, Threads, Edits, Meta View, Shopee, Tokopedia, Lazada, Blibli, YouTube, YouTube Studio, CapCut, MyTelkomsel, Casio Watches | Larang jalan di latar belakang, bucket *Restricted*, Autostart OFF, keluarkan dari Doze whitelist, force-stop |
| 3. Batasi app sistem | Discover (Xiaomi) | Sama seperti no. 2 (sebisanya) |
| 4. Uninstall user 0 | MSA (iklan), GetApps, layanan Facebook bawaan (services, appmanager, system), Android Auto | `pm uninstall -k --user 0` — file asli tetap di sistem |

Untuk menambah/mengurangi aplikasi, edit daftar di bagian **KONFIGURASI** pada `optimasi-ram.ps1`.

---

## C. Langkah MANUAL di HP (tidak bisa lewat ADB)

1. **Kunci WhatsApp di Recent Apps**
   Buka Recent Apps → tekan lama kartu WhatsApp → ketuk ikon **gembok 🔒**.
   Tanpa ini, HyperOS menutup WhatsApp setiap layar dikunci (`LockScreenClean`) atau saat "clear all".
2. **WhatsApp → Battery saver → No restrictions**
   Settings → Apps → Manage apps → WhatsApp → Battery saver → *No restrictions*.
3. **Matikan iklan yang dipersonalisasi**
   Settings → Passwords & security → Privacy → Ads services → matikan *Personalized ad recommendations*.
4. **Matikan rekomendasi di aplikasi bawaan**
   Buka Security, File Manager, Themes → Settings → matikan *Receive recommendations*.
5. *(Opsional)* **Matikan Xiaomi Interconnectivity / HyperConnect** jika tidak memakai PC/tablet/TV Xiaomi.
   Settings → Connection & sharing → Xiaomi Interconnectivity.
6. *(Opsional)* Aplikasi lain yang notifikasinya penting (mis. **BSI Mobile**, **Info BMKG**):
   kunci di Recent Apps + Battery saver *No restrictions*.

Setelah selesai, **matikan USB debugging** demi keamanan.

---

## D. Cek manual pemakaian RAM

```powershell
adb shell dumpsys meminfo                       # RAM per proses + total (lihat "Total PSS by process")
adb shell "ps -A -o PID,RSS,NAME -k -rss | head -20"   # 20 proses terbesar
adb shell dumpsys meminfo com.whatsapp          # detail 1 aplikasi
adb shell "logcat -b events -d -s am_kill:I | tail -20" # aplikasi yang ditutup sistem & alasannya
```

Arti status di `dumpsys meminfo` → "Total PSS by OOM adjustment":
- **Cached** → aman, dilepas otomatis saat RAM dibutuhkan
- **Previous** → aplikasi terakhir dibuka
- **Foreground / Perceptible / Services** → benar-benar aktif berjalan → kandidat dibatasi

Alasan penutupan di log `am_kill`:
- `LockScreenClean` → dibersihkan HyperOS saat layar dikunci
- `SwipeUpClean` → Anda mengusap aplikasi dari Recent Apps
- `normal_mem_pressure` → sistem butuh RAM (normal)

---

## E. Catatan teknis / pelajaran

- **`pm disable-user` diblokir HyperOS** untuk aplikasi sistem (`SecurityException: Cannot disable
  system packages`), bahkan dengan *USB debugging (Security settings)* aktif. Gunakan
  `pm uninstall -k --user 0` sebagai gantinya.
- Mengembalikan aplikasi yang di-uninstall: `adb shell cmd package install-existing <paket>`
- Kode **Autostart** HyperOS = appop `10008`
  (`adb shell cmd appops get <paket> 10008` / `set <paket> 10008 allow|ignore`).
  Jika update OS mengubah kodenya, skrip akan menampilkan nilai aneh pada kolom `autostart=`.
- **DMA-BUF** (buffer kamera/GPU) sempat 3,27 GB lalu turun sendiri ke ~0,4 GB setelah kamera ditutup
  → normal, bukan leak. Leak = angka terus naik dan tidak pernah turun.
- Layanan Facebook bawaan pabrik (`com.facebook.services`, `.appmanager`, `.system`) dan
  Android Auto (`com.google.android.projection.gearhead`) **tidak bisa dinonaktifkan** dan terus hidup
  lagi (layanan Facebook juga membangunkan Meta View), sehingga di-uninstall untuk user 0.
  Jika memakai Android Auto di mobil, hapus baris gearhead dari `$UninstallUser0` lalu jalankan
  `adb shell cmd package install-existing com.google.android.projection.gearhead`.
- Efek samping pembatasan: notifikasi aplikasi yang dibatasi bisa terlambat; Casio Watches bisa
  terputus dari jam; YouTube Premium background play bisa terhenti.
