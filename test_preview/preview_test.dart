// GELİŞTİRME ARACI — uygulamanın bir parçası değildir.
//
// Ekranları Firebase olmadan (sahte veriyle) PNG'ye render eder, böylece
// UI'ı telefona kurmadan gözden geçirebilirsiniz:
//
//   flutter test test_preview/preview_test.dart --update-goldens
//
// Çıktılar: test_preview/goldens/*.png
// CI: .github/workflows/screenshots.yml bu dosyayı çalıştırıp görselleri
// docs/ekranlar/ altına işler.
// Not: `flutter test` bu klasörü taramaz (test/ dışında olduğu için).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sohbet/core/theme/app_theme.dart';
import 'package:sohbet/core/theme/brand_assets.dart';
import 'package:sohbet/features/auth/presentation/login_screen.dart';
import 'package:sohbet/features/auth/presentation/register_screen.dart';
import 'package:sohbet/features/auth/presentation/splash_screen.dart';
import 'package:sohbet/features/chat/data/chat_repository.dart';
import 'package:sohbet/features/chat/domain/models/chat_message.dart';
import 'package:sohbet/features/chat/domain/models/chat_room.dart';
import 'package:sohbet/features/chat/domain/models/room_invite.dart';
import 'package:sohbet/features/chat/presentation/channels_screen.dart';
import 'package:sohbet/features/chat/presentation/chat_screen.dart';
import 'package:sohbet/features/chat/presentation/join_invite_screen.dart';
import 'package:sohbet/features/chat/presentation/new_chat_sheet.dart';
import 'package:sohbet/features/moderation/data/moderation_repository.dart';
import 'package:sohbet/features/moderation/presentation/reports_screen.dart';
import 'package:sohbet/features/chat/presentation/room_settings_screen.dart';
import 'package:sohbet/features/chat/presentation/rooms_screen.dart';
import 'package:sohbet/features/profile/data/user_repository.dart';
import 'package:sohbet/features/profile/domain/user_profile.dart';
import 'package:sohbet/features/profile/presentation/blocked_users_screen.dart';
import 'package:sohbet/features/profile/presentation/edit_profile_screen.dart';
import 'package:sohbet/features/profile/presentation/profile_screen.dart';
import 'package:sohbet/features/profile/presentation/terms_sheet.dart';
import 'package:sohbet/features/setup/setup_screen.dart';

