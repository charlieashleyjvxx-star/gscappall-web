import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gscappall/app/app_providers.dart';
import 'package:gscappall/data/local/app_database.dart';
import 'package:gscappall/features/game/game_page.dart';

void main() {
  testWidgets('practice page keeps focused practice entries', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: GamePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天练哪一步？'), findsNothing);
    expect(find.text('今日热身'), findsNothing);
    expect(find.text('朗读'), findsNothing);
    expect(find.text('背诵'), findsNothing);
    expect(find.text('听写'), findsNothing);
    expect(find.text('听写模块'), findsOneWidget);
    expect(find.text('同音接龙'), findsOneWidget);
    expect(find.text('飞花初试'), findsOneWidget);
    expect(find.text('逐句默写，错了就进错题本。'), findsOneWidget);
    expect(find.text('根据诗句首字或同音继续接龙。'), findsOneWidget);
    expect(find.text('围绕主题字说出对应诗句。'), findsOneWidget);
    expect(find.text('小测验'), findsNothing);
    expect(find.text('更多挑战'), findsNothing);
    expect(find.text('接龙入门'), findsNothing);
    expect(find.text('主题飞花'), findsNothing);
    expect(find.text('限时飞花'), findsNothing);
    expect(find.text('错字复盘'), findsNothing);
  });
}
