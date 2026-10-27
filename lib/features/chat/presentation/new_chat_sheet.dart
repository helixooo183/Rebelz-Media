import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/user_repository.dart';
import '../../profile/domain/user_profile.dart';

/// Kullanıcı adı ve görünen adla başlayan sohbet için kullanıcı seçimi.
///
/// "[Yeni sohbet]" butonundan açılır: kullanıcı adı yazıldıkça eşleşen
/// profiller (fotoğraf + ad + @kullanıcıadı) listelenir.
Future<String?> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const NewChatSheet(),
  );
}

class NewChatSheet extends StatefulWidget {
  const NewChatSheet({super.key, this.repository});

  final UserRepository? repository;

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  late final UserRepository _users = widget.repository ?? userRepositoryInstance;
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
      final found = await _users.searchUsers(query);
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
      final roomId = await chatRepositoryInstance.openDirectChat(
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
        height: MediaQuery.sizeOf(context).height * 0.78,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AppColors.outline)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Yeni sohbet',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Kapat',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppTextField(
                controller: _controller,
                hintText: 'kullanıcı adı (ör. ayse_y)',
                prefixIcon: Icons.alternate_email,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  _debounce?.cancel();
                  _search(value);
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _Info(
        icon: Icons.cloud_off_outlined,
        title: 'Arama başarısız',
        message: _error!,
      );
    }

    if (!_hasSearched) {
      return const _Info(
        icon: Icons.person_search_outlined,
        title: 'Kullanıcı adıyla ara',
        message: 'Yazdığın kullanıcı adıyla eşleşen kişiler burada listelenir. '
            'Sohbet başlatmak için birine dokun.',
      );
    }

    if (_results.isEmpty) {
      return const _Info(
        icon: Icons.search_off_outlined,
        title: 'Kimse bulunamadı',
        message: 'Kullanıcı adının tamamını veya bir kısmını yazmayı dene. '
            'Karşı tarafın profilinde kullanıcı adı tanımlı olmalı.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final profile = _results[index];
        final isBlocked = _blocked.contains(profile.uid);

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: isBlocked ? null : () => _startChat(profile),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  UserAvatar(
                    name: profile.displayName,
                    size: 44,
                    photoUrl: profile.photoUrl,
                    emoji: profile.avatarEmoji,
                    colorIndex: profile.avatarColor,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isBlocked ? 'Engellendi' : profile.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isBlocked
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isBlocked ? Icons.block : Icons.chat_bubble_outline,
                    size: 20,
                    color: isBlocked ? AppColors.danger : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
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
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
