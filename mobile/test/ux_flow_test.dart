import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/design_system/design_system.dart';
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';
import 'package:pipeline_bucal/features/analysis/analysis_widgets.dart';
import 'package:pipeline_bucal/features/app/bucal_shell.dart';
import 'package:pipeline_bucal/features/demo/demo_scenarios.dart';
import 'package:pipeline_bucal/main.dart';
import 'package:pipeline_bucal/features/library/reference_library.dart';

Uint8List sampleImage() {
  final image = img.Image(width: 80, height: 40);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  img.fillRect(
    image,
    x1: 40,
    y1: 0,
    x2: 79,
    y2: 39,
    color: img.ColorRgb8(0, 0, 255),
  );
  return Uint8List.fromList(img.encodePng(image));
}

AnalysisController fixture({
  RiskLevel risk = RiskLevel.medium,
  bool detects = true,
}) {
  final transport = DemoTransport()
    ..scenario = DemoScenario(
      'widget-test',
      'Widget test',
      '',
      risk: risk,
      detects: detects,
      classIndex: 4,
    );
  return AnalysisController(
    mode: ExecutionMode.offline,
    offline: transport,
    executionOrigin: 'automated:widget_fixture',
  );
}

Future<void> mount(
  WidgetTester tester,
  AnalysisController controller, {
  ThemeMode mode = ThemeMode.light,
  double scale = 1,
  bool reducedMotion = false,
  double width = 390,
}) async {
  await tester.runAsync(() => ReferenceLibrary.load());
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      theme: BucalTheme.light(),
      darkTheme: BucalTheme.dark(),
      themeMode: mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reducedMotion,
        ),
        child: child!,
      ),
      home: BucalShell(
        controller: controller,
        initialTab: 1,
        themeMode: mode,
        onThemeChanged: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> answerForm(
  WidgetTester tester,
  AnalysisController controller,
) async {
  while (controller.state.stage == AnalysisStage.questionnaire) {
    final section =
        controller.state.questionnaire!.sections[controller.state.sectionIndex];
    for (var i = 0; i < section.questions.length; i++) {
      final finder = find.widgetWithText(BucalChoiceTile, 'Sim').at(i);
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    await tap(
      tester,
      controller.state.sectionIndex ==
              controller.state.questionnaire!.sections.length - 1
          ? 'Revisar respostas'
          : 'Próxima seção',
    );
  }
}

void main() {
  testWidgets('theme transition follows system reduced motion changes', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearAccessibilityFeaturesTestValue);
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
    final controller = fixture();
    addTearDown(controller.dispose);
    await tester.pumpWidget(PipelineApp(controller: controller));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      Duration.zero,
    );
    dispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: false,
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      const Duration(milliseconds: 220),
    );
  });

  for (final risk in RiskLevel.values) {
    testWidgets(
      'v2 visible flow reaches ${risk.name} and preserves unconfirmed class',
      (tester) async {
        final controller = fixture(risk: risk);
        addTearDown(controller.dispose);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await controller.selectImage(sampleImage());
        await mount(
          tester,
          controller,
          mode: risk == RiskLevel.high ? ThemeMode.dark : ThemeMode.light,
          reducedMotion: true,
          width: risk == RiskLevel.low ? 360 : 390,
        );
        await tap(tester, 'Usar esta imagem');
        expect(controller.state.stage, AnalysisStage.crop);
        await tap(tester, 'O recorte está adequado');
        await tap(tester, 'A qualidade está adequada');
        await tap(tester, 'Discordo da classificação');
        await tap(tester, 'Não consigo determinar');
        expect(controller.state.provisional, isTrue);
        expect(find.text('Classe não confirmada'), findsOneWidget);
        await answerForm(tester, controller);
        expect(controller.state.stage, AnalysisStage.review);
        await tap(tester, 'Confirmar e ver resultado');
        expect(controller.state.stage, AnalysisStage.result);
        expect(controller.state.result!.risk, risk);
        expect(find.text(riskTitles[risk.index]), findsOneWidget);
        expect(controller.state.result!.provisional, isTrue);
        expect(
          find.textContaining('não confirmada', findRichText: true),
          findsWidgets,
        );
        final copy = tester
            .widgetList<Text>(find.byType(Text))
            .map((widget) => widget.data ?? '')
            .join(' ');
        expect(copy, contains('avaliação médica'));
        expect(copy, isNot(contains('%')));
        await tap(tester, 'Concluir análise');
        expect(controller.state.stage, AnalysisStage.completed);
        expect(find.text('Exportar histórico JSON'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('manual crop gesture changes the image displayed at quality', (
    tester,
  ) async {
    final controller = fixture();
    addTearDown(controller.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await controller.selectImage(sampleImage());
    await controller.confirmImage();
    final originalHash = controller.state.original!.hash;
    final automaticHash = controller.state.activeImage!.hash;
    await mount(tester, controller);
    await tap(tester, 'Ajustar recorte manualmente');
    final corner = find.bySemanticsLabel('Ajustar canto 1 do recorte');
    await tester.ensureVisible(corner);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(corner));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(35, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tap(tester, 'Confirmar novo recorte');
    expect(controller.state.stage, AnalysisStage.quality);
    expect(controller.state.activeImage!.hash, isNot(originalHash));
    expect(controller.state.activeImage!.hash, isNot(automaticHash));
    final image = tester.widget<Image>(
      find.byKey(ValueKey('${controller.state.activeImage!.hash}:active')),
    );
    expect(
      (image.image as MemoryImage).bytes,
      orderedEquals(controller.state.activeImage!.bytes),
    );
    expect(find.byType(ClinicalImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation tabs retain the current analysis and selected image',
    (tester) async {
      final controller = fixture();
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await controller.selectImage(sampleImage());
      await mount(tester, controller);
      final id = controller.state.analysisId;
      final image = controller.state.original;
      await tester.tap(find.text('Biblioteca'));
      await tester.pumpAndSettle();
      expect(find.text('Referências para comparar.'), findsOneWidget);
      await tester.tap(find.text('Análise'));
      await tester.pumpAndSettle();
      expect(controller.state.analysisId, id);
      expect(controller.state.original, same(image));
      expect(controller.state.stage, AnalysisStage.preview);
      expect(find.text('Confira a imagem'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no detection offers manual crop and replacement without automatic advance',
    (tester) async {
      final controller = fixture(detects: false);
      addTearDown(controller.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await controller.selectImage(sampleImage());
      await controller.confirmImage();
      await mount(tester, controller);
      expect(find.text('Fazer recorte manual'), findsOneWidget);
      expect(find.text('Enviar outra fotografia'), findsOneWidget);
      expect(controller.state.activeImage, isNull);
      await tap(tester, 'Fazer recorte manual');
      await tap(tester, 'Confirmar novo recorte');
      expect(controller.state.stage, AnalysisStage.quality);
      expect(controller.state.activeImage, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'home supports ${mode.name}, large text, compact phone and reduced motion',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = fixture();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.6),
              disableAnimations: true,
            ),
            child: PipelineApp(controller: controller, initialThemeMode: mode),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Clareza em\ncada etapa.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, 'Nova análise');
        expect(find.text('Selecionar imagem'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
