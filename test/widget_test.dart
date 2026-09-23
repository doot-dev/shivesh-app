import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shivesh_app/main.dart';

void main() {
  testWidgets('app boots into the router', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: ClientApp()));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
