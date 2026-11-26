import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../models/restaurant.dart';
import '../models/review.dart';
import '../models/seed_data.dart';
import '../models/user_ai_profile.dart';
import '../props/app_colors.dart';
import '../props/app_text.dart';
import '../services/ai_recommendation_service.dart';
import '../services/supabase_service.dart';
import '../services/hive_service.dart';
import '../widgets/auth_widgets.dart';
import '../widgets/common_widgets.dart';
import 'ai_profile_page.dart';
import 'detail_page.dart';
import 'intro.dart';
import 'saran_kesan_page.dart';
import '../widgets/restaurant_image.dart';

class ProfileTab extends StatefulWidget {
  final String name;
  final bool fromRegister;
  final void Function(String? url)? onAvatarChanged;
  final void Function(String name)? onNameChanged;
  final VoidCallback? onBackToHome;

  const ProfileTab({
    super.key,
    required this.name,
    this.fromRegister = false,
    this.onAvatarChanged,
    this.onNameChanged,
    this.onBackToHome,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  Profile? _profile;
  UserAiProfile? _aiProfile;
  Map<String, int> _stats = {'reviews': 0};
  bool _loading = true;

  // Tab controller untuk JEJAK KULINER (Ulasan, Pencarian)
  late final TabController _histTab = TabController(length: 2, vsync: this);

  // Data history pencarian & ulasan
  List<Map<String, dynamic>> _searchHistory = [];
  List<Review> _myReviews = [];
  bool _histLoading = true;

  StreamSubscription<void>? _profileSub;
  StreamSubscription<Review>? _reviewAddedSub;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHistory();
    _subscribeRealtime();
    AiRecommendationService.instance.profileNotifier.addListener(
      _onAiProfileChanged,
    );
    _loadAiProfile();
  }

  void _onAiProfileChanged() {
    if (mounted) {
      setState(() {
        _aiProfile = AiRecommendationService.instance.profileNotifier.value;
      });
    }
  }

  Future<void> _loadAiProfile() async {
    final p = await AiRecommendationService.instance.getProfile();
    if (mounted) setState(() => _aiProfile = p);
  }

  void _subscribeRealtime() {
    final svc = SupabaseService.instance;
    _profileSub = svc.onProfileChanged.listen((_) {
      if (!mounted) return;
      _load();
    });

    _reviewAddedSub = svc.onReviewAdded.listen((rev) {
      if (!mounted) return;
      setState(() {
        if (!_myReviews.any((r) => r.id == rev.id)) {
          _myReviews.insert(0, rev);
        }
        _stats['reviews'] = (_stats['reviews'] ?? 0) + 1;
      });
      _load();
      _loadHistory();
    });
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && widget.name.trim().isNotEmpty) {
      setState(() {
        _profile = _profile?.copyWith(displayName: widget.name);
      });
    }
  }

  @override
  void dispose() {
    AiRecommendationService.instance.profileNotifier.removeListener(
      _onAiProfileChanged,
    );
    _profileSub?.cancel();
    _reviewAddedSub?.cancel();
    _histTab.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final svc = SupabaseService.instance;
    final results = await Future.wait([
      svc.getSearchHistory(),
      svc.getUserReviews(),
    ]);
    if (!mounted) return;
    setState(() {
      _searchHistory = results[0] as List<Map<String, dynamic>>;
      _myReviews = results[1] as List<Review>;
      _stats['reviews'] = _myReviews.length;
      _histLoading = false;
    });
  }

  // ─── EDIT PROFILE SHEET ───

