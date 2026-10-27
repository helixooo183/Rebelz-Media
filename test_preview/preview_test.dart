// GELİŞTİRME ARACI — uygulamanın bir parçası değildir.
//
// Ekranları Firebase olmadan (sahte veriyle) PNG'ye render eder, böylece
// UI'ı telefona kurmadan gözden geçirebilirsiniz:
//
//   flutter test test_preview/preview_test.dart --update-goldens
//
// Çıktılar: test_preview/goldens/*.png
// Not: `flutter test` bu klasörü taramaz (test/ dışında olduğu için).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sohbet/core/theme/app_theme.dart';
import 'package:sohbet/features/auth/presentation/login_screen.dart';
import 'package:sohbet/features/auth/presentation/register_screen.dart';
import 'package:sohbet/features/auth/presentation/splash_screen.dart';
import 'package:sohbet/features/chat/data/chat_repository.dart';
import 'package:sohbet/features/chat/domain/models/chat_message.dart';
import 'package:sohbet/features/chat/domain/models/chat_room.dart';
import 'package:sohbet/features/chat/presentation/chat_screen.dart';
import 'package:sohbet/features/chat/presentation/rooms_screen.dart';
import 'package:sohbet/features/setup/setup_screen.dart';

/// Firebase'e dokunmayan sahte depo.
class _FakeChatRepository implements ChatRepository {
  _FakeChatRepository({this.rooms = const [], this.messages = const []});

  final List<ChatRoom> rooms;
  final List<ChatMessage> messages;

  @override
  Stream<List<ChatRoom>> watchRooms() => Stream.value(rooms);

  @override
  Stream<ChatRoom?> watchRoom(String roomId) {
    for (final room in rooms) {
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
  Future<void> sendMessage(String roomId, String text) async {}

  @override
  Future<bool> hasBlocked(String otherUid) async => false;

  @override
  Future<void> hideChat(String roomId) async {}

  @override
  Future<void> deleteChat(String roomId) async {}
}

Future<void> _loadFonts() async {
  const fontDir =
      '/var/tmp/flutter/bin/cache/artifacts/material_fonts';

  final roboto = FontLoader('Roboto');
  for (final file in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
    roboto.addFont(
      Future.value(
        ByteData.view(File('$fontDir/$file').readAsBytesSync().buffer),
      ),
    );
  }
  await roboto.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.view(
          File('$fontDir/MaterialIcons-Regular.otf').readAsBytesSync().buffer,
        ),
      ),
    );
  await icons.load();
}

Widget _wrap(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: child,
    );

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    // iPhone 14 benzeri mantıksal ölçüler (390 x 844), 2x yoğunluk.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });

  final now = DateTime.now();

  final rooms = <ChatRoom>[
    ChatRoom(
      id: 'r1',
      name: 'Tasarım Ekibi',
      createdBy: 'u1',
      memberIds: const ['u1', 'u2'],
      lastMessage: 'Yeni ekran akışını Figma\'ya yükledim',
      lastMessageAt: DateTime(now.year, now.month, now.day, 14, 32),
    ),
    ChatRoom(
      id: 'r2',
      name: 'Deniz',
      createdBy: 'u2',
      memberIds: const ['u1', 'u2'],
      lastMessage: 'Akşam 8 gibi orada olurum.',
      lastMessageAt: DateTime(now.year, now.month, now.day, 11, 5),
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
      id: 'm4',
      senderId: 'u1',
      senderName: 'Sen',
      text: 'Süper! Yarın giriş ekranını da bitiriyorum.',
      createdAt: now.subtract(const Duration(minutes: 3)),
    ),
    ChatMessage(
      id: 'm3',
      senderId: 'u2',
      senderName: 'Deniz',
      text: 'İskelet çok temiz görünüyor, koyu tema tam istediğimiz gibi.',
      createdAt: now.subtract(const Duration(minutes: 14)),
    ),
    ChatMessage(
      id: 'm2',
      senderId: 'u2',
      senderName: 'Deniz',
      text: 'Firebase Auth + Firestore bağladınız mı?',
      createdAt: now.subtract(const Duration(minutes: 15)),
    ),
    ChatMessage(
      id: 'm1',
      senderId: 'u1',
      senderName: 'Sen',
      text: 'Selam! Proje iskeletini kurdum, göz atar mısın?',
      createdAt: now.subtract(const Duration(minutes: 42)),
    ),
  ];

  testWidgets('01 splash', (tester) async {
    await tester.pumpWidget(_wrap(const SplashScreen()));
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/01_splash.png'),
    );
  });

  testWidgets('02 login', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/02_login.png'),
    );
  });

  testWidgets('03 register', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));
    await tester.pump();
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
          currentUserName: 'Ayşe Yılmaz',
        ),
      ),
    );
    await tester.pumpAndSettle();
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
          currentUserName: 'Ayşe Yılmaz',
        ),
      ),
    );
    await tester.pumpAndSettle();
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
          repository: _FakeChatRepository(messages: messages),
          currentUserId: 'u1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/06_chat.png'),
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
}
