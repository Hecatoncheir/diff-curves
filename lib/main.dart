import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'diff.dart';
import 'diff_painter.dart';
import 'gruvbox.dart';

void main() => runApp(const DiffApp());

class DiffApp extends StatelessWidget {
  const DiffApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Git Diff · Gruvbox',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: Gruvbox.background,
      colorScheme: const ColorScheme.dark(
        primary: Gruvbox.yellow,
        surface: Gruvbox.surface,
        onSurface: Gruvbox.text,
      ),
      fontFamily: 'Segoe UI',
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(Gruvbox.border),
        thickness: WidgetStateProperty.all(7),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: Gruvbox.muted),
      ),
    ),
    home: const DiffScreen(),
  );
}

class DiffScreen extends StatefulWidget {
  const DiffScreen({super.key});
  @override
  State<DiffScreen> createState() => _DiffScreenState();
}

class _DiffScreenState extends State<DiffScreen> {
  final _scroll = ScrollController();
  DiffDocument _document = demoDocument;
  double _fontSize = 18, _horizontal = 0;
  int _selected = -1;
  bool _filled = true, _loading = false;
  double get _rowHeight => _fontSize * 1.95;
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _navigate(int delta) {
    if (_document.hunks.isEmpty) return;
    setState(() {
      if (_selected < 0) {
        _selected = delta > 0 ? 0 : _document.hunks.length - 1;
      } else {
        _selected = (_selected + delta) % _document.hunks.length;
      }
    });
    final h = _document.hunks[_selected];
    final target = math.max(
      0,
      math.min(h.oldStart, h.newStart) * _rowHeight - _rowHeight * 3,
    );
    _scroll.animateTo(
      target.toDouble().clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openFiles() async {
    const group = XTypeGroup(label: 'Текстовые файлы');
    try {
      final old = await openFile(
        confirmButtonText: 'Исходный файл',
        acceptedTypeGroups: [group],
      );
      if (old == null || !mounted) return;
      final newer = await openFile(
        confirmButtonText: 'Новая версия',
        acceptedTypeGroups: [group],
      );
      if (newer == null || !mounted) return;
      setState(() => _loading = true);
      final texts = await Future.wait([
        old.readAsString(),
        newer.readAsString(),
      ]);
      final document = await compute(
        compareDocuments,
        DiffRequest(texts[0], texts[1], old.name, newer.name),
      );
      if (!mounted) return;
      setState(() {
        _document = document;
        _selected = -1;
        _horizontal = 0;
      });
      _scroll.jumpTo(0);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сравнить файлы: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    setState(() {
      _document = demoDocument;
      _selected = -1;
      _horizontal = 0;
    });
    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.f7): () => _navigate(1),
      const SingleActivator(LogicalKeyboardKey.f7, shift: true): () =>
          _navigate(-1),
      const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
        if (!_loading) _openFiles();
      },
    },
    child: Focus(
      autofocus: true,
      child: Scaffold(
        body: Column(
          children: [
            _toolbar(),
            _branchHeader(),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentHeight = math.max(
                    constraints.maxHeight,
                    _document.lineCount * _rowHeight + 24,
                  );
                  return Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      child: RepaintBoundary(
                        child: SizedBox(
                          width: constraints.maxWidth,
                          height: contentHeight,
                          child: CustomPaint(
                            key: const ValueKey('diff-canvas'),
                            painter: DiffPainter(
                              document: _document,
                              rowHeight: _rowHeight,
                              fontSize: _fontSize,
                              horizontal: _horizontal,
                              selected: _selected,
                              filled: _filled,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            _footer(),
          ],
        ),
      ),
    ),
  );

  Widget _toolbar() => Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      color: Gruvbox.surface,
      border: Border(bottom: BorderSide(color: Gruvbox.border)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          IconButton(
            key: const ValueKey('previous'),
            tooltip: 'Предыдущее изменение · Shift+F7',
            onPressed: () => _navigate(-1),
            icon: const Icon(Icons.arrow_upward, size: 20),
          ),
          IconButton(
            key: const ValueKey('next'),
            tooltip: 'Следующее изменение · F7',
            onPressed: () => _navigate(1),
            icon: const Icon(Icons.arrow_downward, size: 20),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            height: 24,
            child: VerticalDivider(color: Gruvbox.border),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: _loading ? null : _openFiles,
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            label: Text(
              constraints.maxWidth < 700 ? 'Открыть' : 'Открыть два файла',
            ),
            style: TextButton.styleFrom(foregroundColor: Gruvbox.text),
          ),
          if (constraints.maxWidth >= 850) ...[
            const SizedBox(width: 16),
            Text(
              '1 файл',
              style: TextStyle(color: Gruvbox.muted.withValues(alpha: .8)),
            ),
          ],
          const Spacer(),
          Text(
            '${_document.hunks.length} изменения',
            style: const TextStyle(color: Gruvbox.text, fontSize: 14),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: Gruvbox.background,
              border: Border.all(color: Gruvbox.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('filled'),
                  tooltip: 'Заполненные переходы',
                  onPressed: () => setState(() => _filled = true),
                  icon: Icon(
                    Icons.view_column_outlined,
                    size: 21,
                    color: _filled ? Gruvbox.yellow : Gruvbox.muted,
                  ),
                ),
                IconButton(
                  key: const ValueKey('outline'),
                  tooltip: 'Только контуры',
                  onPressed: () => setState(() => _filled = false),
                  icon: Icon(
                    Icons.show_chart,
                    size: 21,
                    color: !_filled ? Gruvbox.yellow : Gruvbox.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PopupMenuButton<String>(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined, size: 21),
            onSelected: (value) {
              if (value == 'demo') {
                _reset();
                return;
              }
              setState(
                () => _fontSize = (_fontSize + (value == 'larger' ? 2 : -2))
                    .clamp(12, 26),
              );
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'larger', child: Text('Увеличить шрифт')),
              PopupMenuItem(value: 'smaller', child: Text('Уменьшить шрифт')),
              PopupMenuItem(value: 'demo', child: Text('Исходный пример')),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _branchHeader() => Container(
    height: 46,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Gruvbox.border)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: Gruvbox.muted),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _document.oldName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Gruvbox.text, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _document.path,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Gruvbox.muted, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: DiffPainter.gutterWidth),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _document.newName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Gruvbox.text, fontSize: 15),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _footer() => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      color: Gruvbox.surface,
      border: Border(top: BorderSide(color: Gruvbox.border)),
    ),
    child: Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Gruvbox.green,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'Gruvbox Dark',
          style: TextStyle(color: Gruvbox.muted, fontSize: 11),
        ),
        const SizedBox(width: 18),
        Text(
          _selected < 0
              ? 'Изменение не выбрано'
              : 'Изменение ${_selected + 1} из ${_document.hunks.length}',
          style: const TextStyle(color: Gruvbox.muted, fontSize: 11),
        ),
        const Spacer(),
        const Icon(Icons.swap_horiz, size: 16, color: Gruvbox.muted),
        SizedBox(
          width: 160,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: _horizontal,
              min: 0,
              max: 1600,
              onChanged: (value) => setState(() => _horizontal = value),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'UTF-8',
          style: TextStyle(color: Gruvbox.muted, fontSize: 11),
        ),
      ],
    ),
  );
}
