import 'package:flutter/material.dart';

import '../../../core/services/firestore_errors.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/moderation_repository.dart';

/// Destek talepleri paneli (yalnızca yöneticiler).
///
/// Kullanıcıların açtığı `support_requests` kayıtlarını listeler; yönetici
/// yanıt yazınca talep **Yanıtlandı** olur ve kullanıcı kendi destek
/// ekranında yanıtı görür.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key, this.repository});

  final ModerationRepository? repository;

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  late final ModerationRepository _repo =
      widget.repository ?? moderationRepositoryInstance;

  /// 'open' | 'answered' | 'all'
  String _filter = 'open';

  String? _busyId;

  Future<void> _reply(SupportTicket ticket) async {
    final controller = TextEditingController(text: ticket.adminReply);

    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Talebi yanıtla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${ticket.name.isEmpty ? 'Kullanıcı' : ticket.name} · '
              '${ticket.topic}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 5,
              maxLength: 2000,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Yanıt',
                alignLabelWithHint: true,
                hintText: 'Sorunu çözen/yanıtlayan kısa bir mesaj yaz…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (sent != true || !mounted) return;

    setState(() => _busyId = ticket.id);
    try {
      await _repo.replyToSupportTicket(ticket.id, controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yanıt gönderildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyFirestoreError(e))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Destek talepleri'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                borderRadius: BorderRadius.circular(14),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Bekleyen')),
                  DropdownMenuItem(value: 'answered', child: Text('Yanıtlanan')),
                  DropdownMenuItem(value: 'all', child: Text('Tümü')),
                ],
                onChanged: (value) => setState(() => _filter = value ?? 'open'),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<SupportTicket>>(
        stream: _repo.watchAllSupportTickets(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Talepler yüklenemedi',
              message: friendlyFirestoreError(snapshot.error!),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final items = all.where((ticket) {
            if (_filter == 'open') return !ticket.yanitlandi;
            if (_filter == 'answered') return ticket.yanitlandi;
            return true;
          }).toList();

          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.support_agent_rounded,
              title: _filter == 'open' ? 'Bekleyen talep yok' : 'Kayıt yok',
              message: _filter == 'open'
                  ? 'Destek ekranından gelen yeni talepler burada listelenir.'
                  : 'Bu filtreye uyan talep yok.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Text(
                  '${items.length} talep · '
                  '${all.where((t) => !t.yanitlandi).length} bekliyor',
                  style: TextStyle(fontSize: 12, color: context.muted),
                );
              }
              final ticket = items[index - 1];
              return _TicketCard(
                ticket: ticket,
                busy: _busyId == ticket.id,
                onReply: () => _reply(ticket),
              );
            },
          );
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.ticket,
    required this.busy,
    required this.onReply,
  });

  final SupportTicket ticket;
  final bool busy;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final date = ticket.createdAt?.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final when = date == null
        ? ''
        : '${two(date.day)}.${two(date.month)}.${date.year} '
            '${two(date.hour)}:${two(date.minute)}';

    final renk = ticket.yanitlandi ? context.muted : context.colors.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.topic,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.durumEtiketi,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: renk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket.message,
            style: TextStyle(fontSize: 13, height: 1.4, color: context.muted),
          ),
          if (ticket.adminReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.cardHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: context.colors.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yanıtın',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: context.colors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.adminReply,
                    style: const TextStyle(fontSize: 12.5, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${ticket.name.isEmpty ? ticket.uid : ticket.name}'
            '${ticket.email.isEmpty ? '' : ' · ${ticket.email}'}'
            '${when.isEmpty ? '' : ' · $when'}',
            style: TextStyle(fontSize: 11, color: context.muted),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: busy ? null : onReply,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.reply_rounded, size: 16),
              label: Text(ticket.yanitlandi ? 'Yanıtı düzenle' : 'Yanıtla'),
            ),
          ),
        ],
      ),
    );
  }
}
