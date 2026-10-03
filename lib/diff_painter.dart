import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'diff.dart';
import 'gruvbox.dart';

class DiffPainter extends CustomPainter {
  DiffPainter({
    required this.document,
    required this.rowHeight,
    required this.fontSize,
    required this.horizontal,
    required this.selected,
    required this.filled,
  });
  static const gutterWidth = 156.0;
  final DiffDocument document;
  final double rowHeight, fontSize, horizontal;
  final int selected;
  final bool filled;

  Color _accent(DiffHunk h) => switch (h.kind) {
    ChangeKind.insertion => Gruvbox.green,
    ChangeKind.deletion => Gruvbox.red,
    ChangeKind.replacement => Gruvbox.blue,
  };
  Color _background(DiffHunk h) => switch (h.kind) {
    ChangeKind.insertion => const Color(0xff3c432c),
    ChangeKind.deletion => const Color(0xff493833),
    ChangeKind.replacement => const Color(0xff354641),
  };

  Path _ribbon(DiffHunk h, double left, double right) {
    final oldTop = h.oldStart * rowHeight, oldBottom = h.oldEnd * rowHeight;
    final newTop = h.newStart * rowHeight, newBottom = h.newEnd * rowHeight;
    final control = (right - left) * .62;
    return Path()
      ..moveTo(left, oldTop)
      ..cubicTo(left + control, oldTop, right - control, newTop, right, newTop)
      ..lineTo(right, newBottom)
      ..cubicTo(
        right - control,
        newBottom,
        left + control,
        oldBottom,
        left,
        oldBottom,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final left = (size.width - gutterWidth) / 2, right = left + gutterWidth;
    canvas.drawRect(Offset.zero & size, Paint()..color = Gruvbox.background);
    canvas.drawRect(
      Rect.fromLTWH(left, 0, gutterWidth, size.height),
      Paint()..color = const Color(0xff2b2b29),
    );
    for (var i = 0; i < document.hunks.length; i++) {
      final h = document.hunks[i];
      final paint = Paint()..color = _background(h);
      canvas.drawRect(
        Rect.fromLTRB(0, h.oldStart * rowHeight, left, h.oldEnd * rowHeight),
        paint,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          right,
          h.newStart * rowHeight,
          size.width,
          h.newEnd * rowHeight,
        ),
        paint,
      );
      final path = _ribbon(h, left, right);
      if (filled) canvas.drawPath(path, paint);
      if (!filled || selected == i) {
        canvas.drawPath(
          path,
          Paint()
            ..color = _accent(h).withValues(alpha: selected == i ? .7 : .4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected == i ? 1.5 : 1,
        );
      }
      _changeMarker(
        canvas,
        Offset(left + 12, h.oldStart * rowHeight + rowHeight / 2),
        _accent(h),
      );
    }
    final border = Paint()
      ..color = Gruvbox.border.withValues(alpha: .4)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, 0), Offset(left, size.height), border);
    canvas.drawLine(Offset(right, 0), Offset(right, size.height), border);
    _code(
      canvas,
      document.oldLines,
      Rect.fromLTWH(0, 0, left, size.height),
      true,
    );
    _code(
      canvas,
      document.newLines,
      Rect.fromLTWH(right, 0, left, size.height),
      false,
    );
    _numbers(canvas, document.oldLines.length, left + 24);
    _numbers(canvas, document.newLines.length, right - 56);
    _overview(canvas, size);
  }

  void _code(Canvas canvas, List<String> lines, Rect clip, bool old) {
    canvas.save();
    canvas.clipRect(clip);
    for (var row = 0; row < lines.length; row++) {
      final line = lines[row].replaceAll('\t', '    ');
      final highlighted = document.hunks.any(
        (h) =>
            h.kind == ChangeKind.replacement &&
            row >= (old ? h.oldStart : h.newStart) &&
            row < (old ? h.oldEnd : h.newEnd),
      );
      final spans = <TextSpan>[];
      final tokens = RegExp(r'`[^`]*`|\*[^*]*\*|<[^>]*>').allMatches(line);
      var start = 0;
      for (final match in tokens) {
        spans.add(TextSpan(text: line.substring(start, match.start)));
        spans.add(
          TextSpan(
            text: match.group(0),
            style: TextStyle(
              color: Gruvbox.green,
              backgroundColor: highlighted
                  ? Gruvbox.blue.withValues(alpha: .16)
                  : null,
            ),
          ),
        );
        start = match.end;
      }
      spans.add(TextSpan(text: line.substring(start)));
      final text = TextPainter(
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: fontSize,
            color: Gruvbox.text,
            height: 1,
          ),
          children: spans,
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      text.paint(
        canvas,
        Offset(
          clip.left + (old ? 24 : 8) - horizontal,
          row * rowHeight + (rowHeight - text.height) / 2,
        ),
      );
      text.dispose();
    }
    canvas.restore();
  }

  void _numbers(Canvas canvas, int count, double x) {
    for (var row = 0; row < count; row++) {
      final text = TextPainter(
        text: TextSpan(
          text: '${row + document.firstLine}',
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: fontSize - 1,
            color: Gruvbox.muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          x + 36 - text.width,
          row * rowHeight + (rowHeight - text.height) / 2,
        ),
      );
      text.dispose();
    }
  }

  void _changeMarker(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color.withValues(alpha: .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final shift in [0.0, 5.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - 3 + shift, center.dy - 4)
          ..lineTo(center.dx + 1 + shift, center.dy)
          ..lineTo(center.dx - 3 + shift, center.dy + 4),
        paint,
      );
    }
  }

  void _overview(Canvas canvas, Size size) {
    for (final h in document.hunks) {
      final paint = Paint()..color = _accent(h).withValues(alpha: .45);
      if (h.oldStart < h.oldEnd) {
        canvas.drawRect(
          Rect.fromLTWH(
            2,
            h.oldStart * rowHeight,
            3,
            math.max(4, (h.oldEnd - h.oldStart) * rowHeight),
          ),
          paint,
        );
      }
      if (h.newStart < h.newEnd) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width - 4,
            h.newStart * rowHeight,
            3,
            math.max(4, (h.newEnd - h.newStart) * rowHeight),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DiffPainter oldDelegate) =>
      oldDelegate.document != document ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.fontSize != fontSize ||
      oldDelegate.horizontal != horizontal ||
      oldDelegate.selected != selected ||
      oldDelegate.filled != filled;
}
