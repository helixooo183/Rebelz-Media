import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../profile/data/user_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_room.dart';

/// Kanal ve grup ayarları.
///
/// * Kanal: ad/açıklama, moderatör ekleme-kaldırma, moderatör izinleri,
///   kanal izinleri, sahipliği devretme, ayrılma.
/// * Grup: aynı ekran (ad/açıklama, moderatör, üye çıkarma, devretme, ayrılma).
class RoomSettingsScreen extends StatefulWidget {
  const RoomSettingsScreen({
    super.key,
    required this.roomId,
    this.repository,
    this.userRepository,
    this.currentUserId,
  });

  final String roomId;
  final ChatRepository? repository;
  final UserRepository? userRepository;
  final String? currentUserId;

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen> {
  late final ChatRepository _repo =
      widget.repository ?? chatRepositoryInstance;

  late final String? _myUid = widget.currentUserId ?? currentUserIdOrNull;

  late final Stream<ChatRoom?> _roomStream = _repo.watchRoom(widget.roomId);

  UserRepository? _users;

  UserRepository? get _userRepo {
    if (widget.userRepository != null) return widget.userRepository;
    if (_users != null) return _users;
    try {
      return _users = userRepositoryInstance;
    } catch (_) {
      return null;
    }
  }

  bool _isBusy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _isBusy = true);
    try {
      await action();
      _toast(success);
    } catch (e) {
      _toast('İşlem tamamlanamadı: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ------------------------------------------------------------------ düzenleme

  Future<void> _editInfo(ChatRoom room) async {
    final nameController = TextEditingController(text: room.name);
    final aboutController = TextEditingController(text: room.about);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adı ve açıklama'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: aboutController,
              maxLines: 3,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                alignLabelWithHint: true,
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
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    final name = nameController.text;
    final about = aboutController.text;
    nameController.dispose();
    aboutController.dispose();

    if (saved != true) return;
    await _run(
      () => _repo.updateRoomInfo(widget.roomId, name: name, about: about),
      'Bilgiler güncellendi.',
    );
  }

  Future<void> _togglePermission(
    String key,
    bool value,
  ) async {
    await _run(
      () => _repo.setPermission(widget.roomId, key, value: value),
      'İzin güncellendi.',
    );
  }

  Future<void> _setModerator(String uid, bool moderator) async {
    await _run(
      () => _repo.setModerator(widget.roomId, uid, moderator: moderator),
      moderator ? 'Moderatör olarak eklendi.' : 'Moderatörlük kaldırıldı.',
    );
  }

  Future<void> _removeMember(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Üye çıkarılsın mı?'),
        content: Text('$name bu sohbetten çıkarılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _repo.removeMember(widget.roomId, uid),
      '$name çıkarıldı.',
    );
  }

  Future<void> _transferOwnership(String uid, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sahiplik devredilsin mi?'),
        content: Text(
          '$name yeni sahip olacak. Sen moderatör olarak kalacaksın. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Devret'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => _repo.transferOwnership(widget.roomId, uid),
      'Sahiplik $name kişisine devredildi.',
    );
  }

  /// Kullanıcı adıyla arayıp moderatör ekler (gerekiyorsa üyeliği de açar).
  Future<void> _addModerator(ChatRoom room) async {
    final users = _userRepo;
    if (users == null) {
      _toast('Kullanıcı araması şu an kullanılamıyor.');
      return;
    }

    final picked = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UserSearchSheet(users: users),
    );
    if (picked == null) return;

    await _run(() async {
      if (!room.memberIds.contains(picked.uid)) {
        final info = await _repo.fetchMemberInfo(picked.uid);
        await _repo.addMember(
          widget.roomId,
          uid: picked.uid,
          name: info['name'] ?? picked.displayName,
          photoUrl: info['photoUrl'] ?? '',
        );
      }
      await _repo.setModerator(widget.roomId, picked.uid, moderator: true);
    }, '${picked.displayName} moderatör olarak eklendi.');
  }

  Future<void> _leave(ChatRoom room) async {
    final isOwner = room.sahipMi(_myUid);
    final others = room.memberIds.where((id) => id != _myUid).toList();

    if (isOwner && others.isNotEmpty) {
      _toast('Ayrılmadan önce sahipliği başka birine devret.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(room.isChannel ? 'Kanaldan ayrıl?' : 'Gruptan ayrıl?'),
        content: const Text(
          'Sohbet listeden kalkar. Yeniden katılmak için kanalı '
          'tekrar açabilirsin.',
        ),
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
    if (confirmed != true) return;

    await _run(() => _repo.leaveRoom(widget.roomId), 'Ayrıldın.');
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatRoom?>(
      stream: _roomStream,
      builder: (context, snapshot) {
        final room = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(room?.isChannel == true ? 'Kanal ayarları' : 'Grup ayarları'),
          ),
          body: room == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  children: [
                    _RoomHeader(
                      room: room,
                      onEdit: _isBusy || !room.yonetebilirMi(_myUid)
                          ? null
                          : () => _editInfo(room),
                    ),
                    const SizedBox(height: 20),
                    if (room.yonetebilirMi(_myUid))
                      _Section(
                        title: 'İzinler',
                        children: [
                          if (room.isChannel)
                            SwitchListTile(
                              value: room.yalnizModeratorlerPaylasir,
                              onChanged: _isBusy
                                  ? null
                                  : (value) => _togglePermission(
                                        ChatRoom.permOnlyModsPost,
                                        value,
                                      ),
                              title: const Text(
                                'Yalnızca moderatörler paylaşsın',
                              ),
                              subtitle: Text(
                                'Kapalıysa tüm aboneler gönderi paylaşabilir.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.muted,
                                ),
                              ),
                            ),
                          SwitchListTile(
                            value: room.yalnizModeratorlerUyeEkler,
                            onChanged: _isBusy
                                ? null
                                : (value) => _togglePermission(
                                      ChatRoom.permOnlyModsAddMembers,
                                      value,
                                    ),
                            title: const Text('Yalnızca moderatörler üye eklesin'),
                            subtitle: Text(
                              'Kapalıysa her üye yeni kişi ekleyebilir.',
                              style: TextStyle(fontSize: 11.5, color: context.muted),
                            ),
                          ),
                          SwitchListTile(
                            value: room.moderatorlerMesajSilebilir,
                            onChanged: _isBusy
                                ? null
                                : (value) => _togglePermission(
                                      ChatRoom.permModsDeleteMessages,
                                      value,
                                    ),
                            title: const Text('Moderatörler mesaj silebilsin'),
                            subtitle: Text(
                              'Kapalıysa yalnızca mesaj sahibi silebilir.',
                              style: TextStyle(fontSize: 11.5, color: context.muted),
                            ),
                          ),
                        ],
                      ),
                    if (room.yonetebilirMi(_myUid)) const SizedBox(height: 18),
                    if (room.yonetebilirMi(_myUid))
                      _Section(
                        title: 'Moderatörler',
                        children: [
                          for (final uid in room.memberIds
                              .where((id) => room.moderatorMu(id)))
                            _MemberRow(
                              room: room,
                              uid: uid,
                              roleLabel: 'Moderatör',
                              myUid: _myUid,
                              onTap: () => _memberActions(room, uid),
                            ),
                          ListTile(
                            leading: Icon(
                              Icons.add_moderator_outlined,
                              size: 20,
                              color: context.colors.primary,
                            ),
                            title: Text(
                              'Moderatör ekle',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: context.colors.primary,
                              ),
                            ),
                            subtitle: Text(
                              'Kullanıcı adıyla ara ve yetki ver.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.muted,
                              ),
                            ),
                            onTap: _isBusy ? null : () => _addModerator(room),
                          ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    _Section(
                      title: 'Üyeler (${room.memberIds.length})',
                      children: [
                        for (final uid in room.memberIds)
                          _MemberRow(
                            room: room,
                            uid: uid,
                            roleLabel: room.rolOf(uid) == ChatRoom.roleOwner
                                ? 'Sahip'
                                : room.rolOf(uid) == ChatRoom.roleModerator
                                    ? 'Moderatör'
                                    : 'Üye',
                            myUid: _myUid,
                            onTap: () => _memberActions(room, uid),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : () => _leave(room),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: Text(
                        room.isChannel ? 'Kanaldan ayrıl' : 'Gruptan ayrıl',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: context.colors.error,
                        side: BorderSide(
                          color: context.colors.error.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Rol: ${_roleText(room)}',
                        style: TextStyle(fontSize: 11.5, color: context.muted),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  String _roleText(ChatRoom room) {
    final role = room.rolOf(_myUid);
    return switch (role) {
      ChatRoom.roleOwner => 'Sahip',
      ChatRoom.roleModerator => 'Moderatör',
      _ => 'Üye',
    };
  }

  /// Üye satırına dokununca açılan işlemler.
  Future<void> _memberActions(ChatRoom room, String uid) async {
    if (uid == _myUid) {
      _toast('Kendi rollerini buradan değiştiremezsin.');
      return;
    }

    final name = (room.memberNames[uid]?.trim().isNotEmpty ?? false)
        ? room.memberNames[uid]!.trim()
        : 'Kullanıcı';

    final isMod = room.moderatorMu(uid);
    final isOwner = room.sahipMi(_myUid);
    final canManage = room.yonetebilirMi(_myUid);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Şikayet et'),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
            if (canManage)
              ListTile(
                leading: Icon(
                  isMod
                      ? Icons.remove_moderator_outlined
                      : Icons.add_moderator_outlined,
                ),
                title: Text(
                  isMod ? 'Moderatörlükten al' : 'Moderatör yap',
                ),
                onTap: () => Navigator.pop(sheetContext, 'mod'),
              ),
            if (isOwner)
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Sahipliği devret'),
                onTap: () => Navigator.pop(sheetContext, 'transfer'),
              ),
            if (canManage)
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: sheetContext.colors.error,
                ),
                title: Text(
                  'Üyeyi çıkar',
                  style: TextStyle(color: sheetContext.colors.error),
                ),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    switch (action) {
      case 'report':
        final sent = await showReportSheet(
          context,
          targetUid: uid,
          targetName: name,
          roomId: widget.roomId,
        );
        if (sent) _toast('Şikayetin iletildi.');
      case 'mod':
        await _setModerator(uid, !isMod);
      case 'transfer':
        await _transferOwnership(uid, name);
      case 'remove':
        await _removeMember(uid, name);
    }
  }
}

class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room, required this.onEdit});

  final ChatRoom room;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          name: room.name,
          size: 62,
          photoUrl: room.photoUrl,
          isGroup: room.isGroup,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                room.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.texts.headlineSmall,
              ),
              const SizedBox(height: 3),
              Text(
                room.about.isEmpty
                    ? (room.isChannel
                        ? '${room.subscriberCount} abone'
                        : '${room.memberIds.length} üye')
                    : room.about,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: context.muted),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            tooltip: 'Adı ve açıklamayı düzenle',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.room,
    required this.uid,
    required this.roleLabel,
    required this.myUid,
    required this.onTap,
  });

  final ChatRoom room;
  final String uid;
  final String roleLabel;
  final String? myUid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (room.memberNames[uid]?.trim().isNotEmpty ?? false)
        ? room.memberNames[uid]!.trim()
        : 'Kullanıcı';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: UserAvatar(
        name: name,
        size: 38,
        photoUrl: room.memberPhotos[uid],
      ),
      title: Text(
        uid == myUid ? '$name (sen)' : name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        roleLabel,
        style: TextStyle(
          fontSize: 11.5,
          color: roleLabel == 'Üye' ? context.muted : context.colors.primary,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
      onTap: onTap,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: context.muted,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(height: 1, indent: 56, color: context.line),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Kullanıcı adı/görünen adla arayıp seçim yaptıran alt sayfa.
class _UserSearchSheet extends StatefulWidget {
  const _UserSearchSheet({required this.users});

  final UserRepository users;

  @override
  State<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<_UserSearchSheet> {
  final _controller = TextEditingController();
  List<UserProfile> _results = const <UserProfile>[];
  bool _isSearching = false;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final query = raw.trim();
    if (query.length < 2) {
      setState(() {
        _results = const <UserProfile>[];
        _searched = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final found = await widget.users.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = found;
        _searched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const <UserProfile>[];
        _searched = true;
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Kullanıcı adı ara',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _searched
                            ? 'Eşleşen kullanıcı yok.'
                            : 'En az 2 karakter yaz.',
                        style: TextStyle(fontSize: 13, color: context.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, indent: 62, color: context.line),
                      itemBuilder: (context, index) {
                        final profile = _results[index];
                        return ListTile(
                          leading: UserAvatar(
                            name: profile.displayName,
                            size: 40,
                            photoUrl: profile.photoUrl,
                            emoji: profile.avatarEmoji,
                            colorIndex: profile.avatarColor,
                          ),
                          title: Text(
                            profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            profile.username.isEmpty
                                ? 'kullanıcı adı yok'
                                : '@${profile.username}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.muted,
                            ),
                          ),
                          onTap: () => Navigator.of(context).pop(profile),
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
