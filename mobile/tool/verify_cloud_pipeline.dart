// Cross-language contract check, no local listening socket required.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/domain/pipeline.dart';
import 'package:pipeline_bucal/services/cloud_api.dart';
import 'package:pipeline_bucal/services/pipeline_runner.dart';

void check(bool ok, String message) { if (!ok) throw StateError(message); }
class PythonService implements CloudTransport {
  final calls = <Map<String, Object?>>[];
  bool failNext = false, corruptHash = false, corruptRisk = false;
  @override
  Future<Map<String, dynamic>> call(String operation, Map<String, Object?> data) async {
    calls.add({'operation': operation, ...data});
    if (failNext) { failNext = false; throw const CloudFailure('simulated timeout'); }
    final process = await Process.start(Platform.environment['TEST_PYTHON'] ?? 'python3', [
      '-c', 'import sys,json;from service import process;json.dump(process(sys.argv[1],json.load(sys.stdin)),sys.stdout)', operation,
    ]);
    process.stdin.write(jsonEncode(data));
    await process.stdin.close();
    final output = await utf8.decoder.bind(process.stdout).join();
    final errors = await utf8.decoder.bind(process.stderr).join();
    if (await process.exitCode != 0) throw StateError(errors);
    final result = jsonDecode(output) as Map<String, dynamic>;
    if (corruptHash) result['image_hash'] = 'different-image';
    if (corruptRisk) result['risk_index'] = 3;
    return result;
  }
}
Future<void> mustFail(Future<void> Function() action) async {
  try { await action(); } on CloudFailure { return; }
  throw StateError('Expected CloudFailure');
}
Future<void> main() async {
  final image = img.Image(width: 80, height: 40);
  img.fill(image, color: img.ColorRgb8(255, 0, 0));
  img.fillRect(image, x1: 40, y1: 0, x2: 79, y2: 39, color: img.ColorRgb8(0, 0, 255));
  final original = preparePhoto(Uint8List.fromList(img.encodePng(image)));
  final p = Pipeline(executionMode: 'cloud');
  final api = PythonService();
  final runner = PipelineRunner(p, cloud: api);
  api.failNext = true;
  await mustFail(() => runner.start(original));
  check(p.stage == Stage.empty, 'Failed detection must not advance');
  await runner.start(original);
  check(img.decodePng(runner.automaticCrop!)!.width == 64, 'Cloud must crop actual pixels');
  const box = CropBox(.5, 0, 1, 1);
  final corrected = cropPhoto(original.bytes, box);
  api.failNext = true;
  await mustFail(() => runner.confirmCrop(corrected, box, manual: true));
  check(p.stage == Stage.crop && p.activeHash == null, 'Failed focus must leave crop retryable');
  await runner.confirmCrop(corrected, box, manual: true);
  final hash = p.activeHash;
  check(img.decodePng(p.activeBytes!)!.getPixel(0, 0).b == 255, 'Corrected pixels lost');
  api.corruptHash = true;
  await mustFail(() => runner.validateQuality(true));
  check(p.stage == Stage.quality, 'Mismatched image must not advance');
  api.corruptHash = false;
  api.failNext = true;
  await mustFail(() => runner.validateQuality(true));
  check(p.stage == Stage.quality, 'Timeout must not advance');
  await runner.validateQuality(true);
  final selected = (p.config.suggestedClass + 1) % 6;
  await runner.confirmClass(selected);
  check(runner.questionPrompts!.every((q) => q.contains(lesionClasses[selected])), 'Wrong questionnaire class');
  final answers = ['Não informado', 'Sim', 'Não'];
  api.corruptRisk = true;
  await mustFail(() => runner.complete(answers));
  check(p.stage == Stage.questionnaire, 'Only three risks are valid');
  api.corruptRisk = false;
  api.failNext = true;
  await mustFail(() => runner.complete(answers));
  check(p.answers.isEmpty && p.activeHash == hash, 'Retry must preserve session');
  await runner.complete(answers);
  check(p.stage == Stage.completed && p.activeHash == hash, 'Pipeline did not complete');
  for (final call in api.calls.where((c) => c['operation'] != 'detect')) {
    check(call['image_hash'] == hash, 'An old image was sent downstream');
    check(base64Encode(corrected) == call['image_base64'], 'Image bytes changed downstream');
  }
  final feedback = p.feedback.where((e) => e['module'] == 'IntelligentSystemStub').toList();
  check(feedback.length == 3, 'YOLO, CNN and MNN feedback paths required');
  check(jsonDecode(p.summary())['execution_mode'] == 'cloud', 'Missing source label');
  final offline = Pipeline();
  final local = PipelineRunner(offline);
  await local.start(original);
  await local.confirmCrop(corrected, box, manual: true);
  await local.validateQuality(true);
  await local.confirmClass(offline.config.suggestedClass);
  await local.complete(answers);
  check(offline.stage == Stage.completed && !local.isCloud, 'Offline demo failed');
  check(offline.sessionId != p.sessionId, 'New simulation must have a new identity');
  stdout.writeln('PASS: Dart/Python contract, five stages, crop identity, class routing, three-risk boundary, retries, feedback and offline mode');
}
