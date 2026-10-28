import 'package:flutter_test/flutter_test.dart';
import 'package:sohbet/features/chat/domain/models/room_invite.dart';

// Davet bağlantısı çözümleme testleri.
//
// Derin bağlantı (`rebelzmedia://katil/KOD`) GoRouter'da rota olarak
// bulunamadığı için ("no routes for location") önce koda çevrilir; bu
// testler o çevirinin bozulmadığını garanti eder.
void main() {
  group('inviteCodeFromUri', () {
    test('özel şemadan kodu çıkarır', () {
      expect(
        inviteCodeFromUri(Uri.parse('rebelzmedia://katil/VXEQD79E')),
        'VXEQD79E',
      );
    });

    test('https davet sayfasından kodu çıkarır', () {
      expect(
        inviteCodeFromUri(
          Uri.parse('https://rebelz-media.web.app/katil/?k=9H2RC4AQ'),
        ),
        '9H2RC4AQ',
      );
      expect(
        inviteCodeFromUri(Uri.parse('https://rebelz-media.web.app/katil/9H2RC4AQ')),
        '9H2RC4AQ',
      );
    });

    test('davet olmayan adreste null döner', () {
      expect(inviteCodeFromUri(Uri.parse('/chats/abc')), isNull);
      expect(inviteCodeFromUri(Uri.parse('https://ornek.com/hakkinda')), isNull);
    });
  });

  group('inviteRouteFromLocation', () {
    test('özel şemayı otomatik katılma rotasına çevirir', () {
      expect(
        inviteRouteFromLocation('rebelzmedia://katil/VXEQD79E'),
        '/katil/VXEQD79E?auto=1',
      );
    });

    test('tanınmayan adreste null döner', () {
      expect(inviteRouteFromLocation('/chats/abc'), isNull);
    });
  });

  group('normalizeInviteCode', () {
    test('elle girilen kodu büyük harfe çevirir', () {
      expect(normalizeInviteCode('  vxeqd79e '), 'VXEQD79E');
    });

    test('bağlantıdan kodu ayıklar', () {
      expect(
        normalizeInviteCode('rebelzmedia://katil/VXEQD79E'),
        'VXEQD79E',
      );
    });
  });
}
