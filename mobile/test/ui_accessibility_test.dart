import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/design_system/design_system.dart';
import 'package:pipeline_bucal/features/analysis/analysis_widgets.dart';
import 'package:pipeline_bucal/features/app/bucal_shell.dart';
import 'package:pipeline_bucal/features/library/library_widgets.dart';
import 'package:pipeline_bucal/features/library/reference_library.dart';

Widget app(Widget home) => MaterialApp(
  theme: BucalTheme.light(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: const TextScaler.linear(2.5),
      disableAnimations: true,
    ),
    child: child!,
  ),
  home: home,
);

void setup(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('gallery is usable with 250 percent text', (tester) async {
    setup(tester);
    await tester.runAsync(() => ReferenceLibrary.load());
    await tester.pumpWidget(
      app(
        const Scaffold(body: BucalPage(child: ReferenceGallery(classIndex: 0))),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('reference sheet is usable with 250 percent text', (
    tester,
  ) async {
    setup(tester);
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 80, height: 40)),
    );
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showClinicalImage(
                context,
                bytes,
                'Pápula/nódulo',
                source:
                    'Fixture sintética para teste de layout. Texto longo de atribuição para conferir a rolagem e a ampliação de fonte. Resolução da imagem gerada no teste: 80 × 40 px.',
                action: BucalButton(
                  label: 'Usar em uma análise',
                  onPressed: () {},
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('execution options sheet is usable with 250 percent text', (
    tester,
  ) async {
    setup(tester);
    await tester.pumpWidget(
      app(BucalShell(themeMode: ThemeMode.light, onThemeChanged: (_) {})),
    );
    await tester.tap(find.byTooltip('Sobre e configurações'));
    await tester.pumpAndSettle();
    final configure = find.text('Configurar próxima análise');
    await tester.ensureVisible(configure);
    await tester.pumpAndSettle();
    await tester.tap(configure);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
