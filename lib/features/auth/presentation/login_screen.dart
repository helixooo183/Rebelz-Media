import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/google_sign_in_button.dart';
import '../../../core/widgets/or_divider.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isSendingReset = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await authServiceInstance.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // Yönlendirmeyi GoRouter yapar.
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Giriş yapılamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      final credential = await authServiceInstance.signInWithGoogle();
      if (credential == null && mounted) return;
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Önce e-posta adresini yaz.');
      return;
    }

    setState(() => _isSendingReset = true);
    try {
      await authServiceInstance.sendPasswordResetEmail(email);
      if (!mounted) return;
      await _showResetSent(email);
    } on AuthException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _showResetSent(String email) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sıfırlama bağlantısı gönderildi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$email adresine şifre sıfırlama bağlantısı gönderdik.',
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              '• Spam / Gereksiz / Promosyonlar klasörüne bak\n'
              '• Adresi doğru yazdığından emin ol\n'
              '• Bağlantı 1 saat içinde kullanılmalı',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: dialogContext.muted,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'again'),
            child: const Text('Tekrar gönder'),
          ),
        ],
      ),
    );

    if (result == 'again' && mounted) {
      await _resetPassword();
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Tekrar hoş geldin',
      subtitle: 'Sohbetlerine, kanallarına ve çevrene kaldığın yerden devam et.',
      logoHeight: 92,
      footer: _Footer(
        busy: _isLoading || _isGoogleLoading,
        onRegister: () => context.go(AppRoutes.register),
      ),
      children: [
        GoogleSignInButton(
          onPressed: _googleSignIn,
          isLoading: _isGoogleLoading,
        ),
        const SizedBox(height: 16),
        const OrDivider(label: 'veya e-posta ile'),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField.dark(
                controller: _emailController,
                hintText: 'ornek@mail.com',
                labelText: 'E-posta',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'E-posta gerekli.';
                  if (!text.contains('@')) return 'Geçerli bir e-posta gir.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              AppTextField.dark(
                controller: _passwordController,
                hintText: '••••••••',
                labelText: 'Şifre',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                enabled: !_isLoading && !_isGoogleLoading,
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Şifre gerekli.';
                  if ((value ?? '').length < 6) {
                    return 'Şifre en az 6 karakter olmalı.';
                  }
                  return null;
                },
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: (_isLoading || _isGoogleLoading || _isSendingReset)
                      ? null
                      : _resetPassword,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    // Metin stili temadan türetilir (sabit TextStyle yazı
                    // tipini kaybettirip kutucuk çizilmesine yol açıyordu).
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  child: Text(
                    _isSendingReset ? 'Gönderiliyor…' : 'Şifremi unuttum',
                  ),
                ),
              ),
              const SizedBox(height: 4),
              PrimaryButton(
                label: 'Giriş yap',
                isLoading: _isLoading,
                onPressed: _isGoogleLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.busy, required this.onRegister});

  final bool busy;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Hesabın yok mu?',
          style: TextStyle(fontSize: 14.5, color: Color(0xFFD5D5DA)),
        ),
        TextButton(
          onPressed: busy ? null : onRegister,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.brand,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
          ),
          child: const Text('Kayıt ol'),
        ),
      ],
    );
  }
}
