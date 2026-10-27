import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/services.dart';
import '../theme/app_colors.dart';

/// E-posta doğrulanmadıysa gösterilen hatırlatma şeridi.
class VerifyEmailBanner extends StatefulWidget {
  const VerifyEmailBanner({
    super.key,
    this.onVerified,
    this.auth,
    this.showWhenVerified = false,
  });

  final VoidCallback? onVerified;
  final AuthService? auth;
  final bool showWhenVerified;

  @override
  State<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends State<VerifyEmailBanner> {
  AuthService? get _auth => widget.auth ?? authServiceOrNull;

  bool _isSending = false;
  bool _isChecking = false;
  bool _verified = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    final auth = _auth;
    _verified = auth?.emailVerified ?? false;
    _email = auth?.email;
  }

  bool get _isEmailPasswordAccount {
    final providers = _auth?.currentUser?.providerData
            .map((info) => info.providerId)
            .toSet() ??
        const <String>{};
    return providers.isEmpty || providers.contains('password');
  }

  Future<void> _resend() async {
    final auth = _auth;
    if (auth == null) return;

    setState(() => _isSending = true);
    try {
      await auth.sendEmailVerification();
      if (!mounted) return;
      _toast(
        'Doğrulama bağlantısı ${_email ?? 'e-posta adresine'} gönderildi. '
        'Spam/gereksiz klasörünü de kontrol et.',
      );
    } on AuthException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _check() async {
    final auth = _auth;
    if (auth == null) return;

    setState(() => _isChecking = true);
    final verified = await auth.refreshEmailVerified();
    if (!mounted) return;
    setState(() {
      _verified = verified;
      _isChecking = false;
    });

    if (verified) {
      widget.onVerified?.call();
      _toast('E-posta adresin doğrulandı. Teşekkürler!');
    } else {
      _toast('Henüz doğrulanmamış. Bağlantıya tıkladıktan sonra tekrar dene.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_auth == null) return const SizedBox.shrink();
    if (!_isEmailPasswordAccount) return const SizedBox.shrink();
    if (_verified && !widget.showWhenVerified) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _verified
                    ? Icons.verified_rounded
                    : Icons.mark_email_unread_outlined,
                size: 19,
                color: context.colors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _verified
                      ? 'E-posta adresin doğrulandı'
                      : 'E-posta adresin doğrulanmadı',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!_verified) ...[
            const SizedBox(height: 4),
            Text(
              '${_email ?? 'E-posta adresine'} gönderilen bağlantıya dokun. '
              'Gelmediyse tekrar gönderebilirsin.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: context.muted,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: _isSending ? null : _resend,
                  child: Text(_isSending ? 'Gönderiliyor…' : 'Tekrar gönder'),
                ),
                TextButton(
                  onPressed: _isChecking ? null : _check,
                  child: Text(_isChecking ? 'Kontrol…' : 'Doğruladım'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
