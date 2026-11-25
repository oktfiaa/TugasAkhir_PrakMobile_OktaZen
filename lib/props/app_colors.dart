import 'package:flutter/material.dart';

/// Palet warna resmi FOODIE (PRO EDITION - PRAKTIKUM MOBILE)
///
/// CATATAN UNTUK DEMO PRAKTIKUM:
/// Warna telah dipisahkan per fitur / per halaman di bawah ini agar saat
/// penguji / asisten meminta pergantian warna (misal: warna tombol Login diubah,
/// warna background Home diubah, dll.), Anda cukup mengubah variabel di kelas halaman terkait.
class AppColors {
  AppColors._();

  // ─── PALET DASAR UTAMA (HEX) ───
  static const Color charcoal = Color(0xFF252D30); // Hitam arang elegan
  static const Color slateBlue = Color(0xFF607783); // Abu kebiruan (sub-judul & teks sekunder)
  static const Color saffron = Color(0xFFF5BD50); // Kuning emas (bintang, aksen)
  static const Color paprika = Color(0xFFEF8235); // Oranye FOODIE utama (tombol, highlight)
  static const Color tomato = Color(0xFFA92F27); // Merah (error, badge hapus)
  static const Color cream = Color(0xFFFFF7E8); // Krem lembut
  static const Color sageGreen = Color(0xFF3B6E47); // Hijau (sukses, buka)

  // ─── ALIAS GLOBAL (Agar kompatibel dengan seluruh widget lama) ───
  static const Color primary = charcoal;
  static const Color secondary = slateBlue;
  static const Color orange = paprika;
  static const Color yellow = saffron;
  static const Color red = tomato;
  static const Color green = sageGreen;
  static const Color greenDark = charcoal;
  static const Color textDark = charcoal;
  static const Color textMuted = slateBlue;
  static const Color line = Color(0xFFE2DDD5);
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = cream;
  static const Color background = Color(0xFFFAF8F5);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFCFBF8), Color(0xFFFAF8F5), Color(0xFFF6F4ED)],
    stops: [0.0, 0.5, 1.0],
  );

  static Color tint(Color c, double opacity) =>
      c.withValues(alpha: opacity.clamp(0.0, 1.0));
}

// =============================================================================
// 1. WARNA HALAMAN LOGIN (lib/pages/login.dart)
// =============================================================================
class LoginColors {
  LoginColors._();

  /// Warna latar belakang halaman login
  static const Color background = AppColors.background;

  /// Warna tombol utama (Masuk)
  static const Color primaryButton = AppColors.paprika;

  /// Warna teks di dalam tombol utama
  static const Color buttonText = Colors.white;

  /// Warna border kotak input (saat aktif / fokus)
  static const Color inputBorderFocused = AppColors.paprika;

  /// Warna teks judul & label form login
  static const Color textTitle = AppColors.charcoal;

  /// Warna teks sekunder (lupa sandi, ingatkan saya)
  static const Color textMuted = AppColors.slateBlue;

  /// Warna aksen Face ID & tautan daftar
  static const Color accent = AppColors.paprika;
}

// =============================================================================
// 2. WARNA HALAMAN REGISTRASI & VERIFIKASI (lib/pages/register.dart & verify_email.dart)
// =============================================================================
class RegisterColors {
  RegisterColors._();

  /// Warna latar belakang halaman registrasi
  static const Color background = AppColors.background;

  /// Warna tombol utama (Daftar Akun / Verifikasi)
  static const Color primaryButton = AppColors.paprika;

  /// Warna teks di dalam tombol registrasi
  static const Color buttonText = Colors.white;

  /// Warna teks judul registrasi
  static const Color textTitle = AppColors.charcoal;

  /// Warna indikator step progress registrasi
  static const Color stepActive = AppColors.paprika;
  static const Color stepInactive = Color(0xFFE2DDD5);

  /// Warna badge OTP / notifikasi verifikasi email
  static const Color otpBadge = AppColors.cream;
}

// =============================================================================
// 3. WARNA HALAMAN HOME (lib/pages/home_tab.dart)
// =============================================================================
class HomeColors {
  HomeColors._();

  /// Warna latar belakang tab Home
  static const Color background = AppColors.background;

