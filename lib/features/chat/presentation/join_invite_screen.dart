import 'package:flutter/material.dart';

import '../../../core/services/firestore_errors.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/chat_repository.dart';
import '../domain/models/room_invite.dart';

/// Davet bağlantısıyla gelen kişiyi karşılayan ekran.
///
/// `rebelzmedia://katil/<kod>` bağlantısına dokunulduğunda (ya da uygulama
/// içinden kod girildiğinde) açılır: kodu gösterir, "Katıl"a basınca odaya
/// üye olur ve sohbeti açar.
class JoinInviteScreen extends StatefulWidget {
  const JoinInviteScreen({
    super.key,
    required this.code,
    this.repository,
    this.autoJoin = false,
    this.onJoined,
  });

  /// Davet kodu (`ABCD2345`) — bağlantıdan normalize edilerek gelir.
  final String code;

  final ChatRepository? repository;

  /// true ise ekran açılır açılmaz katılmayı dener (bağlantıdan gelindiğinde).
  final bool autoJoin;

  /// Katılım başarılı olduğunda çağrılır (router sohbeti açar).
  /// Verilmezse ekran kapanır.
  final void Function(String roomId)? onJoined;

  @override
  State<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends State<JoinInviteScreen> {
  late final ChatRepository _repository =
      widget.repository ?? chatRepositoryInstance;

  late final String _code = normalizeInviteCode(widget.code);

  bool _isJoining = false;
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoJoin) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _join());
    }
  }

  Future<void> _join() async {
    if (_isJoining || _done) return;
    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final roomId = await _repository.joinByInviteCode(_code);
      if (!mounted) return;
      setState(() => _done = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet kabul edildi, katıldın.')),
      );

      final navigate = widget.onJoined;
      if (navigate != null) {
        navigate(roomId);
      } else {
        Navigator.of(context).maybePop();
      }
    } on ChatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Katılınamadı: ${friendlyFirestoreError(e)}');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _code.length >= 6;

    return Scaffold(
      appBar: AppBar(title: const Text('Davet')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Icon(
              Icons.mark_email_read_rounded,
              size: 62,
              color: context.colors.primary,
            ),
            const SizedBox(height: 18),
            Text(
              'Sana bir davet geldi',
              textAlign: TextAlign.center,
              style: context.texts.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              valid
                  ? 'Davet kodu: $_code\nKatılınca kanal/grup sohbetlerinde '
                      'görünecek.'
                  : 'Bu davet bağlantısı geçersiz görünüyor.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: context.muted),
            ),
            const SizedBox(height: 22),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: context.colors.error),
                ),
              ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: _isJoining ? 'Katılınıyor…' : 'Katıl',
              icon: Icons.login_rounded,
              isLoading: _isJoining,
              onPressed: valid && !_isJoining ? _join : null,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Şimdi değil'),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
