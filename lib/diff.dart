import 'dart:math' as math;
import 'dart:typed_data';

enum ChangeKind { insertion, deletion, replacement }

class DiffHunk {
  const DiffHunk(this.oldStart, this.oldEnd, this.newStart, this.newEnd);
  final int oldStart, oldEnd, newStart, newEnd;
  ChangeKind get kind {
    if (oldStart == oldEnd) return ChangeKind.insertion;
    if (newStart == newEnd) return ChangeKind.deletion;
    return ChangeKind.replacement;
  }
}

class DiffDocument {
  const DiffDocument({
    required this.oldLines,
    required this.newLines,
    required this.hunks,
    this.oldName = 'old',
    this.newName = 'new',
    this.path = 'Сравнение файлов',
    this.firstLine = 1,
  });
  final List<String> oldLines, newLines;
  final List<DiffHunk> hunks;
  final String oldName, newName, path;
  final int firstLine;
  int get lineCount => math.max(oldLines.length, newLines.length);
}

class DiffRequest {
  const DiffRequest(this.oldText, this.newText, this.oldName, this.newName);
  final String oldText, newText, oldName, newName;
}

List<String> splitLines(String text) {
  if (text.isEmpty) return [];
  text = text.replaceAll('\r\n', '\n');
  if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
  return text.split('\n');
}

// Построчный LCS выполняется в отдельном изоляте при загрузке файлов.
DiffDocument compareDocuments(DiffRequest request) {
  final old = splitLines(request.oldText), newer = splitLines(request.newText);
  final width = newer.length + 1;
  if ((old.length + 1) * width > 8000000) {
    throw const FormatException(
      'Файлы слишком велики: лимит — 8 млн ячеек сравнения.',
    );
  }
  final table = Int32List((old.length + 1) * width);
  for (var i = old.length - 1; i >= 0; i--) {
    for (var j = newer.length - 1; j >= 0; j--) {
      table[i * width + j] = old[i] == newer[j]
          ? table[(i + 1) * width + j + 1] + 1
          : math.max(table[(i + 1) * width + j], table[i * width + j + 1]);
    }
  }
  final hunks = <DiffHunk>[];
  var i = 0, j = 0;
  while (i < old.length || j < newer.length) {
    if (i < old.length && j < newer.length && old[i] == newer[j]) {
      i++;
      j++;
      continue;
    }
    final startOld = i, startNew = j;
    while (i < old.length || j < newer.length) {
      if (i < old.length && j < newer.length && old[i] == newer[j]) break;
      if (j == newer.length ||
          (i < old.length &&
              table[(i + 1) * width + j] >= table[i * width + j + 1])) {
        i++;
      } else {
        j++;
      }
    }
    hunks.add(DiffHunk(startOld, i, startNew, j));
  }
  return DiffDocument(
    oldLines: old,
    newLines: newer,
    hunks: hunks,
    oldName: request.oldName,
    newName: request.newName,
    path: '${request.oldName} ↔ ${request.newName}',
  );
}

// Диапазоны примера повторяют расположение блоков исходного скриншота.
final demoDocument = DiffDocument(
  oldLines: splitLines(_old),
  newLines: splitLines(_new),
  firstLine: 48,
  oldName: 'jb/updates',
  newName: 'jb/feature (Local)',
  path: 'src/main/snapshotting/add.md',
  hunks: const [
    DiffHunk(3, 4, 3, 4),
    DiffHunk(9, 12, 9, 9),
    DiffHunk(17, 17, 14, 20),
    DiffHunk(20, 21, 23, 24),
  ],
);

const _old =
    '''Note that older versions of Git used to ignore removed files; use --all.
files but ignore removed ones.

For more details about the *<pathspec>* syntax, see the *pathspec* entry.

`-n`
`--dry-run`
Don't actually add the file(s), just show if they exist and/or will be ignored.

`-v`
`--verbose`
Be verbose.

`-f`
`--force`
Allow adding otherwise ignored files.

`-i`
`--interactive`
Add modified contents in the working tree interactively to the index.
Also note that optional path arguments may be supplied to limit the operation.
See “Interactive mode” for details.

`-p`
`--patch`
Interactively choose hunks of patch between the index and the working tree.
This gives the user a chance to review the difference before adding it.''';

const _new =
    '''Note that older versions of Git used to ignore removed files; use --all.
files but ignore removed ones.

For more details about the `<pathspec>` syntax, see the *pathspec* entry.

`-n`
`--dry-run`
Don't actually add the file(s), just show if they exist and/or will be ignored.


`-f`
`--force`
Allow adding otherwise ignored files.

`--sparse`
Allow updating index entries outside of the sparse-checkout cone.
Normally, `git add` refuses to update index entries whose paths do not fit.
files might be removed from the working tree without warning.
See git-sparse-checkout for more details.

`-i`
`--interactive`
Add modified contents in the working tree interactively to the index.
Path arguments may be supplied to limit operation to a subset of files.
See “Interactive mode” for details.

`-p`
`--patch`
Interactively choose hunks of patch between the index and the working tree.
This gives the user a chance to review the difference before adding it.''';
