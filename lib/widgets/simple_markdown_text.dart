import 'package:flutter/material.dart';

/// Lightweight Markdown renderer for AI Advisor responses.
/// Supports `#`/`##`/`###` headings, `-`/`*`/`•`/numbered lists, and
/// inline `**bold**`, `*italic*`, and `` `code` `` spans.
class SimpleMarkdownText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final Color? accentColor;
  final Color? codeBackgroundColor;

  const SimpleMarkdownText({
    super.key,
    required this.data,
    this.style,
    this.accentColor,
    this.codeBackgroundColor,
  });

  static final RegExp _numberedPattern = RegExp(r'^(\d+\.)\s+(.*)$');

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ??
        DefaultTextStyle.of(context).style.copyWith(fontSize: 14, height: 1.5);
    final lines = data.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trimRight();
      if (line.trim().isEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 6));
        }
        continue;
      }

      if (line.startsWith('### ') ||
          line.startsWith('## ') ||
          line.startsWith('# ')) {
        final content = line.replaceFirst(RegExp(r'^#{1,3}\s+'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text.rich(
              TextSpan(children: _parseInline(content, baseStyle)),
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w700,
                color: accentColor ?? baseStyle.color,
              ),
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('- ') ||
          line.startsWith('* ') ||
          line.startsWith('• ')) {
        final content = line.substring(2).trimLeft();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accentColor ?? baseStyle.color,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _parseInline(content, baseStyle)),
                    style: baseStyle,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final numMatch = _numberedPattern.firstMatch(line);
      if (numMatch != null) {
        final marker = numMatch.group(1)!;
        final content = numMatch.group(2)!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$marker ',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accentColor ?? baseStyle.color,
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: _parseInline(content, baseStyle)),
                    style: baseStyle,
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      widgets.add(
        Text.rich(
          TextSpan(children: _parseInline(line, baseStyle)),
          style: baseStyle,
        ),
      );
    }

    if (widgets.isEmpty) {
      return Text(data, style: baseStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  List<InlineSpan> _parseInline(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final tokenPattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`|\*(.+?)\*');
    int lastEnd = 0;

    for (final match in tokenPattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor:
                  codeBackgroundColor ??
                  (baseStyle.color ?? Colors.grey).withValues(alpha: 0.12),
            ),
          ),
        );
      } else if (match.group(3) != null) {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return spans;
  }
}
