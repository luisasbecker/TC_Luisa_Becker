import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/core/services/analysis_transport.dart';
import 'package:pipeline_bucal/design_system/design_system.dart';
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';
import 'package:pipeline_bucal/features/analysis/analysis_screen.dart';
import 'package:pipeline_bucal/features/app/bucal_shell.dart';
import 'package:pipeline_bucal/features/demo/demo_scenarios.dart';
import 'package:pipeline_bucal/features/library/library_widgets.dart';
import 'package:pipeline_bucal/features/library/reference_library.dart';
import 'package:pipeline_bucal/ui/crop_editor.dart';

Uint8List _pixels(int width, int height) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

DemoTransport _demo({bool focus = true}) =>
    DemoTransport()
      ..scenario = DemoScenario('ui', 'UI fixture', '', focus: focus);

class _CloudFixture implements AnalysisTransport {
  _CloudFixture({required bool focus}) : delegate = _demo(focus: focus);
  final DemoTransport delegate;
  final operations = <String>[];

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    operations.add(operation);
    return {
      ...await delegate.call(operation, payload),
      'execution_mode': 'cloud',
    };
  }
}

Future<void> _mount(
  WidgetTester tester, {
  AnalysisController? controller,
  Size size = const Size(390, 844),
  ThemeMode theme = ThemeMode.light,
  double textScale = 1,
  bool reducedMotion = false,
  int initialTab = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: BucalTheme.light(),
      darkTheme: BucalTheme.dark(),
      themeMode: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: BucalShell(
        controller: controller,
        initialTab: initialTab,
        themeMode: theme,
        onThemeChanged: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final configuration in [
    (const Size(320, 568), 40, 100, ThemeMode.light, 1.0, false),
    (const Size(320, 568), 40, 100, ThemeMode.dark, 2.5, true),
    (const Size(390, 844), 120, 40, ThemeMode.dark, 2.0, false),
    (const Size(960, 1280), 80, 80, ThemeMode.light, 1.0, true),
  ]) {
    testWidgets('crop stays fixed with visible actions at ${configuration.$1}, '
        '${configuration.$2}x${configuration.$3}, text ${configuration.$5}', (
      tester,
    ) async {
      final flow = AnalysisController(
        mode: ExecutionMode.offline,
        offline: _demo(),
      );
      addTearDown(flow.dispose);
      await flow.selectImage(_pixels(configuration.$2, configuration.$3));
      await flow.confirmImage();
      flow.editCrop();
      await _mount(
        tester,
        controller: flow,
        size: configuration.$1,
        theme: configuration.$4,
        textScale: configuration.$5,
        reducedMotion: configuration.$6,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      final viewport = find.byKey(const ValueKey('crop-viewport'));
      final before = tester.getRect(viewport);
      final confirm = find.bySemanticsLabel('Confirmar novo recorte').first;
      final cancel = find.bySemanticsLabel('Cancelar ajuste').first;
      expect(confirm.hitTestable(), findsOneWidget);
      expect(cancel.hitTestable(), findsOneWidget);
      expect(tester.getRect(confirm).bottom, lessThan(configuration.$1.height));
      expect(tester.getRect(cancel).bottom, lessThan(configuration.$1.height));
      expect(tester.getSize(find.byType(CropEditor)).height, greaterThan(0));

      final oldTop = tester.widget<CropEditor>(find.byType(CropEditor)).box.top;
      final corner = find.bySemanticsLabel('Ajustar canto 1 do recorte');
      final gesture = await tester.startGesture(tester.getCenter(corner));
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(viewport), before);
      expect(
        tester.widget<CropEditor>(find.byType(CropEditor)).box.top,
        greaterThan(oldTop),
      );
      expect(find.byType(Scrollable), findsNothing);
      expect(confirm.hitTestable(), findsOneWidget);
      expect(cancel.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final adequate in [true, false]) {
    testWidgets('cloud focus suggestion $adequate preserves human decision', (
      tester,
    ) async {
      final cloud = _CloudFixture(focus: adequate);
      final flow = AnalysisController(cloud: cloud);
      addTearDown(flow.dispose);
      await flow.selectImage(_pixels(80, 40));
      await flow.confirmImage();
      await flow.confirmCrop();
      expect(flow.state.stage, AnalysisStage.quality);
      await _mount(tester, controller: flow);

      expect(
        find.text(
          'Sugestão simulada: foco ${adequate ? 'adequado' : 'inadequado'}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Avaliação de foco: retorno recebido da nuvem.'),
        findsOneWidget,
      );
      expect(cloud.operations, containsAllInOrder(['detect', 'focus']));
      expect(cloud.operations, isNot(contains('classify')));
      await tester.runAsync(() => ReferenceLibrary.load());
      await _tap(tester, 'A qualidade está adequada');
      expect(flow.state.stage, AnalysisStage.classification);
      expect(cloud.operations, contains('classify'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('normal new analysis returns from offline to cloud', (
    tester,
  ) async {
    final flow = AnalysisController(
      mode: ExecutionMode.offline,
      offline: _demo(),
    );
    flow.newAnalysis(executionOrigin: 'fixture:complete');
    final previous = flow.state.analysisId;
    addTearDown(flow.dispose);
    await _mount(tester, controller: flow, initialTab: 0);
    await _tap(tester, 'Nova análise');
    expect(flow.state.mode, ExecutionMode.cloud);
    expect(flow.executionOrigin, 'manual');
    expect(flow.state.analysisId, isNot(previous));
    expect(find.text('SIMULAÇÃO • CLOUD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal new analysis clears a selected demonstration scenario', (
    tester,
  ) async {
    await _mount(tester, initialTab: 0);
    await tester.tap(find.byTooltip('Sobre e configurações'));
    await tester.pumpAndSettle();
    await _tap(tester, 'Painel de demonstração');
    await _tap(tester, '01 · Percurso completo');
    final flow = tester
        .widget<AnalysisScreen>(find.byType(AnalysisScreen))
        .controller;
    expect(flow.state.mode, ExecutionMode.offline);
    expect(flow.executionOrigin, 'fixture:complete');
    expect(find.text('Cenário de demonstração fixo'), findsOneWidget);
    await tester.tap(find.text('Início'));
    await tester.pumpAndSettle();
    await _tap(tester, 'Nova análise');
    expect(flow.state.mode, ExecutionMode.cloud);
    expect(flow.executionOrigin, 'manual');
    expect(find.text('Cenário de demonstração fixo'), findsNothing);
    expect(find.text('SIMULAÇÃO • CLOUD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library acquisition preserves an explicit offline analysis', (
    tester,
  ) async {
    final library = await tester.runAsync(() => ReferenceLibrary.load());
    final flow = AnalysisController(
      mode: ExecutionMode.offline,
      offline: _demo(),
    );
    flow.newAnalysis(executionOrigin: 'fixture:complete');
    final id = flow.state.analysisId;
    addTearDown(flow.dispose);
    await _mount(tester, controller: flow, initialTab: 2);
    final browser = tester.widget<ReferenceBrowser>(
      find.byType(ReferenceBrowser),
    );
    await tester.runAsync(() async {
      final pending = Function.apply(browser.onUse, [library!.images.first]);
      if (pending is Future) await pending;
    });
    await tester.pumpAndSettle();
    expect(flow.state.stage, AnalysisStage.preview);
    expect(flow.state.analysisId, id);
    expect(flow.state.mode, ExecutionMode.offline);
    expect(flow.executionOrigin, 'fixture:complete');
    expect(flow.state.original?.referenceId, library!.images.first.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'library starts a normal cloud analysis without an explicit demo',
    (tester) async {
      final library = await tester.runAsync(() => ReferenceLibrary.load());
      final flow = AnalysisController(
        mode: ExecutionMode.offline,
        offline: _demo(),
      );
      addTearDown(flow.dispose);
      await _mount(tester, controller: flow, initialTab: 2);
      final browser = tester.widget<ReferenceBrowser>(
        find.byType(ReferenceBrowser),
      );
      await tester.runAsync(() async {
        final pending = Function.apply(browser.onUse, [library!.images.first]);
        if (pending is Future) await pending;
      });
      await tester.pumpAndSettle();
      expect(flow.state.stage, AnalysisStage.preview);
      expect(flow.state.mode, ExecutionMode.cloud);
      expect(flow.executionOrigin, 'manual');
      expect(flow.state.original?.referenceId, library!.images.first.id);
      expect(find.text('SIMULAÇÃO • CLOUD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