  void _showEditProfile() {
    final nameCtrl = TextEditingController(
      text: _profile?.displayName ?? widget.name,
    );
    String? tempAvatarUrl = _profile?.avatarUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text('Edit Profil', style: AppText.display(20)),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Avatar area ──
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await _showPhotoSourceSheet(
                            parentContext: ctx,
                            hasExistingPhoto:
                                tempAvatarUrl != null &&
                                tempAvatarUrl!.trim().isNotEmpty,
                            onPicked: (url) {
                              tempAvatarUrl = url;
                              setSheet(() {});
                            },
                            onDeletePhoto: () {
                              tempAvatarUrl = null;
                              setSheet(() {});
                            },
                          );
                        },
                        child: Stack(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AvatarImage(
                                url: tempAvatarUrl,
                                size: 84,
                                fallbackText: nameCtrl.text.isNotEmpty
                                    ? nameCtrl.text
                                    : 'F',
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppColors.orange,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.charcoal,
                              side: const BorderSide(color: AppColors.line),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                            ),
                            icon: const Icon(
                              Icons.add_a_photo_rounded,
                              size: 16,
                              color: AppColors.orange,
                            ),
                            label: Text(
                              (tempAvatarUrl != null &&
                                      tempAvatarUrl!.trim().isNotEmpty)
                                  ? 'Ubah Foto'
                                  : 'Pilih Foto',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () async {
                              await _showPhotoSourceSheet(
                                parentContext: ctx,
                                hasExistingPhoto:
                                    tempAvatarUrl != null &&
                                    tempAvatarUrl!.trim().isNotEmpty,
                                onPicked: (url) {
                                  tempAvatarUrl = url;
                                  setSheet(() {});
                                },
                                onDeletePhoto: () {
                                  tempAvatarUrl = null;
                                  setSheet(() {});
                                },
                              );
                            },
                          ),
                          if (tempAvatarUrl != null &&
                              tempAvatarUrl!.trim().isNotEmpty) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.red,
                                side: const BorderSide(color: AppColors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'Hapus',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: () {
                                tempAvatarUrl = null;
                                setSheet(() {});
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Nama ──
                const Text(
                  'Nama Lengkap',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nama Anda',
                    filled: true,
                    fillColor: AppColors.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.orange,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Tombol simpan ──
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.charcoal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      final newName = nameCtrl.text.trim();
                      if (newName.isEmpty) return;
                      Navigator.pop(ctx);

                      final cleanAvatar =
                          (tempAvatarUrl != null &&
                              tempAvatarUrl!.trim().isNotEmpty)
                          ? tempAvatarUrl!.trim()
                          : null;

                      final activeBorder = _profile?.activeBorderId;

                      setState(() {
                        _profile = _profile != null
                            ? _profile!.copyWith(
                                displayName: newName,
                                avatarUrl: cleanAvatar,
                                activeBorderId: activeBorder,
                              )
                            : Profile(
                                id: SupabaseService.instance.userId ?? 'curator_user',
                                displayName: newName,
                                avatarUrl: cleanAvatar,
                                activeBorderId: activeBorder,
                                points: 100,
                                createdAt: DateTime.now(),
                              );
                      });
                      widget.onNameChanged?.call(newName);
                      widget.onAvatarChanged?.call(cleanAvatar);

                      // 2. Simpan permanen ke SharedPreferences & Supabase
                      await SupabaseService.instance.upsertProfile(
                        displayName: newName,
                        avatarUrl: cleanAvatar,
                        activeBorderId: activeBorder,
                      );
                      await _load();
                      await _loadHistory();

                      if (mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text('Profil berhasil diperbarui.'),
                              backgroundColor: AppColors.greenDark,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                      }
                    },
                    child: const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAvatar({
    required ImageSource source,
    required void Function(String?) onPicked,
  }) async {
    final picker = ImagePicker();
    XFile? picked;
    final sourceName = source == ImageSource.camera ? 'kamera' : 'galeri';
    try {
      picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengakses $sourceName: ${e.toString().split(':').first}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (picked == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Memproses foto dari $sourceName...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.charcoal,
      ),
    );

    final uid = SupabaseService.instance.userId ?? 'curator_user';
    String? uploadedUrl;
    try {
      final bytes = await picked.readAsBytes();
      String ext = 'jpg';
      if (picked.name.contains('.')) {
        ext = picked.name.split('.').last.toLowerCase();
      }
      final mimeType = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final filePath = '$uid/profile.$ext';
      final supabase = Supabase.instance.client;

      try {
        await supabase.storage
            .from('avatars')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );

        uploadedUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
        uploadedUrl = '$uploadedUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      } catch (storageErr) {
        debugPrint('Supabase storage upload fallback to base64: $storageErr');
        final b64 = base64Encode(bytes);
        uploadedUrl = 'data:$mimeType;base64,$b64';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Gagal memproses foto: ${e.toString().split(':').first}',
              ),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    onPicked(uploadedUrl);
  }

  Future<void> _showPhotoSourceSheet({
    required BuildContext parentContext,
    required void Function(String?) onPicked,
    required VoidCallback onDeletePhoto,
    required bool hasExistingPhoto,
  }) async {
    final act = await showModalBottomSheet<String>(
      context: parentContext,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pilih Sumber Foto Profil',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(sheetCtx),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _photoSourceTile(
                ctx: sheetCtx,
                icon: Icons.camera_alt_rounded,
                title: 'Ambil Foto dari Kamera',
                subtitle: 'Gunakan kamera perangkat untuk mengambil foto baru',
                color: AppColors.orange,
                action: 'camera',
              ),
              const SizedBox(height: 10),
              _photoSourceTile(
                ctx: sheetCtx,
                icon: Icons.photo_library_rounded,
                title: 'Pilih dari Galeri',
                subtitle: 'Pilih foto yang tersimpan di album perangkat',
                color: AppColors.slateBlue,
                action: 'gallery',
              ),
              if (hasExistingPhoto) ...[
                const SizedBox(height: 10),
                _photoSourceTile(
                  ctx: sheetCtx,
                  icon: Icons.delete_outline_rounded,
                  title: 'Hapus Foto Profil',
                  subtitle: 'Gunakan inisial nama Anda sebagai avatar',
                  color: AppColors.red,
                  action: 'delete',
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (act == 'camera') {
      await _pickAvatar(source: ImageSource.camera, onPicked: onPicked);
    } else if (act == 'gallery') {
      await _pickAvatar(source: ImageSource.gallery, onPicked: onPicked);
    } else if (act == 'delete') {
      onDeletePhoto();
    }
  }

  Widget _photoSourceTile({
    required BuildContext ctx,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String action,
  }) {
    final isDelete = action == 'delete';
    return InkWell(
      onTap: () => Navigator.pop(ctx, action),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isDelete ? AppColors.red : AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted.withValues(alpha: 0.5),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        SupabaseService.instance.getProfile(),
        SupabaseService.instance.getUserStats(),
      ]);
      if (!mounted) return;
      final prof = results[0] as Profile?;
      final stats = results[1] as Map<String, int>;

      setState(() {
        _profile = prof;
        _stats = stats;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar akun?'),
        content: const Text('Kamu perlu login lagi untuk masuk ke FOODIE.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await SupabaseService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const IntroPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final name = _profile?.displayName.isNotEmpty == true
        ? _profile!.displayName
        : widget.name.trim().isNotEmpty
        ? widget.name.trim()
        : (currentUser?.userMetadata?['name'] as String? ?? 'Pengguna FOODIE');
    final email =
        currentUser?.email ??
        (widget.name.isNotEmpty
            ? '${widget.name.toLowerCase().replaceAll(' ', '.')}@foodie.id'
            : 'user@foodie.id');
    return PageBackground(
      child: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              )
            : RefreshIndicator(
                color: AppColors.orange,
                onRefresh: () async {
                  await _load();
                  await _loadHistory();
                },
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (widget.onBackToHome != null) {
                              widget.onBackToHome!();
                            } else if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.line, width: 1),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x08000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: AppColors.charcoal,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Profil', style: AppText.display(22)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _accountCard(name, email),
                    if (widget.fromRegister) ...[
                      const SizedBox(height: 12),
                      _welcomeBanner(),
                    ],
                    const SizedBox(height: 14),
                    _aiPersonaCard(),
                    const SizedBox(height: 18),

                    // ── Jejak Kuliner ──
                    _sectionLabel('JEJAK KULINER'),
                    const SizedBox(height: 8),
                    _historySection(),
                    const SizedBox(height: 20),

                    // ── Preferensi Sistem ──
                    _sectionLabel('PREFERENSI SISTEM'),
                    const SizedBox(height: 8),
                    _group([
                      _tile(
                        Icons.rate_review_rounded,
                        'Saran & Kesan',
                        trailing: 'Praktikum Mobile',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SaranKesanPage(),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _logoutButton(),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'FOODIE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── HISTORY SECTION ───

  // ─── JEJAK KULINER SECTION (TAB: ULASAN, FAVORIT, PENCARIAN) ───

  Widget _historySection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Segmented Tab Bar Modern
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F4F0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: TabBar(
              controller: _histTab,
              labelColor: AppColors.charcoal,
              unselectedLabelColor: AppColors.textMuted,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              labelStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rate_review_rounded, size: 13),
                      const SizedBox(width: 4),
                      Text('Ulasan (${_myReviews.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 13),
                      const SizedBox(width: 4),
                      Text('Pencarian (${_searchHistory.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 290,
            child: _histLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.orange),
                  )
                : TabBarView(
                    controller: _histTab,
                    children: [
                      _reviewsTab(),
                      _searchHistoryTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _reviewsTab() {
    if (_myReviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rate_review_rounded,
                  size: 26,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Belum Ada Ulasan Ditulis',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kunjungi restoran favoritmu dan bagikan pengalaman rasa pertama Anda!',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: _myReviews.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final rev = _myReviews[i];
        final restoName =
            (rev.restaurantName != null &&
                rev.restaurantName!.isNotEmpty &&
                rev.restaurantName != rev.restaurantId)
            ? rev.restaurantName!
            : (kDefaultRestaurants
                      .where(
                        (r) =>
                            r.id == rev.restaurantId ||
                            r.id == 'resto_${rev.restaurantId}' ||
                            (rev.restaurantId.startsWith('resto_') &&
                                r.id ==
                                    rev.restaurantId.replaceFirst(
                                      'resto_',
                                      '',
                                    )),
                      )
                      .firstOrNull
                      ?.name ??
                  'Tempat Kuliner');

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final resto =
                await SupabaseService.instance.getRestaurant(
                  rev.restaurantId,
                ) ??
                kDefaultRestaurants
                    .where(
                      (r) =>
                          r.id == rev.restaurantId ||
                          r.id == 'resto_${rev.restaurantId}' ||
                          (rev.restaurantId.startsWith('resto_') &&
                              r.id ==
                                  rev.restaurantId.replaceFirst('resto_', '')),
                    )
                    .firstOrNull;
            if (resto != null && mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetailPage(restaurant: resto),
                ),
              );
              _load();
              _loadHistory();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line.withValues(alpha: 0.6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.restaurant_rounded,
                    size: 18,
                    color: AppColors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restoName,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: List.generate(
                          5,
                          (j) => Icon(
                            j < rev.rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 12.5,
                            color: AppColors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        rev.comment.isNotEmpty
                            ? rev.comment
                            : 'Tidak ada ulasan tertulis',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textDark,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _searchHistoryTab() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  size: 26,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Belum Ada Riwayat Pencarian',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kata kunci pencarian kuliner Anda akan tersimpan otomatis di sini.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_searchHistory.length} kata kunci tersimpan',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text('Hapus Semua Riwayat?'),
                      content: const Text(
                        'Semua jejak kata kunci pencarian Anda akan dihapus.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.red,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Hapus Semua'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await SupabaseService.instance.clearSearchHistory();
                    setState(() => _searchHistory = []);
                  }
                },
                child: const Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 13,
                      color: AppColors.red,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Hapus semua',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.red,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchHistory.map((item) {
                final q = item['query'] as String? ?? '';
                if (q.trim().isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.line.withValues(alpha: 0.8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 13,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        q,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          await SupabaseService.instance.removeSearchItem(q);
                          setState(
                            () => _searchHistory.removeWhere(
                              (e) => e['query'] == q,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _aiPersonaCard() {
    final p = _aiProfile;
    final bool isComplete = p != null && p.isCompleted;
    final personaTitle = isComplete
        ? (p!.personaSummary.isNotEmpty ? p.personaSummary : 'Personalisasi Kuliner AI')
        : 'Personalisasi Kuliner AI';
    final personaSummary = isComplete
        ? p!.personaSummary
        : 'Sesuaikan selera rasa, pantangan & budget untuk rekomendasi kuliner AI yang akurat.';

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const AiProfilePage()));
        _loadAiProfile();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.greenDark,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.greenDark.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Decorative background circular glow
            Positioned(
              right: -25,
              bottom: -25,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.yellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 11,
                              color: AppColors.yellow,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'PERSONALISASI KULINER',
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w800,
                                color: AppColors.yellow,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (isComplete)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '100% Aktif',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    personaTitle,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    personaSummary,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.35,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
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
                          'Atur Selera →',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountCard(String name, String email) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar — bisa foto atau inisial
          GestureDetector(
            onTap: _showEditProfile,
            child: Stack(
              children: [
                AvatarImage(
                  url: _profile?.avatarUrl,
                  size: 56,
                  fallbackText: name.isNotEmpty ? name : 'F',
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _showEditProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_rounded, size: 20, color: AppColors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Akun berhasil dibuat! Lengkapi profilmu agar rekomendasi makin pas.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
      ),
    );
  }

  Widget _group(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 52,
                color: AppColors.line.withValues(alpha: 0.6),
              ),
          ],
        ],
      ),
    );
  }

  Widget _iconBox(IconData icon) {
    return Icon(icon, size: 21, color: AppColors.greenDark);
  }

  Widget _tile(
    IconData icon,
    String title, {
    String? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        leading: _iconBox(icon),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.greenDark,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null)
              Text(
                trailing,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
        onTap: onTap ?? () {},
      ),
    );
  }

  Widget _logoutButton() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Keluar Akun',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
