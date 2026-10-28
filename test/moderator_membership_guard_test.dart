import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Yalnızca kanal üyeleri moderatör olabilir" kuralının üç katmanı:
///
///  1. UI — moderatör seçimi global kullanıcı aramasıyla değil, oda
///     üyelerinden oluşan listeden yapılır ve seçim sırasında kişi
///     otomatik üye yapılmaz (`addMember` çağrısı yok).
///  2. Repository — `setModerator(moderator: true)` hedef üye değilse
///     `ChatException` fırlatır.
///  3. Kurallar — `roles` haritasına eklenen/değişen anahtarlar
///     `memberIds` içinde olmak zorunda.
///
/// Davranışın gerilemesine karşı kaynak koruması (fake repository
/// kullanan widget testleri gerçek Firestore/kural katmanını görmez).
void main() {
  String read(String path) => File(path).readAsStringSync();

  /// `marker` sonrasındaki `length` karakterlik pencere.
  String window(String source, String marker, {int length = 4000}) {
    final start = source.indexOf(marker);
    expect(start, isNonNegative, reason: '"$marker" kaynakta bulunmalı');
    final end = start + length > source.length ? source.length : start + length;
    return source.substring(start, end);
  }

  group('Moderatör üyelik şartı', () {
    const settingsPath =
        'lib/features/chat/presentation/room_settings_screen.dart';
    const repoPath = 'lib/features/chat/data/chat_repository.dart';
    const rulesPath = 'firestore.rules';

    test('arayüz moderatörü üye listesinden seçer, global arama yok', () {
      final source = read(settingsPath);
      expect(source, contains('_MemberPickerSheet'));
      // Moderatör akışında sürpriz üyelik ekleme olmamalı.
      final flow = window(source, 'Future<void> _addModerator', length: 2600);
      expect(
        flow,
        isNot(contains('addMember')),
        reason:
            'Moderatör eklerken kanal dışından kişi otomatik üye yapılmamalı.',
      );
      expect(flow, contains('room.memberIds'));
    });

    test('repository üye olmayana moderatörlüğü reddeder', () {
      final source = read(repoPath);
      final body = window(source, 'Future<void> setModerator', length: 1600);
      expect(body, contains('_fetchRoomState'));
      expect(body, contains('state.memberIds.contains(uid)'));
      expect(body, contains('ChatException'));
    });

    test('kurallar rol anahtarlarını üye listesiyle sınırlar', () {
      final rules = read(rulesPath);
      expect(rules, contains('.addedKeys()'));
      expect(rules, contains('.changedKeys()'));
      expect(
        rules,
        contains('.hasOnly(request.resource.data.memberIds)'),
      );
    });
  });
}
