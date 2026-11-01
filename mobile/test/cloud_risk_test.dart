import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/domain/pipeline.dart';
import 'package:pipeline_bucal/main.dart';
import 'package:pipeline_bucal/services/cloud_api.dart';
import 'package:pipeline_bucal/services/pipeline_runner.dart';

class RiskReply implements CloudTransport {
  RiskReply(this.risk);
  final int risk;

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data,
  ) async {
    expect(operation, 'multimodal');
    return {
      'api_version': '1',
      'simulation_only': true,
      'execution_mode': 'cloud',
      'session_id': data['session_id'],
      'operation': operation,
      'image_hash': data['image_hash'],
      'data_stored': false,
      'feedback': [],
      'module': modelNames[data['class_index'] as int],
      'class_index': data['class_index'],
      'risk_index': risk,
      'risk_label': risks[risk],
    };
  }
}

void main() {
  for (var risk = 0; risk < risks.length; risk++) {
    testWidgets('cloud risk $risk reaches result screen and summary', (
      tester,
    ) async {
      final photo = preparePhoto(
        Uint8List.fromList(img.encodePng(img.Image(width: 16, height: 16))),
      );
      // Start at medium to catch a client that ignores low/high cloud replies.
      final pipeline =
          Pipeline(
              config: const SimulationConfig(risk: 1),
              executionMode: 'cloud',
            )
            ..start(photo)
            ..confirmCrop(const CropBox(0, 0, 1, 1), manual: false)
            ..validateQuality(true)
            ..confirmClass(4);
      await PipelineRunner(
        pipeline,
        cloud: RiskReply(risk),
      ).complete(['Não informado', 'Sim', 'Não']);
      expect(pipeline.resultRisk, risk);
      expect(jsonDecode(pipeline.summary())['result']['risk'], risks[risk]);
      await tester.pumpWidget(
        MaterialApp(home: PipelineScreen(initialPipeline: pipeline)),
      );
      expect(find.text(risks[risk]), findsOneWidget);
      for (var other = 0; other < risks.length; other++) {
        if (other != risk) expect(find.text(risks[other]), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
