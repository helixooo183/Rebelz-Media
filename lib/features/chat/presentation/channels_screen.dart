import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/firestore_errors.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_room.dart';

/// Yayın kanalları: keşfet, katıl ve kendi kanalını aç.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key, this.repository, this.myUid});

  final ChatRepository? repository;
  final String? myUid;

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  late final ChatRepository _repository =
      widget.repository ?? chatRepositoryInstance;

  late final String? _myUid = widget.myUid ?? currentUserIdOrNull;

  late final Stream<List<ChatRoom>> _channels = _repository.watchChannels();

  bool _isBusy = false;

  /// Kanal arama: ad ve açıklamada geçen metin.
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final value = _searchController.text.trim().toLowerCase();
      if (value == _query) return;
      setState(() => _query = value);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Davet kodu/bağlantısı ile kanal veya gruba katılır.
  Future<void> _joinWithCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Davet ile katıl'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sana gelen davet bağlantısını ya da 8 karakterlik kodu yaz.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Örn. K7M2P9QD veya rebelzmedia://katil/…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Katıl'),
          ),
        ],
      ),
    );

    final raw = code ?? '';
    controller.dispose();
    if (raw.trim().isEmpty || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final roomId = await _repository.joinByInviteCode(raw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Davet kabul edildi, katıldın.')),
      );
      await context.push(AppRoutes.chat(roomId, name: 'Sohbet'));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyFirestoreError(e))),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openChannel(ChatRoom channel) async {
    if (!channel.hasMember(_myUid)) {
      try {
        await _repository.joinChannel(channel.id);
      } catch (_) {
        // Katılma başarısız olsa da okuma denenebilir.
      }
    }
    if (!mounted) return;
    await context.push(AppRoutes.chat(channel.id, name: channel.name));
  }

  Future<void> _leaveChannel(ChatRoom channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${channel.name} kanalından ayrıl'),
        content: const Text('Kanal listeden kalkar, istediğin zaman '
            'yeniden katılabilirsin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repository.leaveChannel(channel.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${channel.name} kanalından ayrıldın.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ayrılınamadı: ${friendlyFirestoreError(e)}')),
      );
    }
  }

  Future<void> _createChannel() async {
    final nameController = TextEditingController();
    final aboutController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isPrivate = false;

    final created = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kanal aç', style: sheetContext.texts.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Kanalda yalnızca sen paylaşım yaparsın; abonelerin '
                    'gönderileri okur.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: sheetContext.muted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Kanal adı'),
                    validator: (value) =>
                        (value ?? '').trim().length < 3
                            ? 'En az 3 karakter gir.'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: aboutController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Ne paylaşacaksın? (isteğe bağlı)',
                    ),
                  ),
                  const SizedBox(height: 6),
                  StatefulBuilder(
                    builder: (context, setSheetState) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: isPrivate,
                      onChanged: (value) =>
                          setSheetState(() => isPrivate = value),
                      title: const Text('Özel kanal'),
                      subtitle: Text(
                        isPrivate
                            ? 'Keşfette görünmez, yalnızca davetle katılınır.'
                            : 'Herkese açık: kanallar listesinde görünür.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: sheetContext.muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Kanalı oluştur',
                    onPressed: () {
                      if (formKey.currentState?.validate() != true) return;
                      Navigator.pop(
                        sheetContext,
                        '${nameController.text}|||${aboutController.text}'
                            '|||${isPrivate ? '1' : '0'}',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (created == null || !mounted) return;

    final parts = created.split('|||');
    final channelName = parts.first;
    final channelAbout = parts.length > 1 ? parts[1] : '';
    final channelPrivate = parts.length > 2 && parts[2] == '1';

    setState(() => _isBusy = true);
    try {
      final id = await _repository.createChannel(
        name: channelName,
        about: channelAbout,
        isPrivate: channelPrivate,
      );
      if (!mounted) return;
      await context.push(AppRoutes.chat(id, name: channelName.trim()));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kanal açılamadı: ${friendlyFirestoreError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Kanallar', style: context.texts.displaySmall),
                  ),
                  IconButton(
                    tooltip: 'Davet kodu ile katıl',
                    onPressed: _isBusy ? null : _joinWithCode,
                    icon: const Icon(Icons.qr_code_rounded, size: 22),
                  ),
                  IconButton(
                    tooltip: 'Kanal aç',
                    onPressed: _isBusy ? null : _createChannel,
                    icon: const Icon(Icons.add_rounded, size: 26),
                  ),
                ],
              ),
            ),
            // ---- arama çubuğu ------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Kanal ara',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: context.card,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Temizle',
                          onPressed: () => _searchController.clear(),
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.line),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatRoom>>(
                stream: _channels,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Kanallar yüklenemedi',
                      message: friendlyFirestoreError(snapshot.error!),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Özel kanallar keşfette görünmez; yalnızca üyesi
                  // olduklarım listelenir.
                  final visible = snapshot.data!
                      .where((c) =>
                          !c.isPrivate || c.hasMember(_myUid))
                      .toList();

                  final channels = _query.isEmpty
                      ? visible
                      : visible
                          .where((c) =>
                              c.name.toLowerCase().contains(_query) ||
                              c.about.toLowerCase().contains(_query))
                          .toList();

                  if (visible.isEmpty) {
                    return EmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'Henüz kanal yok',
                      message: 'İlk kanalı sen aç: duyurularını tek yerden '
                          'paylaş, abonelerin anında görsün.',
                      actionLabel: 'Kanal aç',
                      onAction: _createChannel,
                    );
                  }

                  if (channels.isEmpty) {
                    return EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sonuç yok',
                      message: '"$_query" ile eşleşen kanal bulunamadı. '
                          'Davet bağlantın varsa kod ile katılabilirsin.',
                      actionLabel: 'Kod ile katıl',
                      onAction: _joinWithCode,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                    itemCount: channels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      final isMine = channel.sahipMi(_myUid);
                      final isMember = channel.hasMember(_myUid);

                      return AppCard(
                        radius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        onTap: () => _openChannel(channel),
                        trailing: isMine
                            ? null
                            : isMember
                                ? TextButton(
                                    onPressed: () => _leaveChannel(channel),
                                    child: const Text('Ayrıl'),
                                  )
                                : FilledButton(
                                    onPressed: () => _openChannel(channel),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 34),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                    ),
                                    child: const Text('Katıl'),
                                  ),
                        child: Row(
                          children: [
                            UserAvatar(
                              name: channel.name,
                              size: 48,
                              photoUrl: channel.photoUrl,
                              isGroup: true,
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          channel.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      if (channel.isPrivate) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.lock_rounded,
                                          size: 13,
                                          color: context.muted,
                                        ),
                                      ],
                                      if (isMine) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.verified_rounded,
                                          size: 15,
                                          color: context.colors.primary,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    channel.about.isNotEmpty
                                        ? channel.about
                                        : '${channel.subscriberCount} abone',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: context.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
