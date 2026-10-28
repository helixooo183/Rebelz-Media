import 'package:flutter/material.dart';

import '../../../core/services/firestore_errors.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../moderation/data/moderation_repository.dart';

/// Şikayet formu — profil veya tek bir mesaj için kullanılır.
///
/// Kullanıcı bir sebep seçer, isterse ayrıntı yazar. Kayıt
/// `reports` koleksiyonuna yazılır; gönderen kendi kaydını görebilir.
Future<bool> showReportSheet(
  BuildContext context, {
  required String targetUid,
  String targetName = '',
  String roomId = '',
  String messageId = '',
  String messageSnippet = '',
  bool isMessage = false,
  ModerationRepository? repository,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _ReportSheet(
        targetUid: targetUid,
        targetName: targetName,
        roomId: roomId,
        messageId: messageId,
        messageSnippet: messageSnippet,
        isMessage: isMessage,
        repository: repository,
      ),
    ),
  );
  return result ?? false;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.targetUid,
    required this.targetName,
    required this.roomId,
    required this.messageId,
    required this.messageSnippet,
    required this.isMessage,
    this.repository,
  });

  final String targetUid;
  final String targetName;
  final String roomId;
  final String messageId;
  final String messageSnippet;
  final bool isMessage;
  final ModerationRepository? repository;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  late final ModerationRepository _repo =
      widget.repository ?? moderationRepositoryInstance;

  final _detailsController = TextEditingController();
  String? _reason;
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) {
      setState(() => _error = 'Bir sebep seç.');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await _repo.sendReport(
        targetUid: widget.targetUid,
        targetName: widget.targetName,
        reason: reason,
        details: _detailsController.text,
        roomId: widget.roomId,
        messageId: widget.messageId,
        messageSnippet: widget.messageSnippet,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ModerationException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Şikayet gönderilemedi: ${friendlyFirestoreError(e)}');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kim = widget.targetName.trim().isEmpty
        ? 'bu kullanıcıyı'
        : widget.targetName.trim();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isMessage ? 'Mesajı şikayet et' : 'Profili şikayet et',
              style: context.texts.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              widget.isMessage
                  ? 'Bu mesajın neden kaldırılması gerektiğini seç. '
                      'Mesajın bir özeti kanıt olarak kaydedilir.'
                  : '$kim neden şikayet ediyorsun? Bildirimin '
                      'inceleme ekibine iletilir.',
              style: TextStyle(fontSize: 13, height: 1.4, color: context.muted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final reason in ReportReasons.all)
                  _ReasonChip(
                    label: reason,
                    selected: _reason == reason,
                    onTap: () => setState(() => _reason = reason),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 600,
              decoration: InputDecoration(
                labelText: 'Ayrıntı (isteğe bağlı)',
                hintText: 'Ne olduğunu kısaca anlatabilirsin.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: context.colors.error),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.flag_rounded, size: 18),
                label: Text(_isSending ? 'Gönderiliyor…' : 'Şikayeti gönder'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? context.colors.primaryContainer
              : context.cardHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? context.colors.primary : context.line,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? context.colors.primary : context.colors.onSurface,
          ),
        ),
      ),
    );
  }
}