/// Firebase'e dokunmayan sahte sohbet deposu.
class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({
    this.rooms = const [],
    this.messages = const [],
    this.channels = const [],
  });

  final List<ChatRoom> rooms;
  final List<ChatMessage> messages;
  final List<ChatRoom> channels;

  @override
  Stream<List<ChatRoom>> watchRooms() =>
      Stream.value(rooms.where((room) => !room.isChannel).toList());

  @override
  Stream<List<ChatRoom>> watchChannels() => Stream.value(channels);

  @override
  Stream<ChatRoom?> watchRoom(String roomId) {
    for (final room in [...rooms, ...channels]) {
      if (room.id == roomId) return Stream.value(room);
    }
    return Stream.value(null);
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String roomId) =>
      Stream.value(messages);

  @override
  Future<String> openDirectChat({
    required String peerUid,
    required String peerName,
    String peerPhotoUrl = '',
  }) async =>
      'dm_fake';

  @override
  Future<void> sendMessage(
    String roomId, {
    String text = '',
    String type = MessageType.text,
    String mediaBase64 = '',
    String mediaMime = '',
    int durationMs = 0,
    ReplyInfo? reply,
  }) async {}

  @override
  Future<void> setTyping(String roomId, bool typing) async {}

  @override
  Future<void> markRead(String roomId) async {}

  @override
  Future<void> toggleReaction(
    String roomId,
    String messageId,
    String emoji,
  ) async {}

  @override
  Future<void> deleteMessage(String roomId, String messageId) async {}

  @override
  Future<void> editMessage(
    String roomId,
    String messageId,
    String text,
  ) async {}

  @override
  Future<String> createChannel({
    required String name,
    String about = '',
    bool isPrivate = false,
  }) async =>
      'kanal_fake';

  @override
  Future<void> joinChannel(String roomId) async {}

  @override
  Future<void> leaveChannel(String roomId) async {}

  @override
  Future<bool> hasBlocked(String otherUid) async => false;

  @override
  Future<void> hideChat(String roomId) async {}

  @override
  Future<void> deleteChat(String roomId) async {}

  // ------------------------------------------------- kanal / grup yönetimi
  @override
  Future<RoomInvite> createInvite({
    required String roomId,
    String roomName = '',
    String roomType = '',
  }) async =>
      RoomInvite(
        code: 'K7M2P9QD',
        roomId: roomId,
        createdBy: 'u1',
        roomName: roomName,
        roomType: roomType,
      );

  @override
  Stream<List<RoomInvite>> watchInvites(String roomId) => Stream.value(
        const <RoomInvite>[],
      );

  @override
  Future<void> revokeInvite(String code) async {}

  @override
  Future<String> joinByInviteCode(String rawCode) async => 'r1';

  @override
  Future<void> setChannelPrivacy(
    String roomId, {
    required bool isPrivate,
  }) async {}

  @override
  Future<void> updateRoomInfo(
    String roomId, {
    String? name,
    String? about,
  }) async {}

  @override
  Future<void> setRoomPhoto(String roomId, String dataUri) async {}

  @override
  Future<void> hideMessageForMe(String roomId, String messageId) async {}

  @override
  Stream<Set<String>> watchHiddenMessageIds(String roomId) =>
      Stream<Set<String>>.value(const <String>{});

  @override
  Future<void> deleteMessageAsModerator(String roomId, String messageId) async {}

  @override
  Future<void> restoreMessage(String roomId, ChatMessage message) async {}

  @override
  Future<void> unhideMessage(String roomId, String messageId) async {}

  @override
  Future<void> setPermission(
    String roomId,
    String key, {
    required bool value,
  }) async {}

  @override
  Future<void> setModerator(
    String roomId,
    String uid, {
    required bool moderator,
  }) async {}

  @override
  Future<void> removeMember(String roomId, String uid) async {}

  @override
  Future<void> addMember(
    String roomId, {
    required String uid,
    String name = '',
    String photoUrl = '',
  }) async {}

  @override
  Future<void> transferOwnership(String roomId, String newOwnerUid) async {}

  @override
  Future<void> leaveRoom(String roomId) async {}

  @override
  Future<Map<String, String>> fetchMemberInfo(String uid) async =>
      const <String, String>{};
}

/// Firebase'e dokunmayan sahte kullanıcı deposu.
class _FakeUserRepository implements UserRepository {
  _FakeUserRepository({
    required this.me,
    this.directory = const <UserProfile>[],
    this.blocked = const <String>{},
    this.blockedProfiles = const <UserProfile>[],
  });

  final UserProfile me;
  final List<UserProfile> directory;
  final Set<String> blocked;
  final List<UserProfile> blockedProfiles;

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      Stream.value(uid == me.uid ? me : null);

  @override
  Stream<UserProfile?> watchMyProfile() => Stream.value(me);

  @override
  Future<UserProfile?> fetchProfile(String uid) async =>
      uid == me.uid ? me : null;

  @override
  Future<List<UserProfile>> searchUsers(
    String rawQuery, {
    Set<String> excludeUids = const <String>{},
  }) async {
    final query = rawQuery.toLowerCase().trim();
    return directory
        .where((p) =>
            p.displayName.toLowerCase().contains(query) ||
            p.usernameLower.contains(query))
        .toList();
  }

  @override
  Future<void> saveProfile({
    required String displayName,
    required String username,
    String bio = '',
    String photoUrl = '',
    String avatarEmoji = '',
    int avatarColor = 0,
  }) async {}

  @override
  Future<void> touchLastSeen() async {}

  @override
  Future<void> acceptTerms({String version = '2026-10-27'}) async {}

  @override
  Stream<Set<String>> watchBlockedUids() => Stream.value(blocked);

  @override
  Future<Set<String>> fetchBlockedUids() async => blocked;

  @override
  Future<void> blockUser(String blockedUid) async {}

