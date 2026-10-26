import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/google_sign_in_button.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/or_divider.dart';
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await authServiceInstance.signUp(
        displayName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Kayıt oluşturulamadı. Lütfen tekrar deneyin.');
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Hesap oluştur',
      subtitle: 'Birkaç saniyede kaydol ve sohbetlere katıl.',
      children: [
        GoogleSignInButton(
          onPressed: _googleSignIn,
          label: 'Google ile kayıt ol',
          isLoading: _isGoogleLoading,
        ),
        const SizedBox(height: 20),
        const OrDivider(),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField(
                controller: _nameController,
                hintText: 'Adın Soyadın',
                labelText: 'Görünen ad',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                enabled: !_isLoading && !_isGoogleLoading,
                validator: (value) {
                  if ((value ?? '').trim().length < 2) {
                    return 'En az 2 karakterlik bir ad girin.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _emailController,
                hintText: 'ornek@mail.com',
                labelText: 'E-posta',
                prefixIcon: Icons.alternate_email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                enabled: !_isLoading && !_isGoogleLoading,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'E-posta gerekli.';
                  if (!text.contains('@')) return 'Geçerli bir e-posta girin.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _passwordController,
                hintText: 'En az 6 karakter',
                labelText: 'Şifre',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                enabled: !_isLoading && !_isGoogleLoading,
                validator: (value) {
                  if ((value ?? '').length < 6) {
                    return 'Şifre en az 6 karakter olmalı.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: 'Kayıt ol',
                isLoading: _isLoading,
                onPressed: _isGoogleLoading ? null : _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Zaten hesabın var mı?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            TextButton(
              onPressed: (_isLoading || _isGoogleLoading)
                  ? null
                  : () => context.go(AppRoutes.login),
              child: const Text('Giriş yap'),
            ),
          ],
        ),
      ],
    );
  }
}
