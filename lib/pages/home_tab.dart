import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/ai_recommendation_result.dart';
import '../models/profile.dart';
import '../models/restaurant.dart';
import '../models/user_ai_profile.dart';
import '../props/app_colors.dart';
import '../props/app_text.dart';
import '../services/ai_recommendation_service.dart';
import '../services/supabase_service.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../widgets/restaurant_image.dart';
import 'ai_profile_page.dart';
import 'notifications_page.dart';

/// Tab "Home": sapaan, Curated Shake, GPS widget, rekomendasi AI, kategori, dan Rekomendasi Terdekat (LBS).
class HomeTab extends StatefulWidget {
  final String name;

  /// Pindah ke tab Explore (dipakai "Lihat semua").
  final VoidCallback? onSeeAll;

  /// Tap kategori → pindah ke Explore dengan filter kategori.
  final void Function(String category)? onCategorySelected;

  /// Buka detail restoran langsung dari Home.
  final void Function(Restaurant)? onOpenRestaurant;

  /// Dipanggil saat koordinat GPS berhasil didapat → dipakai Explore untuk sort terdekat.
  final void Function(double lat, double lng)? onLocationFetched;

  const HomeTab({
    super.key,
    required this.name,
    this.onSeeAll,
    this.onCategorySelected,
    this.onOpenRestaurant,
    this.onLocationFetched,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _CategoryItem {
  final String id;
  final String label;
  final IconData icon;

  const _CategoryItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class _HomeTabState extends State<HomeTab> {
  final _svc = SupabaseService.instance;
  final _pageCtrl = PageController(viewportFraction: 0.9);
  final _aiPageCtrl = PageController(viewportFraction: 0.88);

  static const List<_CategoryItem> _categoryItems = [
    _CategoryItem(
      id: 'all',
      label: 'Popular',
      icon: Icons.local_fire_department_rounded,
    ),
    _CategoryItem(
      id: 'Fast Food',
      label: 'Western',
      icon: Icons.local_pizza_rounded,
    ),
    _CategoryItem(
      id: 'Cafe',
      label: 'Drinks',
      icon: Icons.local_cafe_rounded,
    ),
    _CategoryItem(
      id: 'Warung Tradisional',
      label: 'Local',
      icon: Icons.whatshot_rounded,
    ),
    _CategoryItem(
      id: 'Food Court',
      label: 'Dessert',
      icon: Icons.icecream_rounded,
    ),
    _CategoryItem(
      id: 'Restoran',
      label: 'Resto',
      icon: Icons.restaurant_rounded,
    ),
    _CategoryItem(
      id: 'Angkringan',
      label: 'Angkringan',
      icon: Icons.storefront_rounded,
    ),
  ];

  String _selectedCategoryId = 'all';
  List<Restaurant> _allRestaurants = [];
  Profile? _profile;
  List<Restaurant> _picks = []; // Rekomendasi terdekat (LBS)
  List<AiRecommendationResult> _aiPicks = []; // Rekomendasi personal AI
  UserAiProfile? _aiProfile;
  bool _loading = true;
  int _page = 0;
  int _aiPage = 0;
  StreamSubscription<void>? _profileSub;

  @override
  void initState() {
    super.initState();
    LocationService.instance.currentLocation.addListener(_onLocationUpdated);
    LocationService.instance.isLoading.addListener(_onLocationLoadingChanged);
    AiRecommendationService.instance.profileNotifier.addListener(
      _onAiProfileUpdated,
    );
    _load();
    // Auto-detect lokasi GPS pengguna saat aplikasi dibuka
    LocationService.instance.fetchGpsLocation();
    _profileSub = _svc.onProfileChanged.listen((_) {
      if (mounted) {
        _isLoadingData = false;
        _load();
      }
    });
  }

  void _onLocationUpdated() {
    if (!mounted) return;
    final loc = LocationService.instance.currentLocation.value;
    if (loc != null) {
      widget.onLocationFetched?.call(loc.lat, loc.lng);
    }
    _load();
  }

  void _onLocationLoadingChanged() {
    if (mounted) setState(() {});
  }

  void _onAiProfileUpdated() {
    if (!mounted) return;
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && widget.name.trim().isNotEmpty) {
      if (_profile != null) {
        setState(() {
          _profile = Profile(
            id: _profile!.id,
            displayName: widget.name,
            avatarUrl: _profile!.avatarUrl,
            activeBorderId: _profile!.activeBorderId,
            points: _profile!.points,
            createdAt: _profile!.createdAt,
          );
        });
      } else {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    LocationService.instance.currentLocation.removeListener(_onLocationUpdated);
    LocationService.instance.isLoading.removeListener(
      _onLocationLoadingChanged,
    );
    AiRecommendationService.instance.profileNotifier.removeListener(
      _onAiProfileUpdated,
    );
    _profileSub?.cancel();
    _pageCtrl.dispose();
    _aiPageCtrl.dispose();
    super.dispose();
  }

  bool _isLoadingData = false;

  Future<void> _load() async {
    if (_isLoadingData) return;
    _isLoadingData = true;

    try {
      final results = await Future.wait([
        _svc.getProfile(),
        _svc.getRestaurants(),
        _svc.getCategories(),
        AiRecommendationService.instance.getProfile(),
      ]);
      final rawRestos = results[1] as List<Restaurant>;
      var restos = List<Restaurant>.of(rawRestos);
      final aiProf = results[3] as UserAiProfile?;

      final loc = LocationService.instance.currentLocation.value;
      double? userLat;
      double? userLng;

      // Jika sudah ada koordinat pengguna → sort by jarak terdekat (LBS)
      if (loc != null && (loc.lat != 0 || loc.lng != 0)) {
        userLat = loc.lat;
        userLng = loc.lng;
        restos.sort((a, b) {
          final dA = LocationService.instance.distanceM(
            userLat!,
            userLng!,
            a.lat,
            a.lng,
          );
          final dB = LocationService.instance.distanceM(
            userLat,
            userLng,
            b.lat,
            b.lng,
          );
          return dA.compareTo(dB);
        });
      } else {
        // Fallback: sort by rating jika lokasi belum tersedia
        restos.sort((a, b) => b.rating.compareTo(a.rating));
      }

      // Proses Rekomendasi Cerdas AI jika profil sudah diisi
      List<AiRecommendationResult> aiResults = [];
      if (aiProf != null && aiProf.isCompleted) {
        aiResults = AiRecommendationService.instance.rankRestaurants(
          restaurants: rawRestos,
          profile: aiProf,
          userLat: userLat,
          userLng: userLng,
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile?;
        _allRestaurants = List<Restaurant>.of(rawRestos);
        _picks = restos;
        _aiProfile = aiProf;
        _aiPicks = aiResults.take(6).toList();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading home tab: $e');
    } finally {
      if (mounted) _isLoadingData = false;
    }
  }

  List<Restaurant> get _filteredPicks {
    if (_selectedCategoryId == 'all') {
      return _picks.take(10).toList();
    }
    final filtered = _allRestaurants.where((r) {
      final cat = r.category.toLowerCase();
      if (_selectedCategoryId == 'Fast Food') {
        return cat.contains('fast food') ||
            (r.dishType?.contains('burger') ?? false) ||
            (r.dishType?.contains('pizza') ?? false) ||
            (r.dishType?.contains('steak') ?? false);
      }
      if (_selectedCategoryId == 'Cafe') {
        return cat.contains('cafe') ||
            (r.dishType?.contains('kopi') ?? false) ||
            (r.dishType?.contains('minuman') ?? false);
      }
      if (_selectedCategoryId == 'Warung Tradisional') {
        return cat.contains('warung') ||
            cat.contains('tradisional') ||
            (r.dishType?.contains('jawa') ?? false) ||
            (r.dishType?.contains('padang') ?? false) ||
            (r.dishType?.contains('soto') ?? false) ||
            (r.dishType?.contains('bakso') ?? false);
      }
      if (_selectedCategoryId == 'Food Court') {
        return cat.contains('food court') ||
            (r.dishType?.contains('kue') ?? false) ||
            (r.dishType?.contains('bakpia') ?? false);
      }
      return cat.contains(_selectedCategoryId.toLowerCase());
    }).toList();

    return filtered.isNotEmpty ? filtered.take(10).toList() : _picks.take(10).toList();
  }

  void _open(Restaurant r) {
    if (widget.onOpenRestaurant != null) {
      widget.onOpenRestaurant!(r);
    } else {
      widget.onSeeAll?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pName = _profile?.displayName.trim();
    final wName = widget.name.trim();
    final activeName = (pName != null && pName.isNotEmpty)
        ? pName
        : (wName.isNotEmpty)
        ? wName
        : 'Foodie';
    final first = activeName.split(' ').first;

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.orange,
          onRefresh: () async {
            await LocationService.instance.fetchGpsLocation();
            await _load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              _header(first),
              const SizedBox(height: 18),
              _categoryRow(),
              const SizedBox(height: 18),
              _bannerCard(),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Popular Recipes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.charcoal,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onSeeAll,
                    child: const Text(
                      'Lihat semua',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _popularRecipesGrid(),
              const SizedBox(height: 26),
              // ── GPS / Lokasi Widget (Modul VI LBS) ──
              _gpsWidget(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Header (Foto Profil + Teks Awal + Lonceng) ----------
  Widget _header(String first) {
    final avatarUrl = _profile?.avatarUrl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Foto profil pengguna
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: ClipOval(
            child: (avatarUrl != null && avatarUrl.isNotEmpty)
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.person_rounded,
                      color: AppColors.charcoal,
                      size: 26,
                    ),
                  )
                : const Icon(
                    Icons.person_rounded,
                    color: AppColors.charcoal,
                    size: 26,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        // Teks header seperti awal tadi
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sugeng Rawuh, $first',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(22),
              ),
              const SizedBox(height: 2),
              const Text(
                'Mau makan enak apa hari ini?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Lonceng notifikasi
        ValueListenableBuilder(
          valueListenable: HiveService.instance.settingsListenable,
          builder: (_, _, _) {
            final bool hasBadge =
                HiveService.instance.getActiveRemindersCount() > 0;
            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_rounded,
                      size: 22,
                      color: AppColors.charcoal,
                    ),
                  ),
                  if (hasBadge)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------- Kotak Banner (Warna Seperti Navbar) ----------
  Widget _bannerCard() {
    return GestureDetector(
      onTap: () => widget.onSeeAll?.call(),
      child: Container(
        height: 148,
        decoration: BoxDecoration(
          color: AppColors.greenDark, // Warna sama persis seperti navbar
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.greenDark.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Konten teks di sebelah kiri
            Positioned(
              left: 20,
              top: 18,
              bottom: 18,
              right: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PENAWARAN SPESIAL',
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w800,
                            color: AppColors.yellow,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Diskon s/d 30%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Nikmati kuliner favorit pilihanmu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Lihat Promo →',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Ilustrasi / gambar kuliner di sebelah kanan dengan fade transparan
            Positioned(
              right: -10,
              top: -10,
              bottom: -10,
              width: 155,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.black],
                    stops: [0.0, 0.3],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: Image.network(
                  'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=600&q=80',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Icon(
                      Icons.restaurant_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  //               child: Image.network(
  //                 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=600&q=80',
  //                 fit: BoxFit.cover,
  //                 errorBuilder: (_, _, _) => Center(
  //                   child: Icon(
  //                     Icons.restaurant_rounded,
  //                     size: 64,
  //                     color: Colors.white.withValues(alpha: 0.2),
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // ---------- Category Icons Row (100% Persis Gambar) ----------
  Widget _categoryRow() {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categoryItems.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = _categoryItems[index];
          final isSelected = item.id == _selectedCategoryId;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryId = item.id;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.yellow
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.yellow.withValues(alpha: 0.45),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    item.icon,
                    size: 26,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected
                        ? AppColors.charcoal
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- GPS & Location Widget ----------
  void _showLocationPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationPickerSheet(onLocationChanged: _load),
    );
  }

  Widget _gpsWidget() {
    final loc = LocationService.instance.currentLocation.value;
    final isLoading = LocationService.instance.isLoading.value;

    final displayAddr = loc?.address ?? 'Pusat Kota Yogyakarta';
    final isGps = loc?.isGps ?? false;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showLocationPickerSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLoading
                    ? AppColors.tint(AppColors.orange, 0.12)
                    : (isGps
                          ? AppColors.tint(AppColors.greenDark, 0.12)
                          : AppColors.tint(AppColors.orange, 0.1)),
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.orange,
                      ),
                    )
                  : Icon(
                      isGps
                          ? Icons.my_location_rounded
                          : Icons.location_on_rounded,
                      size: 20,
                      color: isGps ? AppColors.greenDark : AppColors.orange,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Lokasi Kuliner Terdekat',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: isGps
                              ? AppColors.tint(AppColors.greenDark, 0.15)
                              : AppColors.tint(AppColors.orange, 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isGps ? 'GPS AKTIF' : 'WILAYAH',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: isGps
                                ? AppColors.greenDark
                                : AppColors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayAddr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Ketuk untuk ubah lokasi atau GPS',
                    style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ubah',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: AppColors.charcoal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Rekomendasi Cerdas AI (Smart Match) ----------
  Widget _aiRecommendationSection() {
    final aiProf = _aiProfile;
    final isComplete = aiProf != null && aiProf.isCompleted;

    if (!isComplete) {
      return _aiActivationBanner();
    }

    if (_aiPicks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rekomendasi Untukmu', style: AppText.display(20)),
                  Text(
                    'Sesuai dengan preferensi rasa, budget, dan lokasimu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AiProfilePage())),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.orange, 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 12, color: AppColors.orange),
                    SizedBox(width: 4),
                    Text(
                      'Ubah Preferensi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _aiCarousel(),
      ],
    );
  }

  Widget _aiActivationBanner() {
    return GestureDetector(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AiProfilePage())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: HomeColors.restoCardBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.orange, 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rekomendasi Sesuai Selera',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Atur preferensi rasa & budget makanmu',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Atur',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aiCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 205,
          child: PageView.builder(
            controller: _aiPageCtrl,
            padEnds: false,
            physics: const BouncingScrollPhysics(),
            itemCount: _aiPicks.length,
            onPageChanged: (i) {
              if (mounted) setState(() => _aiPage = i);
            },
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _aiCard(_aiPicks[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _aiPicks.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _aiPage ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _aiPage ? AppColors.orange : AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _aiCard(AiRecommendationResult result) {
    final r = result.restaurant;
    final distStr = result.distanceKm > 0
        ? '${result.distanceKm.toStringAsFixed(1)} km'
        : '15 mins';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 135,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RestaurantImage(
                      imageUrl: r.imageUrl,
                      category: r.category,
                      dishType: r.dishType,
                    ),
                    // Badge waktu / jarak di kiri atas (desain pill semi-transparan)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distStr,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Badge rating di kanan bawah (pill kuning dengan bintang hitam)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HomeColors.ratingBadge,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: AppColors.charcoal,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              r.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${r.category} • ${r.priceRange}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Popular Recipes 2-Column Grid (100% Persis Gambar) ----------
  Widget _popularRecipesGrid() {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }
    final items = _filteredPicks;
    if (items.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Belum ada kuliner di kategori ini.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.69,
      ),
      itemBuilder: (_, i) => _gridCard(items[i]),
    );
  }

  Widget _gridCard(Restaurant r) {
    // Hitung jarak jika koordinat tersedia
    String? distLabel;
    final loc = LocationService.instance.currentLocation.value;
    if (loc != null && (r.lat != 0 || r.lng != 0)) {
      final dist = LocationService.instance.distanceM(
        loc.lat,
        loc.lng,
        r.lat,
        r.lng,
      );
      distLabel = LocationService.instance.formatDistance(dist);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RestaurantImage(
                      imageUrl: r.imageUrl,
                      category: r.category,
                      dishType: r.dishType,
                    ),
                    // Badge waktu / jarak di kiri atas (desain pill semi-transparan persis seperti gambar)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distLabel ?? '15 mins',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Badge rating di kanan bawah (pill kuning dengan bintang hitam persis seperti gambar)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.charcoal,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              r.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${r.category} • ${r.priceRange}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  final VoidCallback onLocationChanged;

  const _LocationPickerSheet({required this.onLocationChanged});

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _locSvc = LocationService.instance;

  @override
  Widget build(BuildContext context) {
    final isGpsLoading = _locSvc.isLoading.value;
    final currentLoc = _locSvc.currentLocation.value;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.orange, 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pilih Titik Lokasi Kamu',
                      style: AppText.display(18),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Rekomendasi terdekat dihitung dari titik ini',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tutup',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tombol GPS Otomatis
          InkWell(
            onTap: isGpsLoading
                ? null
                : () async {
                    setState(() {});
                    final scaffold = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    final ok = await _locSvc.fetchGpsLocation();
                    if (!mounted) return;
                    setState(() {});
                    if (ok) {
                      nav.pop();
                      widget.onLocationChanged();
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Lokasi GPS berhasil diperbarui: ${_locSvc.currentLocation.value?.address ?? ''} 📍',
                          ),
                          backgroundColor: AppColors.greenDark,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      final msg = _locSvc.statusMessage.value ?? 'Gagal mengakses GPS';
                      scaffold.showSnackBar(
                        SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.charcoal,
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'Pengaturan',
                            textColor: AppColors.yellow,
                            onPressed: () => Geolocator.openAppSettings(),
                          ),
                        ),
                      );
                    }
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (currentLoc?.isGps ?? false)
                    ? AppColors.tint(AppColors.greenDark, 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isGpsLoading
                          ? AppColors.tint(AppColors.orange, 0.15)
                          : ((currentLoc?.isGps ?? false)
                              ? AppColors.greenDark
                              : Colors.white),
                      shape: BoxShape.circle,
                    ),
                    child: isGpsLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.orange,
                            ),
                          )
                        : Icon(
                            Icons.my_location_rounded,
                            size: 20,
                            color: (currentLoc?.isGps ?? false)
                                ? Colors.white
                                : AppColors.charcoal,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Gunakan Lokasi GPS Saya',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (currentLoc?.isGps ?? false) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.greenDark,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AKTIF',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isGpsLoading
                              ? (_locSvc.statusMessage.value ?? 'Mencari koordinat GPS...')
                              : ((currentLoc?.isGps ?? false)
                                  ? currentLoc!.address
                                  : 'Deteksi koordinat posisi ponsel saat ini'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(child: Divider(color: AppColors.line)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'ATAU PILIH WILAYAH KULINER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.line)),
            ],
          ),
          const SizedBox(height: 12),

          // Daftar Preset Wilayah
          ...LocationService.presetRegions.map((reg) {
            final name = reg['name'] as String;
            final desc = reg['desc'] as String;
            final city = reg['city'] as String;
            final lat = reg['lat'] as double;
            final lng = reg['lng'] as double;

            final isSelected = !(currentLoc?.isGps ?? true) &&
                (currentLoc?.city == city || currentLoc?.address.contains(name) == true);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final scaffold = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(context);
                  await _locSvc.setManualLocation(
                    name: name,
                    address: '$name, $desc',
                    city: city,
                    lat: lat,
                    lng: lng,
                  );
                  if (!mounted) return;
                  nav.pop();
                  widget.onLocationChanged();
                  scaffold.showSnackBar(
                    SnackBar(
                      content: Text('Lokasi aktif diatur ke $name'),
                      backgroundColor: AppColors.greenDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.tint(AppColors.orange, 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.place_rounded,
                        size: 20,
                        color: isSelected ? AppColors.orange : AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? AppColors.orange : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

