# GeoGPS Cam 📸

Aplikasi Flutter untuk menangkap foto dengan **watermark GPS otomatis** yang menampilkan jam, lokasi, latitude dan longitude.

## Fitur Utama

| Fitur | Deskripsi |
|-------|-----------|
| 📸 Kamera HD | Resolusi ultra high dengan kontrol zoom & flash |
| 🕐 Watermark Jam | Jam + tanggal dalam Bahasa Indonesia tertempel di foto |
| 📍 Watermark Lokasi | Alamat lengkap hasil reverse geocoding |
| 🌐 Watermark GPS | Latitude & Longitude presisi 6 desimal |
| 💾 Simpan Galeri | Foto tersimpan di album "GeoGPS Cam" |
| 🔄 Switch Kamera | Support kamera depan & belakang |

## Struktur Proyek

```
lib/
├── main.dart                    # Entry point & locale init
├── models/
│   └── location_data.dart       # Model data GPS
├── screens/
│   ├── camera_screen.dart       # Layar kamera utama
│   └── preview_screen.dart      # Preview & simpan foto
├── services/
│   ├── location_service.dart    # Ambil GPS + reverse geocode
│   └── watermark_service.dart   # Tempelkan watermark ke gambar
└── widgets/
    └── watermark_overlay.dart   # Overlay GPS di viewfinder
```

## Cara Jalankan

```bash
cd GeoGPSCam
flutter pub get
flutter run
```

## Cara Build APK

```bash
flutter build apk --release
```
APK tersimpan di: `build/app/outputs/flutter-apk/app-release.apk`

## Permissions Android

- `CAMERA` — akses kamera
- `ACCESS_FINE_LOCATION` — GPS presisi tinggi
- `ACCESS_COARSE_LOCATION` — GPS kasar (fallback)
- `WRITE_EXTERNAL_STORAGE` — simpan foto (Android < 10)
- `READ_MEDIA_IMAGES` — akses galeri (Android 13+)
- `INTERNET` — reverse geocoding

## Tampilan Watermark

```
┌─────────────────────────────────────────────────────────┐
│  [Foto Asli]                                            │
│                                                         │
│  (area foto)                                            │
│                                                         │
├═════════════════════════════════════════════════════════╡
│ JAM  13:28:05        LAT  -6.200000°                   │
│ Rabu, 30 Juli 2026   LNG  106.816666°                  │
│ [LOC] Jl. Sudirman, Tanah Abang, Jakarta Pusat         │
│                                               GeoGPS Cam│
└─────────────────────────────────────────────────────────┘
```
