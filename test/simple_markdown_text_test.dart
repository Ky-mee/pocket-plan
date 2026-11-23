import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_plan/widgets/simple_markdown_text.dart';

void main() {
  testWidgets('SimpleMarkdownText renders bold, italic, and bullets cleanly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleMarkdownText(
            data: '## Monthly Tip\n- Save **\$100** on *groceries*\n1. Track `bills`',
          ),
        ),
      ),
    );

    expect(find.textContaining('Monthly Tip', findRichText: true), findsOneWidget);
    expect(find.textContaining('Save \$100 on groceries', findRichText: true), findsOneWidget);
    expect(find.textContaining('Track bills', findRichText: true), findsOneWidget);
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });
}
