import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/main.dart';
import 'package:pipeline_bucal/domain/pipeline.dart';
import 'dart:typed_data';

void main() {
  testWidgets('start screen offers gallery and camera with simulation label', (
    tester,
  ) async {
    await tester.pumpWidget(const PipelineApp());
    expect(find.text('Selecionar imagem'), findsOneWidget);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('PROTÓTIPO ACADÊMICO • SIMULAÇÃO'), findsOneWidget);
  });
  testWidgets(
    'quality screen displays active crop pixels instead of original',
    (tester) async {
      final source = img.Image(width: 80, height: 40);
      img.fill(source, color: img.ColorRgb8(255, 0, 0));
      img.fillRect(
        source,
        x1: 40,
        y1: 0,
        x2: 79,
        y2: 39,
        color: img.ColorRgb8(0, 0, 255),
      );
      final pipeline = Pipeline()
        ..start(preparePhoto(Uint8List.fromList(img.encodePng(source))));
      pipeline.confirmCrop(const CropBox(.5, 0, 1, 1), manual: true);
      await tester.pumpWidget(
        MaterialApp(home: PipelineScreen(initialPipeline: pipeline)),
      );
      final displayed = tester.widget<Image>(
        find.byKey(ValueKey('${pipeline.activeHash}:Recorte validado em uso')),
      );
      final pixels = img.decodePng((displayed.image as MemoryImage).bytes)!;
      expect(pixels.width, 40);
      expect(pixels.getPixel(0, 0).b, 255);
      expect(find.text('Recorte validado em uso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small screen and enlarged text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const PipelineScreen(),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