  @override
  Future<void> unblockUser(String blockedUid) async {}

  @override
  Future<List<UserProfile>> fetchBlockedProfiles() async => blockedProfiles;
}


/// Firebase'e dokunmayan sahte şikayet deposu (inceleme paneli).
class _FakeModerationRepository implements ModerationRepository {
  _FakeModerationRepository({this.reports = const <ReportItem>[]});

  final List<ReportItem> reports;

  @override
  Future<bool> isAdmin() async => true;

  @override
  Stream<List<ReportItem>> watchReports() => Stream.value(reports);

  @override
  Future<void> updateReportStatus(String reportId, String status) async {}

  @override
  Stream<List<SupportTicket>> watchMySupportTickets() =>
      Stream.value(const <SupportTicket>[]);

  @override
  Future<void> sendReport({
    required String targetUid,
    required String reason,
    String targetName = '',
    String details = '',
    String roomId = '',
    String messageId = '',
    String messageSnippet = '',
  }) async {}

  @override
  Future<void> sendSupportRequest({
    required String topic,
    required String message,
  }) async {}
}

/// Fontların bulunduğu Flutter SDK kökünü bulur.
///
/// CI'da FLUTTER_ROOT tanımlıdır; yerelde de çalışabilmesi için çalışan
/// dart'ın yolundan yukarı doğru `bin/cache/artifacts/material_fonts`
/// aranır.
String? _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && env.trim().isNotEmpty) return env.trim();

  var dir = File(Platform.resolvedExecutable).parent;
  while (true) {
    if (Directory('${dir.path}/bin/cache/artifacts/material_fonts')
        .existsSync()) {
      return dir.path;
    }
    // dart-sdk içinden gelindiyse: <flutter>/bin/cache/dart-sdk/bin/dart
    if (Directory('${dir.path}/artifacts/material_fonts').existsSync()) {
      return dir.parent.parent.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
}

Future<void> _loadFonts() async {
  final root = _flutterRoot();
  final fontDir = Directory('$root/bin/cache/artifacts/material_fonts');
  if (root == null || !fontDir.existsSync()) {
    throw StateError(
      'Flutter font klasörü bulunamadı (FLUTTER_ROOT=$root). '
      'Golden görüntüler font olmadan anlamsız olur.',
    );
  }

  final roboto = FontLoader('Roboto');
  var loaded = false;
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final file = File('${fontDir.path}/$name');
    if (!file.existsSync()) continue;
    roboto.addFont(
      Future.value(ByteData.view(file.readAsBytesSync().buffer)),
    );
    loaded = true;
  }
  if (loaded) await roboto.load();

  final iconsFile = File('${fontDir.path}/MaterialIcons-Regular.otf');
  if (iconsFile.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(ByteData.view(iconsFile.readAsBytesSync().buffer)),
      );
    await icons.load();
  }
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: child,
    );

