import 'package:flutter/material.dart';

/// Convertit un texte contenant des **mots en gras** (format Markdown simple
/// envoyé par le backend Flask) en un Text.rich affichant le gras correctement.
class BoldText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const BoldText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4);
    final regex = RegExp(r'\*\*(.*?)\*\*');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}