import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sohbet/core/theme/app_theme.dart';
import 'package:sohbet/core/widgets/empty_state.dart';
import 'package:sohbet/core/widgets/user_avatar.dart';
import 'package:sohbet/features/chat/domain/models/chat_room.dart';

void main() {
  testWidgets('EmptyState başlık ve mesajı gösterir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: EmptyState(
            icon: Icons.forum_outlined,
            title: 'Henüz sohbet yok',
            message: 'İlk sohbeti başlat.',
          ),
        ),
      ),
    );

    expect(find.text('Henüz sohbet yok'), findsOneWidget);
    expect(find.text('İlk sohbeti başlat.'), findsOneWidget);
  });

  testWidgets('UserAvatar baş harfi gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: UserAvatar(name: 'ayşe'))),
      ),
    );

    expect(find.text('A'), findsOneWidget);
  });

  test('ChatRoom modeli varsayılan önizleme metnini üretir', () {
    const room = ChatRoom(
      id: 'r1',
      name: 'Genel',
      createdBy: 'u1',
      memberIds: ['u1'],
    );

    expect(room.preview, 'Henüz mesaj yok');
  });
}
