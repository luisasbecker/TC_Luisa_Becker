// Reproducible Flutter widget captures, generated with --update-goldens.
// Every service response is a controlled local fixture. These screenshots are
// not evidence of live cloud calls, physical-device rendering or user research.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipeline_bucal/core/services/analysis_transport.dart';
import 'package:pipeline_bucal/design_system/design_system.dart';
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';
import 'package:pipeline_bucal/features/app/bucal_shell.dart';
import 'package:pipeline_bucal/features/demo/demo_scenarios.dart';
import 'package:pipeline_bucal/features/library/reference_library.dart';

class _CaptureCloudFixture implements AnalysisTransport {
  final fixture = DemoTransport()
    ..scenario = const DemoScenario(
      'capture-crop-cloud',
      'Controlled visual fixture',
      '',
      focus: false,
    );

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async => {
    ...await fixture.call(operation, payload),
    'execution_mode': 'cloud',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'capture fixed crop and cloud feedback with controlled fixtures',
    (tester) async {
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
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
      final reference = library.forClass(4).first;
      final bytes = await tester.runAsync(reference.bytes);

      for (final (name, theme, quality, compact) in [
        ('light-crop-fixed', ThemeMode.light, false, false),
        ('dark-crop-fixed', ThemeMode.dark, false, false),
        ('light-focus-cloud', ThemeMode.light, true, false),
        ('dark-focus-cloud', ThemeMode.dark, true, false),
        ('compact-crop-fixed', ThemeMode.light, false, true),
      ]) {
        tester.view.physicalSize = compact
            ? const Size(320, 568)
            : const Size(390, 844);
        final flow = AnalysisController(
          cloud: _CaptureCloudFixture(),
          executionOrigin: 'automated:visual_fixture',
        );
        await flow.selectImage(bytes!, referenceId: reference.id);
        await flow.confirmImage();
        if (quality) {
          await flow.confirmCrop();
        } else {
          flow.editCrop();
        }
        expect(flow.state.error, isNull);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('capture-crop-cloud'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: BucalTheme.light(),
              darkTheme: BucalTheme.dark(),
              themeMode: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(compact ? 2.5 : 1),
                ),
                child: child!,
              ),
              home: BucalShell(
                key: ValueKey(name),
                controller: flow,
                initialTab: 1,
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
          find.byKey(const ValueKey('capture-crop-cloud')),
          matchesGoldenFile('../../docs/ux/screenshots/flutter/$name.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        flow.dispose();
      }
      debugDisableShadows = true;
    },
  );
}
