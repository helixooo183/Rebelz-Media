import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../data/moderation_repository.dart';

/// Destek ekranı: talep formu + kendi taleplerinin geçmişi.
///
/// Talepler `support_requests` koleksiyonuna yazılır; kullanıcı yalnızca
/// kendi taleplerini görebilir.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.repository});

  final ModerationRepository? repository;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final ModerationRepository _repo =
      widget.repository ?? moderationRepositoryInstance;

  final _messageController = TextEditingController();
  String _topic = SupportTopics.all.first;
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await _repo.sendSupportRequest(
        topic: _topic,
        message: _messageController.text,
      );
      if (!mounted) return;
      _messageController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Talebin alındı. En kısa sürede dönüş yapılacak.'),
        ),
      );
    } on ModerationException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Talep gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destek ve geri bildirim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          Text(
            'Bir sorun mu var? Aşağıdan bize yaz; talebin kayda geçer ve '
            'destek ekibi inceleyip dönüş yapar.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: context.muted),
          ),
          const SizedBox(height: 18),
          Text(
            'Konu',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in SupportTopics.all)
                ChoiceChip(
                  label: Text(topic),
                  selected: _topic == topic,
                  onSelected: (_) => setState(() => _topic = topic),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 6,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Mesajın',
              hintText: 'Sorunu, ne zaman olduğunu ve ne beklediğini yaz.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(fontSize: 13, color: context.colors.error),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.icon(
            onPressed: _isSending ? null : _send,
            icon: _isSending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_isSending ? 'Gönderiliyor…' : 'Talebi gönder'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Taleplerim',
            style: context.texts.titleLarge,
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<SupportTicket>>(
            stream: _repo.watchMySupportTickets(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Talepler yüklenemedi: ${snapshot.error}',
                  style: TextStyle(fontSize: 12.5, color: context.muted),
                );
              }
              final tickets = snapshot.data ?? const <SupportTicket>[];
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (tickets.isEmpty) {
                return Text(
                  'Henüz bir destek talebin yok.',
                  style: TextStyle(fontSize: 12.5, color: context.muted),
                );
              }
              return Column(
                children: [
                  for (final ticket in tickets) _TicketCard(ticket: ticket),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final date = ticket.createdAt?.toLocal();
    final when = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.durumEtiketi,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.colors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            ticket.message,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, height: 1.4, color: context.muted),
          ),
          if (ticket.adminReply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                  Row(
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: 13,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Destek ekibi yanıtladı',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: context.colors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.adminReply,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          if (when.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              when,
              style: TextStyle(fontSize: 11, color: context.muted),
            ),
          ],
        ],
      ),
    );
  }
}
