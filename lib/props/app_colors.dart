import 'package:flutter/material.dart';

/// Palet warna resmi FOODIE (PRO EDITION)
class AppColors {
  AppColors._();

  // ─── PALET DASAR (HEX) ───
  static const Color charcoal = Color(0xFF252D30); // Hitam arang
  static const Color slateBlue = Color(0xFF607783); // Abu kebiruan
  static const Color saffron = Color(0xFFF5BD50); // Kuning emas
  static const Color paprika = Color(0xFFEF8235); // Oranye
  static const Color tomato = Color(0xFFA92F27); // Merah
  static const Color cream = Color(0xFFFFF7E8); // Krem

  // ─── PENGATURAN WARNA UI ───
  static const Color primary = charcoal;
  static const Color secondary = slateBlue;

  // Warna tombol utama (Login, Register, Kirim Saran) & border input saat diketik
  static const Color orange = paprika; 

  // Warna bintang rating ulasan & perolehan poin
  static const Color yellow = saffron; 

  // Warna teks error validasi form, teks Lupa Sandi, & border input saat salah
  static const Color red = tomato; 

  // Warna centang sukses verifikasi & status resto buka
  static const Color green = Color(0xFF3B6E47); 
  static const Color greenDark = charcoal; 

  // Warna teks judul, label input ("Email", "Kata Sandi"), & teks yang diketik di field
  static const Color textDark = charcoal; 

  // Warna teks keterangan (sub-judul, "Ingat saya") & ikon di dalam field (mata, gembok)
  static const Color textMuted = slateBlue; 

  // Warna garis border kotak input (saat normal) & garis pemisah (divider)
  static const Color line = Color(0xFFE2DDD5); 

  // Warna latar putih kotak input field & kartu
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = cream; 

  // Warna latar belakang (background) seluruh layar
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
