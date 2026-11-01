import 'dart:typed_data';
import 'dart:ui' show SemanticsAction, SemanticsActionEvent;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/design_system/design_system.dart';
import 'package:pipeline_bucal/domain/pipeline.dart';
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';
import 'package:pipeline_bucal/features/analysis/analysis_widgets.dart';
import 'package:pipeline_bucal/ui/crop_editor.dart';

Uint8List pixels(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

Widget testApp(Widget child, {double scale = 1}) => MaterialApp(
  theme: BucalTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: child),
);

void screen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AnalysisImage photo(int width, int height, {String id = 'fixture'}) =>
    AnalysisImage(
      id: id,
      photo: PreparedPhoto(pixels(width, height), width, height),
    );

void main() {
  testWidgets('rapid corner updates accumulate before the next frame', (
    tester,
  ) async {
    var selection = const CropBox(.2, .2, .8, .8);
    final bytes = pixels(400, 200);
    await tester.pumpWidget(
      testApp(
        Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: StatefulBuilder(
              builder: (context, setState) => CropEditor(
                bytes: bytes,
                ratio: 2,
                box: selection,
                onChanged: (box) => setState(() => selection = box),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Ajustar canto 1 do recorte')),
    );
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveBy(const Offset(16, 0));
    await gesture.moveBy(const Offset(20, 0));
    await gesture.up();
    await tester.pump();
    expect(selection.left, closeTo(.35, .00001));
    expect(selection.top, .2);
    expect(selection.right, .8);
    expect(selection.bottom, .8);
  });

  testWidgets(
    'vertical center drag moves selection and preserves its size at the boundary',
    (tester) async {
      var selection = const CropBox(.2, .2, .8, .8);
      await tester.pumpWidget(
        testApp(
          Center(
            child: SizedBox(
              width: 400,
              height: 200,
              child: CropEditor(
                bytes: pixels(400, 200),
                ratio: 2,
                box: selection,
                onChanged: (box) => selection = box,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(CropEditor));
      await tester.drag(
        find.bySemanticsLabel('Área selecionada. Arraste para mover.'),
        const Offset(0, 150),
      );
      await tester.pump();
      expect(selection.valid, isTrue);
      expect(selection.top, closeTo(.4, .00001));
      expect(selection.bottom, 1);
      expect(selection.right - selection.left, closeTo(.6, .00001));
      expect(tester.getRect(find.byType(CropEditor)), before);
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(800, 1280),
  ]) {
    for (final imageSize in [
      const Size(60, 300),
      const Size(300, 60),
      const Size(120, 120),
    ]) {
      testWidgets(
        'crop fits $imageSize in $size with large text and no page scrolling',
        (tester) async {
          screen(tester, size);
          await tester.pumpWidget(
            testApp(
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ImageCropPanel(
                    image: photo(
                      imageSize.width.toInt(),
                      imageSize.height.toInt(),
                    ),
                    initialBox: const CropBox(.1, .1, .9, .9),
                    onConfirm: (_) {},
                    onCancel: () {},
                  ),
                ),
              ),
              scale: 2.5,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(Scrollable), findsNothing);
          final viewport = tester.getRect(
            find.byKey(const ValueKey('crop-viewport')),
          );
          final image = tester.getRect(find.byType(CropEditor));
          expect(viewport.contains(image.topLeft), isTrue);
          expect(viewport.contains(image.bottomRight), isTrue);
          expect(
            image.width / image.height,
            closeTo(imageSize.width / imageSize.height, .0001),
          );
          expect(image.height, greaterThan(0));
          expect(
            find.bySemanticsLabel('Confirmar novo recorte').hitTestable(),
            findsOneWidget,
          );
          expect(
            find.bySemanticsLabel('Cancelar ajuste').hitTestable(),
            findsOneWidget,
          );
        },
      );
    }
  }

  testWidgets('zoomed editing uses image coordinates and busy disables zoom', (
    tester,
  ) async {
    screen(tester, const Size(390, 844));
    var busy = false;
    CropBox? confirmed;
    late StateSetter refresh;
    final image = photo(120, 120);
    await tester.pumpWidget(
      testApp(
        StatefulBuilder(
          builder: (context, setState) {
            refresh = setState;
            return ImageCropPanel(
              image: image,
              initialBox: const CropBox(.1, .1, .4, .4),
              busy: busy,
              onConfirm: (value) => confirmed = value,
              onCancel: () {},
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ampliar imagem'));
    await tester.pump();
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    final transform = viewer.transformationController!;
    transform.value = Matrix4.diagonal3Values(2, 2, 1);
    await tester.pump();
    refresh(() => busy = true);
    await tester.pump();
    final before = Matrix4.copy(transform.value);
    await tester.drag(
      find.byType(InteractiveViewer),
      const Offset(30, 40),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(transform.value, before);
    refresh(() => busy = false);
    await tester.pump();
    await tester.tap(find.byTooltip('Voltar a ajustar o recorte'));
    await tester.pump();
    final imageWidth = tester.getSize(find.byType(CropEditor)).width;
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Ajustar canto 1 do recorte')),
    );
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveBy(const Offset(16, 0));
    await gesture.up();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Confirmar novo recorte'));
    expect(confirmed!.left, closeTo(.1 + 40 / (2 * imageWidth), .00001));
    expect(confirmed!.top, .1);
  });

  testWidgets(
    'zoomed portrait corner remains draggable outside the fitted image bounds',
    (tester) async {
      screen(tester, const Size(390, 844));
      CropBox? confirmed;
      await tester.pumpWidget(
        testApp(
          ImageCropPanel(
            image: photo(100, 300),
            initialBox: const CropBox(.2, .4, .8, .6),
            onConfirm: (value) => confirmed = value,
            onCancel: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final originalRect = tester.getRect(find.byType(CropEditor));
      final imageWidth = originalRect.width;
      final viewport = tester.getRect(
        find.byKey(const ValueKey('crop-viewport')),
      );
      await tester.tap(find.byTooltip('Ampliar imagem'));
      await tester.pump();
      final viewerSize = tester.getSize(find.byType(InteractiveViewer));
      final transform = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      transform.value = Matrix4.diagonal3Values(2, 2, 1)
        ..setTranslationRaw(-viewerSize.width / 2, -viewerSize.height / 2, 0);
      await tester.pump();
      await tester.tap(find.byTooltip('Voltar a ajustar o recorte'));
      await tester.pump();
      final handle = find.bySemanticsLabel('Ajustar canto 2 do recorte');
      final handleCenter = tester.getCenter(handle);
      expect(originalRect.contains(handleCenter), isFalse);
      expect(viewport.contains(handleCenter), isTrue);
      final gesture = await tester.startGesture(handleCenter);
      await gesture.moveBy(const Offset(-24, 0));
      await gesture.moveBy(const Offset(-16, 0));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Confirmar novo recorte'));
      expect(confirmed!.right, closeTo(.8 - 40 / (2 * imageWidth), .00001));
    },
  );

  testWidgets(
    'compact action semantics invoke callbacks once and disable while busy',
    (tester) async {
      screen(tester, const Size(320, 568));
      final semantics = tester.ensureSemantics();
      var confirmed = 0, cancelled = 0;
      var busy = false;
      late StateSetter refresh;
      final image = photo(100, 100);
      await tester.pumpWidget(
        testApp(
          StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return ImageCropPanel(
                image: image,
                initialBox: const CropBox(.1, .1, .9, .9),
                busy: busy,
                onConfirm: (_) => confirmed++,
                onCancel: () => cancelled++,
              );
            },
          ),
          scale: 2.5,
        ),
      );
      await tester.pumpAndSettle();
      final confirmNode = tester.getSemantics(
        find.bySemanticsLabel('Confirmar novo recorte'),
      );
      final cancelNode = tester.getSemantics(
        find.bySemanticsLabel('Cancelar ajuste'),
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          nodeId: confirmNode.id,
          viewId: tester.view.viewId,
          type: SemanticsAction.tap,
        ),
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          nodeId: cancelNode.id,
          viewId: tester.view.viewId,
          type: SemanticsAction.tap,
        ),
      );
      await tester.pump();
      expect(confirmed, 1);
      expect(cancelled, 1);
      refresh(() => busy = true);
      await tester.pump();
      final busyConfirm = tester.getSemantics(
        find.bySemanticsLabel('Verificando foco…'),
      );
      final busyCancel = tester.getSemantics(
        find.bySemanticsLabel('Cancelar ajuste'),
      );
      expect(
        busyConfirm.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      expect(
        busyCancel.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          nodeId: busyConfirm.id,
          viewId: tester.view.viewId,
          type: SemanticsAction.tap,
        ),
      );
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          nodeId: busyCancel.id,
          viewId: tester.view.viewId,
          type: SemanticsAction.tap,
        ),
      );
      await tester.pump();
      expect(confirmed, 1);
      expect(cancelled, 1);
      semantics.dispose();
    },
  );

  testWidgets(
    'new image resets crop and accessible adjustments remain available',
    (tester) async {
      screen(tester, const Size(320, 568));
      var image = photo(100, 100);
      CropBox? confirmed;
      late StateSetter refresh;
      await tester.pumpWidget(
        testApp(
          StatefulBuilder(
            builder: (context, setState) {
              refresh = setState;
              return ImageCropPanel(
                image: image,
                initialBox: const CropBox(.2, .2, .8, .8),
                onConfirm: (value) => confirmed = value,
                onCancel: () {},
              );
            },
          ),
          scale: 2.5,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Imagem inteira'));
      await tester.pump();
      refresh(() => image = photo(50, 100, id: 'replacement'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajustes acessíveis'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Alargar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alargar'));
      await tester.ensureVisible(find.byTooltip('Fechar ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fechar ajustes'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Confirmar novo recorte'));
      expect(confirmed!.left, closeTo(.175, .00001));
      expect(confirmed!.right, closeTo(.825, .00001));
    },
  );
}
