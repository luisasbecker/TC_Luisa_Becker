import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pipeline_bucal/core/services/analysis_transport.dart';
import 'package:pipeline_bucal/domain/pipeline.dart' show cropPhoto;
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';

Uint8List photo({int red = 100}) {
  final pixels = img.Image(width: 100, height: 80);
  for (var y = 0; y < pixels.height; y++) {
    for (var x = 0; x < pixels.width; x++) {
      pixels.setPixelRgb(x, y, red + x, y * 2, x + y);
    }
  }
  return Uint8List.fromList(img.encodePng(pixels));
}

class RecordedCall {
  RecordedCall(this.operation, this.payload);
  final String operation;
  final Map<String, Object?> payload;
}

/// Controlled responses belong only to automated tests, never the app UI.
class FakeCloud implements AnalysisTransport {
  FakeCloud({this.classIndex = 4, this.risk = 1, this.detected = true});
  final int classIndex, risk;
  final bool detected;
  final calls = <RecordedCall>[];
  final offline = OfflineAnalysisTransport();
  String? failNext, pauseOperation, corruptNext, wrongModuleNext;
  Completer<void>? paused;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    calls.add(RecordedCall(operation, Map.of(payload)));
    if (failNext == operation) {
      failNext = null;
      throw const AnalysisServiceException(
        'Conexão interrompida. Tente novamente.',
      );
    }
    if (pauseOperation == operation) {
      pauseOperation = null;
      paused = Completer<void>();
      await paused!.future;
    }
    final response = await offline.call(operation, payload);
    response['execution_mode'] = 'cloud';
    if (operation == 'detect') {
      response['detected'] = detected;
      if (detected) {
        const roi = CropBox(.1, .1, .9, .9);
        final pixels = cropPhoto(
          base64Decode(payload['image_base64']! as String),
          roi,
        );
        response.addAll({
          'box': roi.toJson(),
          'crop_base64': base64Encode(pixels),
          'crop_hash': sha256.convert(pixels).toString(),
        });
      } else {
        response.addAll({'box': null, 'crop_base64': null, 'crop_hash': null});
      }
    }
    if (operation == 'classify') {
      response.addAll({
        'class_index': classIndex,
        'class_label': lesionClasses[classIndex],
      });
    }
    if (operation == 'multimodal') {
      response.addAll({
        'risk': RiskLevel.values[risk].name,
        'risk_index': risk,
        'risk_label': riskTitles[risk],
      });
    }
    if (corruptNext == operation) {
      response['image_id'] = 'different-image-id';
      corruptNext = null;
    }
    if (wrongModuleNext == operation) {
      response['module'] = 'UnrelatedModule';
      wrongModuleNext = null;
    }
    return response;
  }

  List<RecordedCall> operations(String op) =>
      calls.where((call) => call.operation == op).toList();
}

class UnexpectedOffline implements AnalysisTransport {
  int calls = 0;

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    calls++;
    throw StateError('A cloud analysis must never invoke offline processing.');
  }
}

AnalysisController controller(
  FakeCloud cloud, {
  DateTime Function()? clock,
  AnalysisTransport? offline,
}) {
  var counter = 0;
  return AnalysisController(
    cloud: cloud,
    offline: offline,
    clock: clock,
    idFactory: () => 'fixture_${(++counter).toString().padLeft(16, '0')}',
  );
}

const cloudStages = [
  'detect',
  'focus',
  'classify',
  'questionnaire',
  'multimodal',
];

Future<void> prepareOperation(AnalysisController flow, String operation) async {
  await flow.selectImage(photo());
  if (operation == 'detect') return;
  await flow.confirmImage();
  if (operation == 'focus') return;
  await flow.confirmCrop();
  if (operation == 'classify') return;
  await flow.acceptQuality(true);
  if (operation == 'questionnaire') return;
  await flow.confirmSuggestedClass();
  fillAnswers(flow);
}

Future<void> performOperation(AnalysisController flow, String operation) =>
    switch (operation) {
      'detect' => flow.confirmImage(),
      'focus' => flow.confirmCrop(),
      'classify' => flow.acceptQuality(true),
      'questionnaire' => flow.confirmSuggestedClass(),
      'multimodal' => flow.submitAnswers(),
      _ => throw ArgumentError.value(operation),
    };

