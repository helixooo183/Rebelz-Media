import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/user_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/chat_repository.dart';

/// Kullanıcı adı ve görünen adla başlayan sohbet için kullanıcı seçimi.
///
/// "[Yeni sohbet]" butonundan açılır: kullanıcı adı yazıldıkça eşleşen
/// profiller (fotoğraf + ad + @kullanıcıadı) listelenir.
Future<String?> showNewChatSheet(
  BuildContext context, {
  UserRepository? userRepository,
  ChatRepository? chatRepository,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NewChatSheet(
      userRepository: userRepository,
      chatRepository: chatRepository,
    ),
  );
}

class NewChatSheet extends StatefulWidget {
  const NewChatSheet({super.key, this.repository, this.userRepository, this.chatRepository});

  /// Eski çağrılarla uyumluluk.
  final UserRepository? repository;
  final UserRepository? userRepository;
  final ChatRepository? chatRepository;

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  late final UserRepository _users =
      widget.userRepository ?? widget.repository ?? userRepositoryInstance;
  late final ChatRepository _chats = widget.chatRepository ?? chatRepositoryInstance;

  final _controller = TextEditingController();

  List<UserProfile> _results = const [];
  Set<String> _blocked = const {};
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _error;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _users.fetchBlockedUids().then((value) {
      if (mounted) setState(() => _blocked = value);
    });
  }

  /// Yazarken arar; her tuşta istek atmasın diye 250 ms beklenir.
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _search(_controller.text),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String raw) async {
    final query = Username.normalize(raw);
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _hasSearched = query.isNotEmpty;
        _isSearching = false;
        _error = null;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final found = await _users.searchUsers(query, excludeUids: _blocked);
      if (!mounted) return;
      setState(() {
        _results = found;
        _hasSearched = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kullanıcılar aranamadı. ($e)';
        _hasSearched = true;
      });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _startChat(UserProfile profile) async {
    try {
      final roomId = await _chats.openDirectChat(
        peerUid: profile.uid,
        peerName: profile.displayName,
        peerPhotoUrl: profile.photoUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(roomId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sohbet açılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.82,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: context.line)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: context.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Yeni sohbet',
                      style: context.texts.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: AppTextField(
                controller: _controller,
                hintText: '@kullanıcıadı veya isim',
                labelText: 'Kullanıcı ara',
                prefixIcon: Icons.search_rounded,
                autofocus: true,
                textInputAction: TextInputAction.search,
              ),
            ),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_isSearching && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Hint(
        icon: Icons.cloud_off_rounded,
        title: 'Arama yapılamadı',
        message: _error!,
      );
    }

    if (!_hasSearched) {
      return const _Hint(
        icon: Icons.alternate_email_rounded,
        title: 'Kullanıcı adıyla ara',
        message:
            'Sohbet başlatmak için kişinin kullanıcı adını (@ayse_y) ya da '
            'görünen adını yaz. En az 2 karakter gerekir.',
      );
    }

    if (_results.isEmpty) {
      return const _Hint(
        icon: Icons.person_search_rounded,
        title: 'Sonuç yok',
        message: 'Bu ada uyan bir kullanıcı bulunamadı. '
            'Yazımı kontrol et veya tam kullanıcı adını dene.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        color: context.line,
        indent: 68,
      ),
      itemBuilder: (context, index) {
        final profile = _results[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          leading: UserAvatar(
            name: profile.displayName,
            size: 44,
            photoUrl: profile.photoUrl,
            emoji: profile.avatarEmoji,
            colorIndex: profile.avatarColor,
          ),
          title: Text(
            profile.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            profile.username.isEmpty
                ? 'kullanıcı adı yok'
                : '@${profile.username}',
            style: TextStyle(fontSize: 12.5, color: context.muted),
          ),
          trailing: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: context.muted,
          ),
          onTap: () => _startChat(profile),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: context.colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: context.muted),
            ),
          ],
        ),
      ),
    );
  }
}