Future<void> _loadBrandAssets() async {
  // İlk golden'da logo boş görünmesin diye marka görselleri önceden okunur.
  final mark = await rootBundle.load('assets/brand/rebelz-mark.png');
  final wordmark = await rootBundle.load('assets/brand/rebelz-wordmark.png');
  expect(mark.lengthInBytes, greaterThan(0));
  expect(wordmark.lengthInBytes, greaterThan(0));
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    await _loadBrandAssets();
  });

  setUp(() {
    // iPhone 14 benzeri mantıksal ölçüler (390 x 844), 3x yoğunluk.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });

  // Golden'larda marka görselleri boş görünmesin: ImageCache'e ısıt.
  testWidgets('00 marka görselleri ısınma', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    final context = tester.element(find.byType(SizedBox).first);
    await tester.runAsync(() async {
      for (final asset in const [
        BrandAssets.brush,
        BrandAssets.mark,
        BrandAssets.banner,
        BrandAssets.googleG,
        BrandAssets.grunge,
      ]) {
        await precacheImage(AssetImage(asset), context);
      }
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  final now = DateTime.now();

  final rooms = <ChatRoom>[
    ChatRoom(
      id: 'r1',
      name: 'Deniz Kaya',
      createdBy: 'u1',
      memberIds: const ['u1', 'u2'],
      type: 'dm',
      memberNames: const {'u1': 'Ayşe Yılmaz', 'u2': 'Deniz Kaya'},
      lastMessage: 'Yeni ekran akışını Figma\'ya yükledim',
      lastSenderId: 'u2',
      lastMessageAt: DateTime(now.year, now.month, now.day, 14, 32),
    ),
    ChatRoom(
      id: 'r2',
      name: 'Emre Demir',
      createdBy: 'u2',
      memberIds: const ['u1', 'u3'],
      type: 'dm',
      memberNames: const {'u1': 'Ayşe Yılmaz', 'u3': 'Emre Demir'},
      lastMessage: 'Akşam 8 gibi orada olurum.',
      lastSenderId: 'u3',
      lastMessageAt: DateTime(now.year, now.month, now.day, 11, 5),
      typing: {'u3': now.subtract(const Duration(seconds: 1))},
    ),
    ChatRoom(
      id: 'r3',
      name: 'Genel',
      createdBy: 'u1',
      memberIds: const ['u1', 'u2', 'u3'],
      lastMessage: 'Hoş geldiniz!',
      lastMessageAt: now.subtract(const Duration(days: 2)),
    ),
    ChatRoom(
      id: 'r4',
      name: 'Flutter Türkiye',
      createdBy: 'u3',
      memberIds: const ['u1', 'u3'],
      lastMessage: 'Riverpod 3 çıktı, deneyen var mı?',
      lastMessageAt: now.subtract(const Duration(days: 6)),
    ),
  ];

  final messages = <ChatMessage>[
    ChatMessage(
      id: 'm5',
      senderId: 'u1',
      senderName: 'Ayşe Yılmaz',
      text: 'Süper! Yarın giriş ekranını da bitiriyorum.',
      createdAt: now.subtract(const Duration(seconds: 40)),
      readBy: const ['u1', 'u2'],
    ),
    ChatMessage(
      id: 'm4',
      senderId: 'u1',
      senderName: 'Ayşe Yılmaz',
      text: 'Sesli not bırakıyorum, müsait olunca dinle.',
      type: MessageType.audio,
      durationMs: 12000,
      createdAt: now.subtract(const Duration(minutes: 3)),
      readBy: const ['u1'],
    ),
    ChatMessage(
      id: 'm3',
      senderId: 'u2',
      senderName: 'Deniz Kaya',
      text: 'Kırmızı vurgu tam logo ile uyumlu olmuş. Baloncuklar da '
          'WhatsApp gibi okunuyor.',
      reply: const ReplyInfo(
        id: 'm2',
        senderName: 'Deniz Kaya',
        preview: 'Firebase Auth + Firestore bağladınız mı?',
      ),
      reactions: const {'u1': '❤️', 'u3': '🔥'},
      createdAt: now.subtract(const Duration(minutes: 14)),
    ),
    ChatMessage(
      id: 'm2',
      senderId: 'u2',
      senderName: 'Deniz Kaya',
      text: 'Firebase Auth + Firestore bağladınız mı?',
      createdAt: now.subtract(const Duration(minutes: 15)),
    ),
    ChatMessage(
      id: 'm1',
      senderId: 'u1',
      senderName: 'Ayşe Yılmaz',
      text: 'Selam! Rebelz Media iskeletini kurdum, göz atar mısın?',
      createdAt: now.subtract(const Duration(minutes: 42)),
    ),
  ];

  final channels = <ChatRoom>[
    ChatRoom(
      id: 'c1',
      name: 'Rebelz Duyuru',
      createdBy: 'u1',
      ownerUid: 'u1',
      memberIds: const ['u1'],
      type: 'channel',
      about: 'Ürün güncellemeleri ve yeni özellikler',
      subscriberCount: 128,
      lastMessage: 'Karanlık tema artık sistemle uyumlu.',
      lastMessageAt: now.subtract(const Duration(hours: 3)),
    ),
    ChatRoom(
      id: 'c2',
      name: 'Flutter Türkiye',
      createdBy: 'u3',
      ownerUid: 'u3',
      memberIds: const ['u3'],
      type: 'channel',
      about: 'Haftalık Flutter bülteni',
      subscriberCount: 964,
      lastMessage: 'Bu hafta: Impeller ve yeni Material 3 bileşenleri.',
      lastMessageAt: now.subtract(const Duration(days: 1)),
    ),
  ];

  final me = UserProfile(
    uid: 'u1',
    displayName: 'Ayşe Yılmaz',
    username: 'ayse_y',
    bio: 'Ürün tasarımcısı · Flutter ile ilgileniyorum.',
    avatarEmoji: '🦊',
    avatarColor: 1,
    email: 'ayse@example.com',
    termsVersion: '2026-10-27',
    termsAcceptedAt: now,
  );

  const deniz = UserProfile(
    uid: 'u2',
    displayName: 'Deniz Kaya',
    username: 'deniz_k',
    bio: 'Mobil geliştirici',
    avatarEmoji: '🐺',
    avatarColor: 3,
  );

  const emre = UserProfile(
    uid: 'u3',
    displayName: 'Emre Demir',
    username: 'emre_d',
    avatarEmoji: '🚀',
    avatarColor: 2,
  );

  final users = _FakeUserRepository(
    me: me,
    directory: const [
      deniz,
      emre,
      UserProfile(
        uid: 'u4',
        displayName: 'Deniz Su',
        username: 'deniz_su',
        avatarEmoji: '🌙',
        avatarColor: 4,
      ),
    ],
    blocked: const {'u3'},
    blockedProfiles: const [emre],
  );

  testWidgets('01 splash', (tester) async {
    await tester.pumpWidget(_wrap(const SplashScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01_splash.png'),
    );
  });

  testWidgets('02 login', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_login.png'),
    );
  });

  testWidgets('03 register (koşul onayı kutusu)', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/03_register.png'),
    );
  });

  testWidgets('04 rooms', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RoomsScreen(
          repository: _FakeChatRepository(rooms: rooms),
          userRepository: users,
          currentUserName: 'Ayşe Yılmaz',
          myUid: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/04_rooms.png'),
    );
  });

  testWidgets('05 rooms_empty', (tester) async {
    await tester.pumpWidget(
      _wrap(
        RoomsScreen(
          repository: _FakeChatRepository(),
          userRepository: users,
          currentUserName: 'Ayşe Yılmaz',
          myUid: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/05_rooms_empty.png'),
    );
  });

  testWidgets('06 chat', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChatScreen(
          roomId: 'r1',
          roomName: 'Tasarım Ekibi',
          repository: _FakeChatRepository(rooms: rooms, messages: messages),
          userRepository: users,
          currentUserId: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06_chat.png'),
    );
  });

  testWidgets('20 mesaj işlemleri menüsü', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChatScreen(
          roomId: 'r1',
          roomName: 'Tasarım Ekibi',
          repository: _FakeChatRepository(rooms: rooms, messages: messages),
          userRepository: users,
          currentUserId: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Kendi metin mesajına uzun bas → alt menü açılır.
    final own = find.text('Süper! Yarın giriş ekranını da bitiriyorum.').first;
    await tester.longPress(own);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/20_message_actions.png'),
    );
  });

  testWidgets('21 silme geri al bildirimi', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChatScreen(
          roomId: 'r1',
          roomName: 'Tasarım Ekibi',
          repository: _FakeChatRepository(rooms: rooms, messages: messages),
          userRepository: users,
          currentUserId: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.longPress(
      find.text('Süper! Yarın giriş ekranını da bitiriyorum.').first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Benden sil'));
    await tester.pumpAndSettle();

    // 5 saniyelik geri alma bildirimi görünür kalmalı.
    expect(find.text('Geri al'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/21_undo_snackbar.png'),
    );
  });

  testWidgets('07 setup', (tester) async {
    await tester.pumpWidget(_wrap(const SetupScreen()));
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/07_setup.png'),
    );
  });

  testWidgets('08 profil', (tester) async {
    await tester.pumpWidget(
      _wrap(ProfileScreen(repository: users)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/08_profile.png'),
    );
  });

  testWidgets('09 profil düzenleme', (tester) async {
    await tester.pumpWidget(
      _wrap(EditProfileScreen(profile: me, repository: users)),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/09_profile_edit.png'),
    );
  });

  testWidgets('10 yeni sohbet (kullanıcı adı arama)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          backgroundColor: AppTheme.dark.scaffoldBackgroundColor,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NewChatSheet(repository: users),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'deniz');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/10_new_chat.png'),
    );
  });

  testWidgets('11 engellenenler', (tester) async {
    await tester.pumpWidget(
      _wrap(BlockedUsersScreen(repository: users)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/11_blocked.png'),
    );
  });

  testWidgets('12 kullanım koşulları', (tester) async {
    await tester.pumpWidget(_wrap(const TermsScreen()));
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/12_terms.png'),
    );
  });

  final blocking = _FakeUserRepository(me: me, blocked: const {'u2'});

  testWidgets('15 kanallar', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChannelsScreen(
          repository: _FakeChatRepository(rooms: rooms, channels: channels),
          myUid: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/15_channels.png'),
    );
  });

  testWidgets('16 profil — açık tema', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ProfileScreen(repository: users),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/16_profile_light.png'),
    );
  });

  testWidgets('13 sohbet — engellenen kişi', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ChatScreen(
          roomId: 'r1',
          roomName: 'Tasarım Ekibi',
          repository: _FakeChatRepository(rooms: rooms, messages: messages),
          userRepository: blocking,
          currentUserId: 'u1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/13_chat_blocked.png'),
    );
  });

  testWidgets('17 kanal ayarları (moderatörler ve izinler)', (tester) async {
    const kanal = ChatRoom(
      id: 'c9',
      name: 'Rebelz Duyuru',
      createdBy: 'u1',
      ownerUid: 'u1',
      memberIds: ['u1', 'u2', 'u3'],
      type: 'channel',
      about: 'Ürün güncellemeleri ve yeni özellikler',
      subscriberCount: 128,
      roles: {'u2': ChatRoom.roleModerator},
      memberNames: {
        'u1': 'Ayşe Yılmaz',
        'u2': 'Deniz Kaya',
        'u3': 'Emre Demir',
      },
      permissions: {ChatRoom.permModsDeleteMessages: true},
    );

    await tester.pumpWidget(
      _wrap(
        RoomSettingsScreen(
          roomId: 'c9',
          repository: _FakeChatRepository(rooms: <ChatRoom>[kanal]),
          userRepository: users,
          currentUserId: 'u1',
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/17_room_settings.png'),
    );
  });

  testWidgets('18 şikayet inceleme paneli', (tester) async {
    final now = DateTime.now();
    final reports = <ReportItem>[
      ReportItem(
        id: 'r1',
        reporterUid: 'u2',
        reporterName: 'Deniz Kaya',
        targetUid: 'u3',
        targetName: 'Emre Demir',
        reason: 'Spam / reklam',
        details: 'Sürekli aynı reklam bağlantısını gönderiyor.',
        status: ReportStatus.open,
        roomId: 'r1',
        messageId: 'm1',
        messageSnippet: 'Kazanmak için tıkla: ornek-kampanya.com',
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      ReportItem(
        id: 'r2',
        reporterUid: 'u3',
        reporterName: 'Emre Demir',
        targetUid: 'u2',
        targetName: 'Deniz Kaya',
        reason: 'Taciz veya zorbalık',
        status: ReportStatus.open,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      ReportItem(
        id: 'r3',
        reporterUid: 'u4',
        reporterName: 'Selin',
        targetUid: 'u5',
        targetName: 'Kaan',
        reason: 'Sahte hesap',
        status: ReportStatus.resolved,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        ReportsScreen(
          repository: _FakeModerationRepository(reports: reports),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/18_reports.png'),
    );
  });

  testWidgets('19 davet ekranı', (tester) async {
    await tester.pumpWidget(
      _wrap(
        JoinInviteScreen(
          code: 'K7M2P9QD',
          repository: _FakeChatRepository(rooms: rooms),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/19_join_invite.png'),
    );
  });
}
