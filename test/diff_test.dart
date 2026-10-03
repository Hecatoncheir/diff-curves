import 'package:flutter_test/flutter_test.dart';
import 'package:git_diff_curves_flutter_demo/diff.dart';

List<List<int>> ranges(DiffDocument d) =>
    d.hunks.map((h) => [h.oldStart, h.oldEnd, h.newStart, h.newEnd]).toList();

void main() {
  test('Вставки, удаления, замены и пустые файлы', () {
    final cases = [
      ('a\nb', 'a\nb', <List<int>>[]),
      (
        'a\nb',
        'a\nx\nb',
        [
          [1, 1, 1, 2],
        ],
      ),
      (
        'a\nx\nb',
        'a\nb',
        [
          [1, 2, 1, 1],
        ],
      ),
      (
        'a\nx\nb',
        'a\ny\nz\nb',
        [
          [1, 2, 1, 3],
        ],
      ),
      (
        '',
        'a',
        [
          [0, 0, 0, 1],
        ],
      ),
      (
        'a',
        '',
        [
          [0, 1, 0, 0],
        ],
      ),
      (
        'a\nx\nb\ny',
        'a\nb\nz',
        [
          [1, 2, 1, 1],
          [3, 4, 2, 3],
        ],
      ),
    ];
    for (final c in cases) {
      expect(
        ranges(compareDocuments(DiffRequest(c.$1, c.$2, 'old', 'new'))),
        c.$3,
      );
    }
  });
  test('Диапазоны встроенного примера воспроизводят новую версию', () {
    final output = <String>[];
    var cursor = 0;
    for (final h in demoDocument.hunks) {
      output.addAll(demoDocument.oldLines.sublist(cursor, h.oldStart));
      output.addAll(demoDocument.newLines.sublist(h.newStart, h.newEnd));
      cursor = h.oldEnd;
    }
    output.addAll(demoDocument.oldLines.sublist(cursor));
    expect(output, demoDocument.newLines);
  });
  test('Нормализация CRLF и ограничение размера', () {
    expect(splitLines('a\r\nb\r\n'), ['a', 'b']);
    final large = List.filled(3000, 'a').join('\n');
    expect(
      () => compareDocuments(DiffRequest(large, large, 'old', 'new')),
      throwsFormatException,
    );
  });
}
