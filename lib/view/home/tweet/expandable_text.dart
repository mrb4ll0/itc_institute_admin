import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final bool isDark;
  final int trimLines;
  final Function(String)? onMentionTap;

  const ExpandableText({
    Key? key,
    required this.text,
    this.isDark = false,
    this.trimLines = 3,
    this.onMentionTap,
  }) : super(key: key);

  @override
  _ExpandableTextState createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 15,
      height: 1.4,
      color: widget.isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
    );

    final textSpan = _buildTextSpan(style);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: widget.trimLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        if (textPainter.didExceedMaxLines && !_isExpanded) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: textSpan,
                maxLines: widget.trimLines,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => setState(() => _isExpanded = true),
                child: Text(
                  'Show More',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        } else {
          return RichText(text: textSpan);
        }
      },
    );
  }

  TextSpan _buildTextSpan(TextStyle style) {
    final List<TextSpan> children = [];
    final RegExp regex = RegExp(r'@[a-zA-Z0-9_]+');

    widget.text.splitMapJoin(
      regex,
      onMatch: (Match match) {
        final mention = match[0]!;
        children.add(
          TextSpan(
            text: mention,
            style: style.copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.w600,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (widget.onMentionTap != null) {
                  // Remove the '@' before passing to the callback
                  widget.onMentionTap!(mention.substring(1));
                }
              },
          ),
        );
        return ''; // Return empty string as we've handled the match
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return ''; // Return empty string as we've handled the non-match
      },
    );

    return TextSpan(children: children);
  }
}
