// Explicit diagnostic entry point; never the target of the distributed app.
// Uses only synthetic pixels and the same HTTPS client/runner as the normal app.
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/domain/pipeline.dart';
import 'package:pipeline_bucal/main.dart' as app;
import 'package:pipeline_bucal/services/cloud_api.dart';
import 'package:pipeline_bucal/services/cloud_endpoint.dart';
import 'package:pipeline_bucal/services/pipeline_runner.dart';

// Select test sessions that exercise each deterministic server branch. Normal
// sessions continue to use an unconstrained random identity in the main app.
Pipeline sessionForRisk(int expected) {
  for (var attempt = 0; attempt < 4096; attempt++) {
    final pipeline = Pipeline(executionMode: 'cloud');
    final digest = sha256.convert(
      utf8.encode('ghost-v1:${pipeline.sessionId}:risk'),
    );
    var remainder = 0;
    for (final byte in digest.bytes) {
      remainder = (remainder * 256 + byte) % risks.length;
    }
    if (remainder == expected) return pipeline;
  }
  throw StateError('Could not prepare test session');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Text(
              'Verificação técnica da cloud\nUsando apenas imagem sintética.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ),
  );
  try {
    final pixels = img.Image(width: 32, height: 16);
    img.fill(pixels, color: img.ColorRgb8(255, 0, 0));
    img.fillRect(
      pixels,
      x1: 16,
      y1: 0,
      x2: 31,
      y2: 15,
      color: img.ColorRgb8(0, 0, 255),
    );
    final original = preparePhoto(Uint8List.fromList(img.encodePng(pixels)));
    const box = CropBox(.5, 0, 1, 1);
    final corrected = cropPhoto(original.bytes, box);
    for (var expected = 0; expected < risks.length; expected++) {
      final pipeline = sessionForRisk(expected);
      final runner = PipelineRunner(pipeline, cloud: CloudApi(cloudEndpoint));
      await runner.start(original);
      await runner.confirmCrop(corrected, box, manual: true);
      await runner.validateQuality(true);
      await runner.confirmClass(
        (pipeline.config.suggestedClass + 1) % lesionClasses.length,
      );
      await runner.complete(['Não informado', 'Sim', 'Não']);
      final summary = jsonDecode(pipeline.summary()) as Map;
      if (pipeline.resultRisk != expected ||
          summary['result']['risk'] != risks[expected] ||
          pipeline.activeHash != sha256.convert(corrected).toString()) {
        throw StateError('Device result mismatch for expected risk $expected');
      }
      debugPrint(
        '[CLOUD-DEVICE-CHECK] PASS risk=$expected label=${pipeline.resultRiskLabel} mode=${pipeline.executionMode} crop=verified',
      );
    }
    debugPrint(
      '[CLOUD-DEVICE-CHECK] PASS all three risks through five real HTTPS stages on this device',
    );
    runApp(const app.PipelineApp());
  } catch (error) {
    debugPrint('[CLOUD-DEVICE-CHECK] FAIL $error');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Text(
                'Verificação não concluída: $error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
