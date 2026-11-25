import 'dart:async';

import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../props/app_colors.dart';
import '../props/app_text.dart';
import '../services/supabase_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/restaurant_image.dart';
import 'detail_page.dart';

class FavoritesPage extends StatefulWidget {
  final bool isTab;
  const FavoritesPage({super.key, this.isTab = false});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Restaurant>? _favorites;
  bool _favLoading = true;
  String? _favError;
  StreamSubscription<Set<String>>? _favSub;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _favSub = SupabaseService.instance.favoritesStream.listen((_) {
      if (mounted) _loadFavorites();
    });
  }

  @override
  void dispose() {
    _favSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _favLoading = true;
      _favError = null;
    });
    try {
      final list = await SupabaseService.instance.getFavoriteRestaurants();
      if (mounted) setState(() => _favorites = list);
    } catch (e) {
      if (mounted) setState(() => _favError = e.toString());
    } finally {
      if (mounted) setState(() => _favLoading = false);
    }
  }

  Future<void> _removeFavorite(Restaurant r) async {
    await SupabaseService.instance.toggleFavorite(r.id);
    if (!mounted) return;
    setState(() {
      _favorites?.removeWhere((item) => item.id == r.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${r.name} dihapus dari favorit'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _openDetail(Restaurant r) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => DetailPage(restaurant: r)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(),
              Expanded(child: _favoritesTab()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (!widget.isTab && Navigator.of(context).canPop()) ...[
            InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Restoran Favorit', style: AppText.display(20)),
                const Text(
                  'Daftar kuliner pilihan yang kamu simpan',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _favoritesTab() {
    if (_favLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.orange),
      );
    }
    if (_favError != null) {
      return _errorState(_favError!, _loadFavorites);
    }
    if (_favorites == null || _favorites!.isEmpty) {
      return _emptyState(
        Icons.favorite_border,
        'Belum ada restoran favorit',
        'Jelajahi kuliner dan ketuk ikon hati untuk menyimpannya di sini.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: AppColors.orange,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _favorites!.length,
        itemBuilder: (_, i) {
          final r = _favorites![i];
          return _FavoriteCardItem(
            restaurant: r,
            onTap: () => _openDetail(r),
            onRemove: () => _removeFavorite(r),
          );
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.red),
          const SizedBox(height: 8),
          const Text('Gagal memuat data'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

class _FavoriteCardItem extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteCardItem({
    required this.restaurant,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final r = restaurant;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: RestaurantImage(
                    imageUrl: r.imageUrl,
                    category: r.category,
                    dishType: r.dishType,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.address,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      r.priceRange,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenDark,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.red,
                ),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

