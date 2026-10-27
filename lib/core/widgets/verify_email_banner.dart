import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/services.dart';
import '../theme/app_colors.dart';

/// E-posta doğrulanmadıysa gösterilen hatırlatma şeridi.
///
/// "Tekrar gönder" ve "Doğruladım" aksiyonları vardır; ikincisi Firebase'deki
/// kullanıcıyı yeniler (bağlantıya tıklandıktan sonra gerekir). Hesap Google
/// ile açıldıysa ya da Firebase yoksa hiçbir şey çizmez.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Doğrulama bağlantısı ${_email ?? 'e-posta adresine'} gönderildi. '
            'Gelen kutunda yoksa spam/gereksiz klasörüne bak.',
          ),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-posta adresin doğrulandı. Teşekkürler!'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Henüz doğrulanmamış. Bağlantıya tıkladıktan sonra tekrar dene.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_auth == null) return const SizedBox.shrink();
    if (!_isEmailPasswordAccount) return const SizedBox.shrink();
    if (_verified && !widget.showWhenVerified) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _verified
                    ? Icons.verified_outlined
                    : Icons.mark_email_unread_outlined,
                size: 20,
                color: _verified ? AppColors.success : AppColors.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _verified
                      ? 'E-posta adresin doğrulandı.'
                      : 'E-posta adresin henüz doğrulanmadı.',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (!_verified) ...[
            const SizedBox(height: 6),
            Text(
              'Doğrulama bağlantısı ${_email ?? 'e-posta adresine'} gönderildi. '
              'Gelmediyse tekrar gönderebilirsin; spam/gereksiz klasörünü de '
              'kontrol et.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
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