  /// Warna kartu informasi GPS / Lokasi LBS
  static const Color gpsCardBackground = Colors.white;
  static const Color gpsIcon = AppColors.paprika;

  /// Warna kartu rekomendasi personal AI
  static const Color aiCardGradientStart = Color(0xFF252D30);
  static const Color aiCardGradientEnd = Color(0xFF38464C);

  /// Warna judul teks di Home ("Sugeng Rawuh", "Terdekat dari Lokasimu")
  static const Color titleText = AppColors.charcoal;

  /// Warna kartu restoran terdekat
  static const Color restoCardBackground = Colors.white;

  /// Warna badge rating dan jarak
  static const Color ratingBadge = AppColors.saffron;
  static const Color distanceText = AppColors.paprika;
}

// =============================================================================
// 4. WARNA HALAMAN EXPLORE (lib/pages/explore_tab.dart)
// =============================================================================
class ExploreColors {
  ExploreColors._();

  /// Warna latar belakang tab Explore
  static const Color background = AppColors.background;

  /// Warna kotak pencarian (Search Bar)
  static const Color searchBarBackground = Colors.white;
  static const Color searchIcon = AppColors.slateBlue;

  /// Warna filter chip aktif
  static const Color chipActiveBackground = AppColors.charcoal;
  static const Color chipActiveText = Colors.white;

  /// Warna filter chip tidak aktif
  static const Color chipInactiveBackground = Colors.white;
  static const Color chipInactiveText = AppColors.charcoal;

  /// Warna kartu restoran dalam daftar explore
  static const Color cardBackground = Colors.white;
  static const Color priceTag = AppColors.sageGreen;
}

// =============================================================================
// 5. WARNA HALAMAN FAVORIT (lib/pages/favorites_page.dart)
// =============================================================================
class FavoritesColors {
  FavoritesColors._();

  /// Warna latar belakang tab Favorit
  static const Color background = AppColors.background;

  /// Warna tab aktif di switcher ("Favorit" vs "Riwayat")
  static const Color tabActive = AppColors.charcoal;
  static const Color tabInactive = Colors.transparent;

  /// Warna ikon hati (favorit)
  static const Color heart = AppColors.tomato;

  /// Warna kartu restoran favorit
  static const Color cardBackground = Colors.white;

  /// Warna tombol hapus / aksi di favorit
  static const Color removeButton = AppColors.tomato;
}

// =============================================================================
// 6. WARNA HALAMAN PROFIL (lib/pages/profile_tab.dart)
// =============================================================================
class ProfileColors {
  ProfileColors._();

  /// Warna latar belakang tab Profil
  static const Color background = AppColors.background;

  /// Warna kartu utama akun (header profil pengguna)
  static const Color accountCard = AppColors.charcoal;

  /// Warna kartu persona kuliner AI
  static const Color personaCardGradientStart = Color(0xFF1E2426);
  static const Color personaCardGradientEnd = Color(0xFF2C3539);

  /// Warna kartu statistik (Favorit & Ulasan)
  static const Color statsCard = Colors.white;

  /// Warna switch toggle aktif (Face ID & Notifikasi)
  static const Color switchActive = AppColors.paprika;

  /// Warna tombol logout / keluar
  static const Color logoutButton = AppColors.tomato;
}

// =============================================================================
// 7. WARNA HALAMAN SARAN & KESAN (lib/pages/saran_kesan_page.dart)
// =============================================================================
class SaranKesanColors {
  SaranKesanColors._();

  /// Warna latar belakang halaman Saran & Kesan
  static const Color background = AppColors.background;

  /// Warna kartu banner banner "Praktikum Pemrograman Mobile"
  static const Color headerBanner = AppColors.charcoal;

  /// Warna bintang penilaian (rating)
  static const Color starRating = AppColors.saffron;

  /// Warna kartu feedback mahasiswa
  static const Color feedbackCard = Colors.white;

  /// Warna tombol floating action button (Tulis Kesan & Saran)
  static const Color fabButton = AppColors.charcoal;
  static const Color fabIcon = AppColors.saffron;

  /// Warna tombol simpan feedback di bottom sheet
  static const Color submitButton = AppColors.paprika;
}
