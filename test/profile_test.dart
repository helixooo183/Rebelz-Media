import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sohbet/core/theme/app_theme.dart';
import 'package:sohbet/features/chat/data/chat_repository.dart';
import 'package:sohbet/features/chat/domain/models/chat_room.dart';
import 'package:sohbet/features/profile/domain/legal_texts.dart';
import 'package:sohbet/features/profile/domain/user_profile.dart';
import 'package:sohbet/features/profile/presentation/terms_sheet.dart';

void main() {
  group('Username', () {
    test('baştaki @ ve büyük harfler normalize edilir', () {
      expect(Username.normalize('  @Ayse_Y '), 'ayse_y');
    });

    test('geçerli adlar kabul edilir', () {
      expect(Username.isValid('ayse_y'), isTrue);
      expect(Username.isValid('user123'), isTrue);
      expect(Username.isValid('abc'), isTrue);
    });

    test('geçersiz adlar reddedilir', () {
      expect(Username.isValid('ab'), isFalse);
      expect(Username.isValid('ayşe'), isFalse);
      expect(Username.isValid('ayse-y'), isFalse);
      expect(Username.isValid('a' * 21), isFalse);
      expect(Username.validate(''), isNotNull);
      expect(Username.validate('ayse_y'), isNull);
    });
  });

  group('UserProfile', () {
    test('eksik alanlarda güvenli varsayılanlar kullanılır', () {
      final profile = UserProfile.fromMap('uid1', {'displayName': '  '});

      expect(profile.displayName, 'Kullanıcı');
      expect(profile.username, isEmpty);
      expect(profile.handle, '@kullanici');
      expect(profile.termsAccepted, isFalse);
      expect(profile.initial, 'K');
    });

    test('handle ve baş harf üretilir', () {
      const profile = UserProfile(
        uid: 'uid1',
        displayName: 'ayşe',
        username: 'ayse_y',
      );

      expect(profile.handle, '@ayse_y');
      expect(profile.initial, 'A');
      expect(profile.hasPhoto, isFalse);
    });

    test('fotoğraf varsa hasPhoto true olur', () {
      const profile = UserProfile(
        uid: 'uid1',
        displayName: 'Ayşe',
        photoUrl: 'https://example.com/a.png',
      );

      expect(profile.hasPhoto, isTrue);
    });
  });

  group('ChatRoom', () {
    test('dm odasında karşı taraf bulunur', () {
      const room = ChatRoom(
        id: 'dm_a_b',
        name: 'Deniz',
        createdBy: 'u1',
        memberIds: ['u1', 'u2'],
        type: 'dm',
      );

      expect(room.isDirect, isTrue);
      expect(room.peerUid('u1'), 'u2');
      expect(room.peerUid('u2'), 'u1');
      expect(room.peerUid(null), isNull);
    });

    test('grup odasında peerUid null olur', () {
      const room = ChatRoom(
        id: 'r1',
        name: 'Genel',
        createdBy: 'u1',
        memberIds: ['u1', 'u2', 'u3'],
      );

      expect(room.isDirect, isFalse);
      expect(room.peerUid('u1'), isNull);
      expect(room.hasMember('u3'), isTrue);
    });

    test('doğrudan sohbet kimliği iki uid için tek kayıt üretir', () {
      expect(
        ChatRepository.directChatId('b', 'a'),
        ChatRepository.directChatId('a', 'b'),
      );
      expect(ChatRepository.directChatId('b', 'a'), 'dm_a_b');
    });
  });

  group('LegalTexts', () {
    test('sürüm ve metin dolu', () {
      expect(LegalTexts.version, isNotEmpty);
      expect(LegalTexts.sections, isNotEmpty);
      expect(LegalTexts.plainText, contains('Kullanım'));
      expect(LegalTexts.checkboxLabel, contains('kabul'));
    });
  });

  testWidgets('TermsCheckbox dokunuşla işaretlenir', (tester) async {
    var value = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => TermsCheckbox(
              value: value,
              onChanged: (v) => setState(() => value = v),
            ),
          ),
        ),
      ),
    );

    expect(find.text(LegalTexts.checkboxLabel), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(value, isTrue);
  });
}
