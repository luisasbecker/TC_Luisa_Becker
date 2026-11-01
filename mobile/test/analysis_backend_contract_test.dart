import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/core/services/analysis_transport.dart';
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';

/// Opt-in cross-language contract test. It calls the real Python implementation
/// over stdin/stdout, without opening ports, deploying or consuming cloud quota.
class PythonContractTransport implements AnalysisTransport {
  PythonContractTransport(this.executable);
  final String executable;
  final errors = <String>[];
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    final process = await Process.start(
      executable,
      [
        '-c',
        'import json,sys; from api_v2 import process; request=json.load(sys.stdin); print(json.dumps(process(request["operation"],request["payload"])))',
      ],
      environment: {
        'PYTHONPATH':
            '${Platform.environment['PYTHONPATH'] ?? ''}${Platform.isWindows ? ';' : ':'}${Directory.current.parent.path}/cloud',
      },
    );
    process.stdin.write(
      jsonEncode({'operation': operation, 'payload': payload}),
    );
    await process.stdin.close();
    final output = process.stdout.transform(utf8.decoder).join();
    final stderr = process.stderr.transform(utf8.decoder).join();
    final status = await process.exitCode;
    final message = await stderr;
    if (status != 0) {
      errors.add(message);
      throw AnalysisServiceException('Local Python contract failed: $message');
    }
    return jsonDecode(await output) as Map<String, dynamic>;
  }
}

void main() {
  final executable = Platform.environment['PIPELINE_PYTHON'];
  final skip = executable == null
      ? 'Set PIPELINE_PYTHON and PYTHONPATH with Pillow to run the local v2 contract.'
      : false;
  test(
    'real Python v2 accepts manual crop, uncertainty, feedback and all six questionnaire/model routes',
    () async {
      final transport = PythonContractTransport(executable!);
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 50, height: 40)),
      );
      for (var index = 0; index < 7; index++) {
        var sequence = index * 100;
        final flow = AnalysisController(
          cloud: transport,
          idFactory: () =>
              'contract_${(++sequence).toString().padLeft(16, '0')}',
        );
        await flow.selectImage(bytes);
        await flow.confirmImage();
        expect(flow.state.error, isNull);
        flow.editCrop();
        await flow.confirmCrop(const CropBox(.2, .2, .8, .8));
        expect(
          flow.state.stage,
          AnalysisStage.quality,
          reason: flow.state.error,
        );
        await flow.acceptQuality(true);
        expect(flow.state.suggestedClass, isNotNull, reason: flow.state.error);
        if (index == 6) {
          flow.disagree();
          await flow.declareUncertainty();
        } else if (flow.state.suggestedClass == index) {
          await flow.confirmSuggestedClass();
        } else {
          flow.disagree();
          await flow.chooseClass(index);
        }
        expect(
          flow.state.stage,
          AnalysisStage.questionnaire,
          reason: flow.state.error,
        );
        for (final question in flow.state.questionnaire!.questions) {
          flow.answer(question.id, question.options.first);
        }
        flow.reviewAnswers();
        await flow.submitAnswers();
        expect(
          flow.state.stage,
          AnalysisStage.result,
          reason: flow.state.error,
        );
        expect(
          flow.state.result!.module,
          modelNames[flow.state.effectiveClass!],
        );
        expect(flow.state.result!.provisional, index == 6);
        expect(flow.state.result!.risk, isIn(RiskLevel.values));
        await flow.retryPendingFeedback();
        expect(transport.errors, isEmpty);
        flow.dispose();
      }
    },
    skip: skip,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
