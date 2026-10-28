import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firestore yazma deseni koruması.
///
/// Noktalı alan yolu (`'permissions.onlyModsPost'` gibi) yalnızca
/// `update()` çağrısında iç içe alan olarak yorumlanır. Aynı anahtar
/// `set(..., SetOptions(merge: true))` ile yazılırsa adı kelimenin tam
/// anlamıyla `permissions.onlyModsPost` olan yeni bir üst alan oluşur;
/// güvenlik kurallarındaki `affectedKeys().hasOnly(...)` denetimleri de
/// bu alanı tanımadığı için yazım `permission-denied` ile reddedilir.
///
/// Bu hata daha önce DM açılışı, kanal izinleri, moderatörlük, tepkiler,
/// "yazıyor…"/okundu bilgisi ve davetle katılma akışlarını topluca
/// bozmuştu; testlerin sahte repository kullanması yüzünden CI'da
/// yakalanamadı. Bu kaynak taraması aynı desenin geri gelmesini engeller.
void main() {
  final dottedKey = RegExp(r"'[A-Za-z][A-Za-z0-9]*\.");

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  group('Firestore yazma deseni koruması', () {
    test('set() çağrılarında noktalı alan yolu anahtarı kullanılmaz', () {
      final violations = <String>[];

      for (final file in dartFiles()) {
        final source = file.readAsStringSync();
        for (final call in _findCalls(source, 'set')) {
          if (dottedKey.hasMatch(call.text)) {
            violations.add('${file.path}:${call.line}');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Noktalı anahtarlar yalnızca update() ile kullanılmalı. '
            'Aykırı set() çağrıları: $violations',
      );
    });

    test('noktalı anahtar taşıyan map değişkeni set() ile yazılmaz', () {
      final violations = <String>[];
      final dottedAssignment = RegExp(r"(\w+)\[\s*'[A-Za-z][A-Za-z0-9]*\.");
      final mapDeclaration =
          RegExp(r'(?:final|var)\s+(\w+)\s*=\s*<String,\s*dynamic>\s*\{');
      final nextMethod =
          RegExp(r'\n  (?:Future|Stream|void|bool|String|int|static)\b');

      for (final file in dartFiles()) {
        final source = file.readAsStringSync();
        // (değişken adı, noktalı kullanımın dosya içindeki konumu)
        final dottedUses = <(String, int)>[];

        // `data['roles.$uid'] = ...` biçimindeki atamalar.
        for (final match in dottedAssignment.allMatches(source)) {
          dottedUses.add((match.group(1)!, match.start));
        }

        // Noktalı anahtar içeren map literal'iyle tanımlanan değişkenler.
        for (final match in mapDeclaration.allMatches(source)) {
          final openBrace = source.indexOf('{', match.start);
          final span = _balancedSpan(source, openBrace, '{', '}');
          if (span != null && dottedKey.hasMatch(span)) {
            dottedUses.add((match.group(1)!, match.start));
          }
        }

        for (final (name, index) in dottedUses) {
          // Arama penceresi: yalnızca bu kullanımın ait olduğu fonksiyon.
          // Aynı adlı değişken başka fonksiyonlarda yeniden tanımlanmış
          // olabilir; pencere bir sonraki yöntem tanımında ya da aynı
          // adın yeniden tanımında kesilir.
          final cap = index + 6000 > source.length
              ? source.length
              : index + 6000;
          var window = source.substring(index, cap);
          for (final boundary in <RegExp>[
            nextMethod,
            RegExp('(?:final|var)\\s+$name\\s*='),
          ]) {
            final hit = boundary.firstMatch(window.substring(1));
            if (hit != null) window = window.substring(0, hit.start + 1);
          }

          final writtenWithSet =
              RegExp('\\.set\\(\\s*$name\\b').hasMatch(window);
          if (writtenWithSet) {
            violations.add('${file.path}: "$name" set() ile yazılıyor');
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Noktalı anahtarlı map\'ler update() ile yazılmalı: '
            '$violations',
      );
    });
  });
}

class _CallSpan {
  const _CallSpan(this.text, this.line);

  final String text;
  final int line;
}

/// `.<method>( ... )` çağrılarının parantez dengeli tam metinlerini bulur.
List<_CallSpan> _findCalls(String source, String method) {
  final pattern = RegExp('\\.$method\\s*\\(');
  final calls = <_CallSpan>[];

  for (final match in pattern.allMatches(source)) {
    final openParen = source.indexOf('(', match.start);
    final span = _balancedSpan(source, openParen, '(', ')');
    if (span == null) continue;
    final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
    calls.add(_CallSpan(span, line));
  }

  return calls;
}

/// [openIndex]'teki açıcıdan başlayan dengeli bloğu döndürür.
///
/// String ve yorum içindeki parantez/süslü parantezler sayılmaz.
String? _balancedSpan(
  String source,
  int openIndex,
  String openChar,
  String closeChar,
) {
  if (openIndex < 0 || openIndex >= source.length) return null;

  var depth = 0;
  var inSingle = false;
  var inDouble = false;
  var inLineComment = false;
  var inBlockComment = false;
  var escaped = false;

  for (var i = openIndex; i < source.length; i++) {
    final char = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    if (inLineComment) {
      if (char == '\n') inLineComment = false;
      continue;
    }
    if (inBlockComment) {
      if (char == '*' && next == '/') {
        inBlockComment = false;
        i++;
      }
      continue;
    }
    if (inSingle || inDouble) {
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == '\\') {
        escaped = true;
        continue;
      }
      if (inSingle && char == "'") inSingle = false;
      if (inDouble && char == '"') inDouble = false;
      continue;
    }

    if (char == '/' && next == '/') {
      inLineComment = true;
      i++;
      continue;
    }
    if (char == '/' && next == '*') {
      inBlockComment = true;
      i++;
      continue;
    }
    if (char == "'") {
      inSingle = true;
      continue;
    }
    if (char == '"') {
      inDouble = true;
      continue;
    }

    if (char == openChar) depth++;
    if (char == closeChar) {
      depth--;
      if (depth == 0) return source.substring(openIndex, i + 1);
    }
  }

  return null;
}