Future<void> reachClassification(AnalysisController flow) async {
  await flow.selectImage(photo());
  await flow.confirmImage();
  await flow.confirmCrop();
  await flow.acceptQuality(true);
  expect(flow.state.stage, AnalysisStage.classification);
}

void fillAnswers(AnalysisController flow) {
  for (final question in flow.state.questionnaire!.questions) {
    flow.answer(question.id, question.options.first);
  }
  expect(flow.reviewAnswers(), isTrue);
}

Future<void> reachResult(AnalysisController flow) async {
  await reachClassification(flow);
  await flow.confirmSuggestedClass();
  fillAnswers(flow);
  await flow.submitAnswers();
  expect(flow.state.stage, AnalysisStage.result);
}

void main() {
  test(
    'image identity and the actual corrected pixels continue through all five cloud stages',
    () async {
      final cloud = FakeCloud(risk: 2);
      final offline = UnexpectedOffline();
      final flow = controller(cloud, offline: offline);
      addTearDown(flow.dispose);
      await flow.selectImage(photo());
      final analysisId = flow.state.analysisId;
      final imageId = flow.state.imageId;
      final originalHash = flow.state.original!.hash;
      await flow.confirmImage();
      final automaticHash = flow.state.activeImage!.hash;
      flow.editCrop();
      await flow.confirmCrop(const CropBox(.25, .2, .65, .75));
      final corrected = flow.state.activeImage!;
      expect(corrected.hash, isNot(automaticHash));
      expect(corrected.hash, isNot(originalHash));
      expect(corrected.width, 40);
      await flow.acceptQuality(true);
      await flow.confirmSuggestedClass();
      fillAnswers(flow);
      await flow.submitAnswers();
      expect(flow.state.result!.risk, RiskLevel.high);
      expect(
        cloud.calls
            .where((call) => call.operation != 'feedback')
            .map((call) => call.operation),
        cloudStages,
      );
      expect(offline.calls, 0);
      for (final request in cloud.calls.where(
        (r) => r.operation != 'feedback',
      )) {
        expect(request.payload['analysis_id'], analysisId);
        expect(request.payload['image_id'], imageId);
        if (request.operation != 'detect') {
          expect(
            base64Decode(request.payload['image_base64']! as String),
            corrected.bytes,
          );
          expect(request.payload['image_hash'], corrected.hash);
          expect(request.payload['crop_revision'], 1);
        }
      }
      expect(flow.events.any((e) => e['type'] == 'crop_corrected'), isTrue);
      final receipts = flow.events
          .where((event) => event['type'] == 'operation_completed')
          .toList();
      expect(receipts.map((event) => event['operation']), cloudStages);
      for (final receipt in receipts) {
        expect(receipt['execution_mode'], 'cloud');
        expect(receipt['module'], isA<String>());
        expect(receipt['duration_ms'], isNonNegative);
        expect(receipt.containsKey('image_base64'), isFalse);
      }
      expect(
        cloud
            .operations('feedback')
            .every((r) => !r.payload.containsKey('image_base64')),
        isTrue,
      );
    },
  );

  for (final operation in cloudStages) {
    test(
      '$operation waits for a validated cloud receipt before completion',
      () async {
        final cloud = FakeCloud();
        final offline = UnexpectedOffline();
        var now = DateTime.utc(2026, 11, 1);
        final flow = controller(cloud, offline: offline, clock: () => now);
        addTearDown(flow.dispose);
        await prepareOperation(flow, operation);
        cloud.pauseOperation = operation;
        final pending = performOperation(flow, operation);
        await Future<void>.delayed(Duration.zero);
        expect(flow.pendingOperation, operation);
        expect(flow.state.busy, isTrue);
        expect(
          flow.events.where(
            (event) =>
                event['type'] == 'operation_completed' &&
                event['operation'] == operation,
          ),
          isEmpty,
        );
        final started = flow.events.lastWhere(
          (event) =>
              event['type'] == 'operation_started' &&
              event['operation'] == operation,
        );
        expect(started['execution_mode'], 'cloud');
        now = now.add(const Duration(milliseconds: 250));
        cloud.paused!.complete();
        await pending;
        expect(flow.pendingOperation, isNull);
        expect(flow.state.busy, isFalse);
        expect(flow.state.error, isNull);
        final completed = flow.events.lastWhere(
          (event) =>
              event['type'] == 'operation_completed' &&
              event['operation'] == operation,
        );
        expect(completed['execution_mode'], 'cloud');
        expect(completed['request_id'], started['request_id']);
        expect(
          completed['module'],
          operation == 'multimodal'
              ? modelNames[flow.state.effectiveClass!]
              : analysisOperationModules[operation],
        );
        expect(completed['duration_ms'], 250);
        expect(offline.calls, 0);
      },
    );

    test(
      '$operation network failure stays cloud and retries identical inputs',
      () async {
        final cloud = FakeCloud();
        final offline = UnexpectedOffline();
        final flow = controller(cloud, offline: offline);
        addTearDown(flow.dispose);
        await prepareOperation(flow, operation);
        final previousStage = flow.state.stage;
        cloud.failNext = operation;
        await performOperation(flow, operation);
        expect(flow.state.stage, previousStage);
        expect(flow.state.error, isNotNull);
        expect(flow.state.mode, ExecutionMode.cloud);
        expect(flow.pendingOperation, isNull);
        expect(flow.canRetry, isTrue);
        expect(
          flow.events.where(
            (event) =>
                event['type'] == 'operation_completed' &&
                event['operation'] == operation,
          ),
          isEmpty,
        );
        final failed = flow.events.lastWhere(
          (event) =>
              event['type'] == 'operation_error' &&
              event['operation'] == operation,
        );
        expect(failed['execution_mode'], 'cloud');
        expect(failed.containsKey('module'), isFalse);
        await flow.retry();
        expect(cloud.operations(operation), hasLength(2));
        expect(
          cloud.operations(operation).first.payload,
          cloud.operations(operation).last.payload,
        );
        expect(flow.state.error, isNull);
        expect(flow.canRetry, isFalse);
        expect(flow.pendingOperation, isNull);
        expect(offline.calls, 0);
      },
    );

    for (final wrongModule in [false, true]) {
      test(
        '$operation rejects a wrong ${wrongModule ? 'module' : 'image identity'} without recording success',
        () async {
          final cloud = FakeCloud();
          final offline = UnexpectedOffline();
          final flow = controller(cloud, offline: offline);
          addTearDown(flow.dispose);
          await prepareOperation(flow, operation);
          final previousStage = flow.state.stage;
          if (wrongModule) {
            cloud.wrongModuleNext = operation;
          } else {
            cloud.corruptNext = operation;
          }
          await performOperation(flow, operation);
          expect(flow.state.stage, previousStage);
          expect(flow.state.error, isNotNull);
          expect(flow.pendingOperation, isNull);
          expect(
            flow.events.where(
              (event) =>
                  event['type'] == 'operation_completed' &&
                  event['operation'] == operation,
            ),
            isEmpty,
          );
          expect(flow.state.result, isNull);
          await flow.retry();
          expect(flow.state.error, isNull);
          expect(offline.calls, 0);
        },
      );
    }
  }

  test(
    'a replacement keeps analysis identity, creates a new image and must rerun detection',
    () async {
      final cloud = FakeCloud();
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await reachResult(flow);
      final analysis = flow.state.analysisId, firstImage = flow.state.imageId;
      flow.replaceImage(reason: 'test_new_photo');
      expect(flow.state.stage, AnalysisStage.acquisition);
      expect(flow.state.result, isNull);
      expect(flow.state.questionnaire, isNull);
      expect(flow.state.activeImage, isNull);
      expect(flow.state.answers, isEmpty);
      await flow.selectImage(photo(red: 60));
      expect(flow.state.analysisId, analysis);
      expect(flow.state.imageId, isNot(firstImage));
      await flow.confirmImage();
      expect(cloud.operations('detect'), hasLength(2));
      expect(flow.state.cropRevision, 0);
      expect(flow.state.stage, AnalysisStage.crop);
    },
  );

  test(
    'no detection offers manual ROI and never classifies an image without one',
    () async {
      final cloud = FakeCloud(detected: false);
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await flow.selectImage(photo());
      await flow.confirmImage();
      await flow.confirmCrop();
      await flow.acceptQuality(true);
      expect(cloud.operations('classify'), isEmpty);
      expect(flow.state.activeImage, isNull);
      expect(flow.state.error, isNotNull);
      flow.editCrop();
      await flow.confirmCrop(const CropBox(.2, .3, .8, .9));
      expect(flow.state.stage, AnalysisStage.quality);
      await flow.acceptQuality(true);
      expect(cloud.operations('classify'), hasLength(1));
    },
  );

  test(
    'rejected visual quality returns to acquisition with reason and invalidates the crop',
    () async {
      final cloud = FakeCloud();
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await flow.selectImage(photo());
      await flow.confirmImage();
      await flow.confirmCrop();
      await flow.acceptQuality(false);
      expect(flow.state.stage, AnalysisStage.acquisition);
      expect(flow.state.activeImage, isNull);
      expect(cloud.operations('classify'), isEmpty);
      expect(
        flow.events.any((e) => e['reason'] == 'quality_inadequate'),
        isTrue,
      );
    },
  );

  for (var index = 0; index < 6; index++) {
    test(
      'class $index keeps its own questionnaire and multimodal with categorical risk ${index % 3}',
      () async {
        final cloud = FakeCloud(classIndex: index, risk: index % 3);
        final flow = controller(cloud);
        addTearDown(flow.dispose);
        await reachResult(flow);
        expect(flow.state.suggestedClass, index);
        expect(flow.state.questionnaire!.classIndex, index);
        expect(flow.state.questionnaire!.id, 'lesion-$index-demo');
        expect(flow.state.result!.module, modelNames[index]);
        expect(flow.state.result!.risk, RiskLevel.values[index % 3]);
        expect(flow.state.result!.title, isNot(contains('%')));
        expect(flow.state.result!.guidance, contains('avaliação médica'));
        flow.finish();
        expect(flow.state.stage, AnalysisStage.completed);
        expect(
          flow.events.any((e) => e['type'] == 'analysis_completed'),
          isTrue,
        );
      },
    );
  }

  test(
    'uncertainty proceeds to the result without becoming confirmation',
    () async {
      final cloud = FakeCloud(classIndex: 3, risk: 0);
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await reachClassification(flow);
      flow.disagree();
      await flow.declareUncertainty();
      expect(flow.state.stage, AnalysisStage.questionnaire);
      expect(flow.state.suggestedClass, 3);
      expect(flow.state.effectiveClass, 3);
      expect(flow.state.decision!.selectedClass, isNull);
      expect(flow.state.decision!.status, ProfessionalDecisionStatus.uncertain);
      expect(flow.state.provisional, isTrue);
      fillAnswers(flow);
      await flow.submitAnswers();
      expect(flow.state.result!.provisional, isTrue);
      final exported = jsonDecode(flow.exportHistory()) as Map;
      expect(exported['decision']['class_confirmed'], isFalse);
      final request = cloud.operations('multimodal').single.payload;
      expect((request['decision']! as Map)['status'], 'uncertain');
      expect(
        flow.events.any((e) => e['feedback_type'] == 'class_uncertain'),
        isTrue,
      );
    },
  );

  test(
    'alternative selection preserves original CNN class and invalidates incompatible answers',
    () async {
      final cloud = FakeCloud(classIndex: 0);
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await reachResult(flow);
      flow.backToClassification();
      flow.disagree();
      await flow.chooseClass(5);
      expect(flow.state.suggestedClass, 0);
      expect(flow.state.effectiveClass, 5);
      expect(flow.state.decision!.status, ProfessionalDecisionStatus.corrected);
      expect(flow.state.questionnaire!.id, 'lesion-5-demo');
      expect(flow.state.answers, isEmpty);
      expect(flow.state.result, isNull);
      fillAnswers(flow);
      await flow.submitAnswers();
      expect(flow.state.result!.module, modelNames[5]);
      expect(flow.state.result!.provisional, isFalse);
    },
  );

  test(
    'changing confirmation to uncertainty retains compatible answers but invalidates result metadata',
    () async {
      final flow = controller(FakeCloud());
      addTearDown(flow.dispose);
      await reachResult(flow);
      final previousAnswers = flow.state.answers;
      flow.backToClassification();
      flow.disagree();
      await flow.declareUncertainty();
      expect(flow.state.answers, previousAnswers);
      expect(flow.state.result, isNull);
      expect(flow.state.provisional, isTrue);
      expect(flow.reviewAnswers(), isTrue);
      await flow.submitAnswers();
      expect(flow.state.result!.provisional, isTrue);
    },
  );

  test(
    'navigation preserves state, crop edits invalidate every dependent result',
    () async {
      final flow = controller(FakeCloud());
      addTearDown(flow.dispose);
      await reachResult(flow);
      final result = flow.state.result;
      final answers = flow.state.answers;
      flow.backToCrop();
      expect(flow.state.result, same(result));
      expect(flow.state.answers, answers);
      flow.editCrop();
      await flow.confirmCrop(const CropBox(.3, .3, .7, .7));
      expect(flow.state.stage, AnalysisStage.quality);
      expect(flow.state.cropRevision, 2);
      expect(flow.state.suggestedClass, isNull);
      expect(flow.state.decision, isNull);
      expect(flow.state.questionnaire, isNull);
      expect(flow.state.answers, isEmpty);
      expect(flow.state.result, isNull);
    },
  );

  test(
    'question sections enforce completeness and edits invalidate an earlier result',
    () async {
      final flow = controller(FakeCloud());
      addTearDown(flow.dispose);
      await reachClassification(flow);
      await flow.confirmSuggestedClass();
      expect(flow.nextSection(), isFalse);
      expect(flow.state.sectionIndex, 0);
      expect(flow.reviewAnswers(), isFalse);
      final question = flow.state.questionnaire!.questions.first;
      flow.answer(question.id, 'not-an-option');
      expect(flow.state.answers, isEmpty);
      flow.answer(question.id, question.options.first);
      expect(flow.nextSection(), isTrue);
      expect(flow.state.sectionIndex, 1);
      fillAnswers(flow);
      await flow.submitAnswers();
      flow.editAnswers();
      expect(flow.state.result, isNotNull);
      flow.answer(question.id, question.options.last);
      expect(flow.state.result, isNull);
      expect(flow.state.answers[question.id], question.options.last);
      expect(flow.state.answersRevision, 4);
    },
  );

  test(
    'retry retains the request identity and stays in cloud mode after network failure',
    () async {
      final cloud = FakeCloud(risk: 2);
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await reachClassification(flow);
      await flow.confirmSuggestedClass();
      fillAnswers(flow);
      cloud.failNext = 'multimodal';
      await flow.submitAnswers();
      expect(flow.state.stage, AnalysisStage.review);
      expect(flow.state.result, isNull);
      expect(flow.state.mode, ExecutionMode.cloud);
      expect(flow.canRetry, isTrue);
      await flow.retry();
      expect(flow.state.result!.risk, RiskLevel.high);
      expect(
        cloud.operations('multimodal').first.payload,
        cloud.operations('multimodal').last.payload,
      );
      expect(flow.canRetry, isFalse);
    },
  );

  test(
    'goBack owns guided navigation and preserves existing answers and results',
    () async {
      final flow = controller(FakeCloud());
      addTearDown(flow.dispose);
      expect(flow.goBack(), isFalse);
      await flow.selectImage(photo());
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.acquisition);
      expect(flow.state.original, isNull);
      await reachClassification(flow);
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.quality);
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.crop);
      expect(flow.goBack(), isFalse);
      flow.editCrop();
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.crop);
      await flow.confirmCrop();
      await flow.acceptQuality(true);
      flow.disagree();
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.classification);
      await flow.confirmSuggestedClass();
      final first = flow.state.questionnaire!.questions.first;
      flow.answer(first.id, first.options.first);
      flow.nextSection();
      expect(flow.goBack(), isTrue);
      expect(flow.state.sectionIndex, 0);
      fillAnswers(flow);
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.questionnaire);
      flow.reviewAnswers();
      await flow.submitAnswers();
      final result = flow.state.result;
      final answers = flow.state.answers;
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.questionnaire);
      expect(flow.state.result, same(result));
      expect(flow.state.answers, answers);
      expect(flow.goBack(), isTrue);
      expect(flow.state.stage, AnalysisStage.classification);
    },
  );

  test('a stale classification response cannot overwrite a new crop', () async {
    final cloud = FakeCloud();
    final flow = controller(cloud);
    addTearDown(flow.dispose);
    await flow.selectImage(photo());
    await flow.confirmImage();
    await flow.confirmCrop();
    cloud.pauseOperation = 'classify';
    final pending = flow.acceptQuality(true);
    await Future<void>.delayed(Duration.zero);
    expect(flow.state.busy, isTrue);
    expect(flow.goBack(), isFalse);
    expect(flow.state.stage, AnalysisStage.classification);
    flow.backToCrop();
    flow.editCrop();
    await flow.confirmCrop(const CropBox(.2, .2, .6, .6));
    final hash = flow.state.activeImage!.hash;
    cloud.paused!.complete();
    await pending;
    expect(flow.state.stage, AnalysisStage.quality);
    expect(flow.state.suggestedClass, isNull);
    expect(flow.state.activeImage!.hash, hash);
    expect(flow.state.cropRevision, 2);
  });

  test(
    'a new analysis ignores the previous analysis detection response',
    () async {
      final cloud = FakeCloud()..pauseOperation = 'detect';
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await flow.selectImage(photo());
      final pending = flow.confirmImage();
      await Future<void>.delayed(Duration.zero);
      expect(flow.pendingOperation, 'detect');
      final previousId = flow.state.analysisId;
      flow.newAnalysis();
      expect(flow.pendingOperation, isNull);
      cloud.paused!.complete();
      await pending;
      expect(flow.state.analysisId, isNot(previousId));
      expect(flow.state.stage, AnalysisStage.acquisition);
      expect(flow.state.activeImage, isNull);
      expect(flow.state.busy, isFalse);
      expect(
        flow.events.where((event) => event['type'] == 'operation_completed'),
        isEmpty,
      );
    },
  );

  test(
    'mismatched receipt is rejected with recovery instead of an accepted result',
    () async {
      final cloud = FakeCloud()..corruptNext = 'detect';
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await flow.selectImage(photo());
      await flow.confirmImage();
      expect(flow.state.stage, AnalysisStage.preview);
      expect(flow.state.activeImage, isNull);
      expect(flow.state.error, isNotNull);
      await flow.retry();
      expect(flow.state.stage, AnalysisStage.crop);
    },
  );

  test(
    'invalid file, absent photo and cancelled selection never upload image data',
    () async {
      final cloud = FakeCloud();
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await flow.confirmImage();
      await flow.confirmCrop();
      await flow.submitAnswers();
      await flow.selectImage(Uint8List.fromList([1, 2, 3, 4]));
      flow.pickCancelled();
      expect(flow.state.stage, AnalysisStage.acquisition);
      expect(flow.state.error, isNotNull);
      expect(cloud.calls, isEmpty);
      expect(flow.events.any((e) => e['type'] == 'input_error'), isTrue);
      expect(
        flow.events.any((e) => e['type'] == 'image_selection_cancelled'),
        isTrue,
      );
    },
  );

  test(
    'feedback delivery failure remains pending and can be retried without stopping flow',
    () async {
      final cloud = FakeCloud();
      final flow = controller(cloud);
      addTearDown(flow.dispose);
      await reachClassification(flow);
      cloud.failNext = 'feedback';
      flow.disagree();
      await Future<void>.delayed(Duration.zero);
      expect(flow.pendingFeedbackCount, 1);
      await flow.declareUncertainty();
      expect(flow.state.stage, AnalysisStage.questionnaire);
      await flow.retryPendingFeedback();
      expect(flow.pendingFeedbackCount, 0);
      expect(
        flow.events.any(
          (e) =>
              e['type'] == 'feedback_acknowledged' && e['persisted'] == false,
        ),
        isTrue,
      );
    },
  );

  test(
    'stage timing excludes pauses and JSON export contains no image or personal source fields',
    () async {
      var now = DateTime.utc(2026, 10, 29);
      final flow = controller(FakeCloud(), clock: () => now);
      addTearDown(flow.dispose);
      flow.newAnalysis();
      now = now.add(const Duration(seconds: 3));
      flow.setActive(false);
      now = now.add(const Duration(seconds: 20));
      flow.setActive(true);
      now = now.add(const Duration(seconds: 2));
      await flow.selectImage(photo(), referenceId: 'document-figure-2');
      final exit = flow.events.firstWhere((e) => e['type'] == 'stage_exited');
      expect(exit['elapsed_ms'], 25000);
      expect(exit['active_ms'], 5000);
      flow.abandon();
      final exported = flow.exportHistory(executionOrigin: 'automated_test');
      final decoded = jsonDecode(exported) as Map;
      expect(decoded['execution_origin'], 'automated_test');
      expect(exported, isNot(contains('image_base64')));
      expect(exported, isNot(contains(base64Encode(photo()))));
      expect(exported, isNot(contains('document-figure-2')));
      expect(flow.events.any((e) => e['type'] == 'analysis_abandoned'), isTrue);
    },
  );

  test(
    'home idle time is excluded and interrupted sessions survive a new analysis in memory',
    () async {
      var now = DateTime.utc(2026, 10, 29);
      final flow = controller(FakeCloud(), clock: () => now);
      addTearDown(flow.dispose);
      expect(flow.hasStarted, isFalse);
      expect(flow.events, isEmpty);
      now = now.add(const Duration(minutes: 10));
      flow.newAnalysis();
      now = now.add(const Duration(seconds: 7));
      await flow.selectImage(photo());
      final previousId = flow.state.analysisId;
      now = now.add(const Duration(seconds: 5));
      flow.newAnalysis();
      final output =
          jsonDecode(flow.exportHistory(executionOrigin: 'automated_test'))
              as Map;
      final archived = (output['previous_sessions'] as List).single as Map;
      expect(archived['analysis_id'], previousId);
      expect(archived['abandoned'], isTrue);
      final events = archived['events'] as List;
      expect(
        events.any((event) => event['type'] == 'analysis_abandoned'),
        isTrue,
      );
      expect(
        events
            .where((event) => event['type'] == 'stage_exited')
            .map((event) => event['active_ms']),
        [7000, 5000],
      );
      expect(flow.state.analysisId, isNot(previousId));
      expect(flow.archivedSessions, hasLength(1));
    },
  );

  test(
    'session provenance remains attached to each analysis across fixture and manual runs',
    () async {
      final flow = AnalysisController(
        cloud: FakeCloud(),
        executionOrigin: 'fixture:low',
      );
      addTearDown(flow.dispose);
      await flow.selectImage(photo());
      flow.newAnalysis();
      var output = jsonDecode(flow.exportHistory()) as Map;
      expect(output['execution_origin'], 'manual');
      expect(
        (output['previous_sessions'] as List).single['execution_origin'],
        'fixture:low',
      );
      expect(flow.archivedSessions.single['execution_origin'], 'fixture:low');
      flow.newAnalysis(executionOrigin: 'fixture:high');
      output = jsonDecode(flow.exportHistory()) as Map;
      expect(output['execution_origin'], 'fixture:high');
      expect(
        (output['previous_sessions'] as List).map(
          (session) => session['execution_origin'],
        ),
        ['fixture:low', 'manual'],
      );
      final withOverride =
          jsonDecode(flow.exportHistory(executionOrigin: 'automated_test'))
              as Map;
      expect(withOverride['execution_origin'], 'automated_test');
      expect(
        (withOverride['previous_sessions'] as List).map(
          (session) => session['execution_origin'],
        ),
        ['fixture:low', 'manual'],
      );
    },
  );

  test(
    'offline is explicit and random new analyses cover all classes and risks with stable retries',
    () async {
      final transport = OfflineAnalysisTransport();
      final classes = <int>{}, risks = <String>{};
      for (var i = 0; i < 90; i++) {
        final payload = <String, Object?>{
          'analysis_id': 'sample_${i.toString().padLeft(16, '0')}',
          'image_id': 'example_image_00001',
          'request_id': 'example_request_00001',
          'image_hash': 'a' * 64,
          'crop_revision': 1,
          'decision_revision': 1,
          'answers_revision': 1,
          'decision': {
            'status': 'confirmed',
            'suggested_class': 0,
            'selected_class': 0,
          },
          'questionnaire_id': 'lesion-0-demo',
          'questionnaire_version': 1,
        };
        final first = await transport.call('multimodal', payload);
        final repeat = await transport.call('multimodal', payload);
        expect(first, repeat);
        expect(first['execution_mode'], 'offline');
        risks.add(first['risk'] as String);
        classes.add(
          (await transport.call('classify', payload))['class_index'] as int,
        );
      }
      expect(classes, {0, 1, 2, 3, 4, 5});
      expect(risks, {'low', 'medium', 'high'});
    },
  );
}
