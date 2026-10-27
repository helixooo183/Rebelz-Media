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
import '../../profile/presentation/terms_sheet.dart';
import 'auth_scaffold.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;

  /// Koşulların açıkça kabul edildiğini gösterir (kanıt kaydı için şart).
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _recordTerms() async {
    try {
      await userRepositoryInstance.acceptTerms();
    } catch (_) {
      // Onay, ana ekrandaki hatırlatmayla tamamlanır.
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      _showError('Devam etmek için kullanım koşullarını kabul etmelisin.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await authServiceInstance.signUp(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      await _recordTerms();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Kayıt oluşturulamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    if (!_acceptedTerms) {
      _showError('Devam etmek için kullanım koşullarını kabul etmelisin.');
      return;
    }

    setState(() => _isGoogleLoading = true);
    try {
      final credential = await authServiceInstance.signInWithGoogle();
      if (credential == null && mounted) return;
      await _recordTerms();
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
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
    final isBusy = _isLoading || _isGoogleLoading;

    return AuthScaffold(
      title: 'Hesap oluştur',
      subtitle: 'Saniyeler içinde katıl; kullanıcı adını seç, çevreni kur.',
      logoHeight: 84,
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Zaten hesabın var mı?',
            style: TextStyle(fontSize: 14.5, color: Color(0xFFD5D5DA)),
          ),
          TextButton(
            onPressed: isBusy ? null : () => context.go(AppRoutes.login),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brand,
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Giriş yap'),
          ),
        ],
      ),
      children: [
        GoogleSignInButton(
          onPressed: _acceptedTerms ? _googleSignIn : null,
          label: 'Google ile kayıt ol',
          isLoading: _isGoogleLoading,
        ),
        const SizedBox(height: 18),
        const OrDivider(label: 'veya e-posta ile'),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField.dark(
                controller: _nameController,
                hintText: 'Adın Soyadın',
                labelText: 'Görünen ad',
                prefixIcon: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                enabled: !isBusy,
                validator: (value) {
                  if ((value ?? '').trim().length < 2) {
                    return 'En az 2 karakterlik bir ad gir.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField.dark(
                controller: _emailController,
                hintText: 'ornek@mail.com',
                labelText: 'E-posta',
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !isBusy,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'E-posta gerekli.';
                  if (!text.contains('@')) return 'Geçerli bir e-posta gir.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField.dark(
                controller: _passwordController,
                hintText: 'En az 6 karakter',
                labelText: 'Şifre',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                enabled: !isBusy,
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Şifre en az 6 karakter olmalı.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              TermsCheckbox(
                value: _acceptedTerms,
                enabled: !isBusy,
                onChanged: (value) => setState(() => _acceptedTerms = value),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kayıttan sonra doğrulama bağlantısı e-postana gönderilir. '
                'Gelmezse spam/gereksiz klasörünü kontrol et.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: Color(0xFF8E8E97),
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                label: 'Kayıt ol',
                isLoading: _isLoading,
                onPressed: isBusy || !_acceptedTerms ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
