import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/moderation_repository.dart';

/// Şikayet inceleme paneli (yalnızca yöneticiler).
///
/// Yönetici = `admins/{uid}` dokümanı olan kullanıcı. Firestore kuralları da
/// şikayetleri yalnızca yöneticiye okutur; bu ekranın menüde görünmesi için
/// `admins` koleksiyonuna kayıt gerekir.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.repository});

  final ModerationRepository? repository;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ModerationRepository _repo =
      widget.repository ?? moderationRepositoryInstance;

  /// 'open' | 'all' | 'closed'
  String _filter = 'open';

  bool _isBusy = false;

  Future<void> _setStatus(ReportItem report, String status) async {
    setState(() => _isBusy = true);
    try {
      await _repo.updateReportStatus(report.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Şikayet: ${ReportStatus.label(status)}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şikayetler'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                borderRadius: BorderRadius.circular(14),
                items: const [
                  DropdownMenuItem(value: 'open', child: Text('Açık')),
                  DropdownMenuItem(value: 'closed', child: Text('Kapanan')),
                  DropdownMenuItem(value: 'all', child: Text('Tümü')),
                ],
                onChanged: (value) =>
                    setState(() => _filter = value ?? 'open'),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ReportItem>>(
        stream: _repo.watchReports(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Şikayetler yüklenemedi',
              message: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final items = all.where((report) {
            if (_filter == 'open') return report.isAcik;
            if (_filter == 'closed') return !report.isAcik;
            return true;
          }).toList();

          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_rounded,
              title: _filter == 'open' ? 'Açık şikayet yok' : 'Kayıt yok',
              message: _filter == 'open'
                  ? 'Bekleyen şikayet bulunmuyor. Yeni bildirimler '
                      'burada listelenir.'
                  : 'Bu filtreye uyan şikayet yok.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${items.length} kayıt · '
                    '${all.where((r) => r.isAcik).length} açık şikayet',
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                );
              }
              final report = items[index - 1];
              return _ReportCard(
                report: report,
                busy: _isBusy,
                onResolve: () =>
                    _setStatus(report, ReportStatus.resolved),
                onDismiss: () =>
                    _setStatus(report, ReportStatus.dismissed),
                onReopen: () => _setStatus(report, ReportStatus.open),
              );
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onResolve,
    required this.onDismiss,
    required this.onReopen,
  });

  final ReportItem report;
  final bool busy;
  final VoidCallback onResolve;
  final VoidCallback onDismiss;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final date = report.createdAt?.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final when = date == null
        ? ''
        : '${two(date.day)}.${two(date.month)}.${date.year} '
            '${two(date.hour)}:${two(date.minute)}';

    final durumRengi = report.isAcik
        ? context.colors.primary
        : context.muted;

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
              UserAvatar(
                name: report.targetName.isEmpty
                    ? 'Kullanıcı'
                    : report.targetName,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.targetName.isEmpty
                          ? report.targetUid
                          : report.targetName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      report.isMesaj ? 'Mesaj şikayeti' : 'Profil şikayeti',
                      style: TextStyle(fontSize: 11.5, color: context.muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: durumRengi.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.durumEtiketi,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: durumRengi,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.reason,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFF5A5A),
            ),
          ),
          if (report.details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              report.details,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: context.muted),
            ),
          ],
          if (report.messageSnippet.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.cardHigh,
                borderRadius: BorderRadius.circular(10),
                border: Border(
                  left: BorderSide(color: context.colors.primary, width: 3),
                ),
              ),
              child: Text(
                '“${report.messageSnippet}”',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.35, color: context.muted),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${report.reporterName.isEmpty ? report.reporterUid : report.reporterName}'
            '${when.isEmpty ? '' : ' · $when'}',
            style: TextStyle(fontSize: 11, color: context.muted),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (report.isAcik) ...[
                TextButton(
                  onPressed: busy ? null : onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: context.muted,
                  ),
                  child: const Text('Reddet'),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: busy ? null : onResolve,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Çözüldü'),
                ),
              ] else
                TextButton(
                  onPressed: busy ? null : onReopen,
                  child: const Text('Yeniden aç'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
