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

  group('Kullanıcı adı kotası', () {
    final simdi = DateTime(2026, 10, 27, 12);

    test('hiç değiştirilmemişse 2 hak vardır', () {
      expect(
        UsernameChangePolicy.remaining(used: 0, windowStart: null, now: simdi),
        UsernameChangePolicy.maxChanges,
      );
    });

    test('1 değişiklikte 1 hak kalır', () {
      expect(
        UsernameChangePolicy.remaining(
          used: 1,
          windowStart: simdi.subtract(const Duration(days: 3)),
          now: simdi,
        ),
        1,
      );
    });

    test('2 değişiklikte kilitlenir ve açılma zamanı 30. gündür', () {
      final baslangic = simdi.subtract(const Duration(days: 10));
      expect(
        UsernameChangePolicy.remaining(
          used: 2,
          windowStart: baslangic,
          now: simdi,
        ),
        0,
      );
      expect(
        UsernameChangePolicy.unlockAt(
          used: 2,
          windowStart: baslangic,
          now: simdi,
        ),
        baslangic.add(const Duration(days: UsernameChangePolicy.windowDays)),
      );
    });

    test('dönem dolunca haklar yeniden 2 olur', () {
      expect(
        UsernameChangePolicy.remaining(
          used: 2,
          windowStart: simdi.subtract(const Duration(days: 31)),
          now: simdi,
        ),
        UsernameChangePolicy.maxChanges,
      );
      expect(
        UsernameChangePolicy.unlockAt(
          used: 2,
          windowStart: simdi.subtract(const Duration(days: 31)),
          now: simdi,
        ),
        isNull,
      );
    });

    test('kalan süre metni gün cinsinden yazılır', () {
      // Gerçek "şimdi"ye göre hesaplanır: 12 gün 1 saat sonrası → 12 gün.
      final onIkiGunSonra =
          DateTime.now().add(const Duration(days: 12, hours: 1));
      expect(UsernameChangePolicy.waitText(onIkiGunSonra), '12 gün sonra');
      expect(UsernameChangePolicy.waitText(DateTime.now()), 'bugün');
      expect(UsernameChangePolicy.waitText(null), 'kısa süre sonra');
    });

    test('profil getter\'ları sayacı yansıtır', () {
      final kilitli = UserProfile(
        uid: 'u1',
        displayName: 'Ayşe',
        username: 'ayse_y',
        usernameChanges: 2,
        usernameWindowStart: simdi.subtract(const Duration(days: 5)),
      );
      expect(kilitli.kalanKullaniciAdiHakki, 0);
      expect(kilitli.kullaniciAdiKilitli, isTrue);
      expect(kilitli.yeniKullaniciAdiHakki, isNotNull);

      final acik = kilitli.copyWith(usernameChanges: 0);
      expect(acik.kalanKullaniciAdiHakki, UsernameChangePolicy.maxChanges);
      expect(acik.kullaniciAdiKilitli, isFalse);
    });
  });
}
