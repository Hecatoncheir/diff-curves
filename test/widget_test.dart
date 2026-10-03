import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git_diff_curves_flutter_demo/main.dart';
import 'package:git_diff_curves_flutter_demo/diff_painter.dart';

void main() {
  testWidgets('Навигация, режим кривых, прокрутка и изменение окна', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const DiffApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('next')));
    await tester.pumpAndSettle();
    expect(find.text('Изменение 1 из 4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('previous')));
    await tester.pumpAndSettle();
    expect(find.text('Изменение 4 из 4'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('outline')));
    await tester.pumpAndSettle();
    var painter =
        tester
                .widget<CustomPaint>(find.byKey(const ValueKey('diff-canvas')))
                .painter!
            as DiffPainter;
    expect(painter.filled, isFalse);
    await tester.tap(find.byKey(const ValueKey('filled')));
    await tester.pumpAndSettle();
    painter =
        tester
                .widget<CustomPaint>(find.byKey(const ValueKey('diff-canvas')))
                .painter!
            as DiffPainter;
    expect(painter.filled, isTrue);
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Кадр реального Flutter-интерфейса', (tester) async {
    final output = Platform.environment['DIFF_PREVIEW_OUTPUT'];
    if (output == null) return;
    await tester.runAsync(() async {
      final mono = FontLoader('JetBrainsMono')
        ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf'));
      await mono.load();
      if (Platform.isWindows) {
        final uiFont = FontLoader('Segoe UI')
          ..addFont(
            File(r'C:\Windows\Fonts\segoeui.ttf')
                .readAsBytes()
                .then((bytes) => ByteData.sublistView(bytes)),
          );
        await uiFont.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    tester.view.physicalSize = const Size(1600, 1120);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key: key, child: const DiffApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
