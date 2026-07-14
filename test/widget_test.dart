import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_account_book/main.dart';

void main() {
  testWidgets('App 启动渲染 smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // App 启动后应显示加载指示器或页面内容（数据库初始化中）
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
