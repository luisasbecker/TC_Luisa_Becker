import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/domain/pipeline.dart';

PreparedPhoto source() {
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
  return preparePhoto(Uint8List.fromList(img.encodePng(image)));
}

Pipeline cropped({SimulationConfig config = const SimulationConfig()}) =>
    Pipeline(config: config)
      ..start(source())
      ..confirmCrop(const CropBox(.5, 0, 1, 1), manual: true);
void main() {
  test('manual crop is real pixel data shared by every downstream stage', () {
    final p = cropped();
    final hash = p.activeHash;
    void verify() {
      final image = img.decodePng(p.activeBytes!)!;
      expect(image.width, 40);
      expect(image.getPixel(0, 0).b, 255);
      expect(image.getPixel(0, 0).r, 0);
      expect(p.activeHash, hash);
    }

    verify();
    p.validateQuality(true);
    verify();
    p.confirmClass(3);
    verify();
    p.complete(['Menos de 2 semanas', 'Não', 'Sim']);
    verify();
    expect(p.stage, Stage.completed);
    expect(p.feedback.length, 2);
    expect(
      p.history.where((e) => e['event'] == 'CNN simulada').single['image_hash'],
      hash,
    );
    final summary = jsonDecode(p.summary()) as Map;
    expect(summary['result']['model'], 'ErosionMultimodalStub');
    expect(summary.containsKey('bytes'), false);
    expect(p.summary().contains('base64'), false);
  });
  test('active pixels cannot be mutated through getter', () {
    final p = cropped();
    final original = p.activeBytes!;
    p.activeBytes![0] = 0;
    expect(p.activeBytes, orderedEquals(original));
  });
  test('invalid and empty crop rejected', () {
    final p = Pipeline()..start(source());
    expect(
      () => p.confirmCrop(const CropBox(.8, 0, .2, 1), manual: true),
      throwsFormatException,
    );
    expect(p.stage, Stage.crop);
  });
  test('full image selection preserves dimensions', () {
    final p = Pipeline()
      ..start(source())
      ..confirmCrop(const CropBox(0, 0, 1, 1), manual: false);
    expect(img.decodePng(p.activeBytes!)!.width, 80);
    expect(p.feedback, isEmpty);
  });
  test('rejected quality prevents classification', () {
    final p = cropped()..validateQuality(false);
    expect(p.stage, Stage.rejected);
    expect(() => p.confirmClass(2), throwsStateError);
  });
  test('failed detection prevents crop', () {
    final p = Pipeline(config: const SimulationConfig(detects: false))
      ..start(source());
    expect(p.stage, Stage.rejected);
    expect(
      () => p.confirmCrop(const CropBox(0, 0, 1, 1), manual: false),
      throwsStateError,
    );
  });
  test('incomplete questionnaire cannot finish', () {
    final p = cropped()
      ..validateQuality(true)
      ..confirmClass(4);
    expect(() => p.complete(['Sim']), throwsArgumentError);
    expect(p.stage, Stage.questionnaire);
  });
  test('corrupt image is rejected', () {
    expect(
      () => preparePhoto(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });
  for (var i = 0; i < lesionClasses.length; i++) {
    test('class $i selects its own multimodal stub', () {
      final p = cropped()
        ..validateQuality(true)
        ..confirmClass(i)
        ..complete(['Não informado', 'Sim', 'Não']);
      final summary = jsonDecode(p.summary());
      expect(summary['result']['model'], modelNames[i]);
      expect(summary['result']['message'], contains('não substitui'));
    });
  }
}
