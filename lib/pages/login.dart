import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../props/app_colors.dart';
import '../props/app_text.dart';
import '../utils/validators.dart';
import '../widgets/buttons.dart';
import '../widgets/foodie_logo.dart';
import '../widgets/text_field.dart';
import 'home.dart';
import 'onboarding.dart';
import 'register.dart';
import 'verify_email.dart';
import 'forgot_password_page.dart';
import '../services/supabase_service.dart';

class LoginPage extends StatefulWidget {
  final String? initialEmail;
  const LoginPage({super.key, this.initialEmail});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  bool _remember = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg, {Color bg = AppColors.charcoal, IconData? icon, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: icon != null
            ? Row(
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(msg)),
                ],
              )
            : Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _saveUserSession(String name, String email, [String? password]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = Supabase.instance.client.auth.currentUser?.id;
      final existingName = uid != null ? prefs.getString('foodie_name_$uid') : null;
      final emailPrefix = email.split('@').first;
      final effectiveName = (existingName != null && existingName.trim().isNotEmpty && (name == emailPrefix || name.isEmpty))
          ? existingName.trim()
          : name;

      await prefs.setString('foodie_last_user_name', effectiveName);
      await prefs.setString('foodie_current_display_name', effectiveName);
      if (uid != null) await prefs.setString('foodie_name_$uid', effectiveName);
      await prefs.setString('foodie_last_user_email', email);

      if (password != null && password.isNotEmpty) {
        await prefs.setString('foodie_saved_password', password);
      }
    } catch (_) {}
  }

  void _goHome(String name) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomePage(name: name)),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final pwd = _password.text;
    final emailText = _email.text.trim();
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: emailText,
        password: pwd,
      );
      if (!mounted) return;
      setState(() => _loading = false);

      // Cegah login jika email belum diverifikasi di database
      if (res.user != null && res.user!.emailConfirmedAt == null) {
        await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
        if (!mounted) return;
        setState(() => _loading = false);
        _showSnackBar(
          'Email belum diverifikasi. Harap verifikasi kode OTP terlebih dahulu.',
          bg: AppColors.red,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyEmailPage(
              name: emailText.split('@').first,
              email: emailText,
              password: pwd,
            ),
          ),
        );
        return;
      }

      await SupabaseService.instance.initStorage(force: true);
      final prof = await SupabaseService.instance.getProfile();
      final name = (prof?.displayName != null && prof!.displayName.trim().isNotEmpty)
          ? prof.displayName.trim()
          : ((res.user?.userMetadata?['name'] as String?)?.trim().isNotEmpty == true
              ? (res.user!.userMetadata!['name'] as String).trim()
              : emailText.split('@').first);

      await _saveUserSession(name, emailText, pwd);
      if (!mounted) return;
      _goHome(name);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      String msg = e.message;
      if (msg.toLowerCase().contains('invalid login credentials')) {
        msg = 'Email atau kata sandi salah. Silakan periksa kembali.';
      } else if (msg.toLowerCase().contains('email not confirmed')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Email Anda belum diverifikasi. Masukkan kode OTP terlebih dahulu.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Verifikasi',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await Supabase.instance.client.auth.resend(
                    type: OtpType.signup,
                    email: emailText,
                  );
                } catch (_) {}
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VerifyEmailPage(
                      name: emailText.split('@').first,
                      email: emailText,
                      password: pwd,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        return;
      }
      _showSnackBar(msg, bg: AppColors.red);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnackBar(
        'Gagal masuk. Periksa kembali email, kata sandi, dan koneksi internet Anda.',
        bg: AppColors.red,
      );
    }
  }

  void _toRegister() {
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordPage(initialEmail: _email.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const OnboardingPage()),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.charcoal),
                        ),
                      ),
                      const FoodieHeaderLogo(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Center(child: Text('Masuk', style: AppText.display(26))),
                  const SizedBox(height: 24),
                  AppTextField(
                    label: 'Email',
                    hint: 'nama@gmail.com',
                    icon: Icons.mail_rounded,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Kata Sandi',
                    hint: 'Masukkan kata sandi',
                    icon: Icons.lock_rounded,
                    controller: _password,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) => Validators.required(v, 'Kata sandi'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: _remember,
                          activeColor: AppColors.greenDark,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (v) => setState(() => _remember = v ?? true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Ingat saya',
                        style: TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _openForgotPassword,
                        child: const Text(
                          'Lupa kata sandi?',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(label: 'Masuk', loading: _loading, onPressed: _submit),
                  const SizedBox(height: 22),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Belum punya akun? ',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                        GestureDetector(
                          onTap: _toRegister,
                          child: const Text('Daftar',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
