import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/domain/pipeline.dart';
import 'package:pipeline_bucal/services/pipeline_runner.dart';
import 'cloud_risk_test.dart' show RiskReply;

Pipeline questionnaire() =>
    Pipeline(config: const SimulationConfig(risk: 1), executionMode: 'cloud')
      ..start(
        preparePhoto(
          Uint8List.fromList(img.encodePng(img.Image(width: 16, height: 16))),
        ),
      )
      ..confirmCrop(const CropBox(0, 0, 1, 1), manual: false)
      ..validateQuality(true)
      ..confirmClass(4);

void main() {
  test('cloud cannot complete with an implicit configured risk', () {
    final pipeline = questionnaire();
    expect(
      () => pipeline.complete(['Não informado', 'Sim', 'Não']),
      throwsStateError,
    );
    expect(pipeline.stage, Stage.questionnaire);
    expect(jsonDecode(pipeline.summary())['result'], isNull);
  });

  test('accepted cloud result is not a mutable simulation default', () async {
    final pipeline = questionnaire();
    await PipelineRunner(
      pipeline,
      cloud: RiskReply(0),
    ).complete(['Não informado', 'Sim', 'Não']);
    pipeline.config = const SimulationConfig(risk: 1);
    expect(jsonDecode(pipeline.summary())['result']['risk'], risks[0]);
  });
}
