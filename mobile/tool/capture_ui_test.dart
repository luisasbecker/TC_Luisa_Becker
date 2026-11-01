// Reproducible rendered Flutter evidence; run explicitly with --update-goldens.
// These images are simulated test fixtures, never observations of real users.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipeline_bucal/design_system/design_system.dart';
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';
import 'package:pipeline_bucal/features/app/bucal_shell.dart';
import 'package:pipeline_bucal/features/demo/demo_scenarios.dart';
import 'package:pipeline_bucal/features/library/reference_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('render deterministic light and dark app evidence', (
    tester,
  ) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await ReferenceLibrary.load();
    });
    final library = await ReferenceLibrary.load();
    final bytes = await tester.runAsync(
      () => library.forClass(4).first.bytes(),
    );
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      for (final target in [
        'home',
        'classification',
        'risk-low',
        'risk-medium',
        'risk-high',
      ]) {
        final risk = target == 'risk-low'
            ? RiskLevel.low
            : target == 'risk-high'
            ? RiskLevel.high
            : RiskLevel.medium;
        final demo = DemoTransport()
          ..scenario = DemoScenario(
            'capture',
            'Visual test fixture',
            '',
            classIndex: 4,
            risk: risk,
          );
        final controller = AnalysisController(
          mode: ExecutionMode.offline,
          offline: demo,
          executionOrigin: 'automated:visual_fixture',
        );
        if (target != 'home') {
          await controller.selectImage(
            bytes!,
            referenceId: library.forClass(4).first.id,
          );
          await controller.confirmImage();
          await controller.confirmCrop();
          await controller.acceptQuality(true);
          if (target.startsWith('risk')) {
            if (risk == RiskLevel.high) {
              controller.disagree();
              await controller.declareUncertainty();
            } else {
              await controller.confirmSuggestedClass();
            }
            for (final question in controller.state.questionnaire!.questions) {
              controller.answer(question.id, question.options.first);
            }
            controller.reviewAnswers();
            await controller.submitAnswers();
          }
        }
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: BucalTheme.light(),
              darkTheme: BucalTheme.dark(),
              themeMode: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: BucalShell(
                key: ValueKey('${theme.name}:$target'),
                controller: controller,
                initialTab: target == 'home' ? 0 : 1,
                themeMode: theme,
                onThemeChanged: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final context = tester.element(find.byType(BucalShell));
          await Future.wait(
            tester
                .widgetList<Image>(find.byType(Image))
                .map((widget) => precacheImage(widget.image, context)),
          );
        });
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('capture')),
          matchesGoldenFile(
            '../../docs/ux/screenshots/flutter/${theme.name}-$target.png',
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    }
    debugDisableShadows = true;
  });
}
