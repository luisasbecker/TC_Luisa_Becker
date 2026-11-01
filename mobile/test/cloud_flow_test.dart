import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:pipeline_bucal/domain/pipeline.dart';
import 'package:pipeline_bucal/main.dart';
import 'package:pipeline_bucal/services/cloud_api.dart';

class TestPicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(
    Uint8List.fromList(img.encodePng(img.Image(width: 16, height: 16))),
    name: 'synthetic.png',
    mimeType: 'image/png',
  );
}

class SequenceCloud implements CloudTransport {
  final sessions = <String>[];
  final calls = <String, List<String>>{};
  final riskSequence = [1, 0, 2, 1];

  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> data,
  ) async {
    final session = data['session_id'] as String;
    if (!sessions.contains(session)) sessions.add(session);
    final sequence = sessions.indexOf(session);
    (calls[session] ??= []).add(operation);
    final index = sequence % lesionClasses.length;
    final result = <String, dynamic>{
      'api_version': '1',
      'simulation_only': true,
      'execution_mode': 'cloud',
      'session_id': session,
      'operation': operation,
      'image_hash': data['image_hash'],
      'data_stored': false,
      'feedback': [],
    };
    switch (operation) {
      case 'detect':
        final box = const CropBox(.1, .1, .9, .9);
        final crop = cropPhoto(
          base64Decode(data['image_base64'] as String),
          box,
        );
        result.addAll({
          'module': 'YoloDetectionStub',
          'detected': true,
          'box': box.toJson(),
          'crop_base64': base64Encode(crop),
          'crop_hash': sha256.convert(crop).toString(),
        });
      case 'focus':
        result.addAll({
          'module': 'FocusEvaluationStub',
          'adequate': true,
          'user_decides': true,
        });
      case 'classify':
        result.addAll({
          'module': 'CnnClassificationStub',
          'class_index': index,
        });
      case 'questionnaire':
        result.addAll({
          'module': 'QuestionnaireStub',
          'class_index': index,
          'questions': List.generate(
            3,
            (i) => {
              'id': questionIds[i],
              'prompt': 'Pergunta ${i + 1}',
              'options': answerOptions[i],
            },
          ),
        });
      case 'multimodal':
        result.addAll({
          'module': modelNames[index],
          'class_index': index,
          'risk_index': riskSequence[sequence],
          'risk_label': risks[riskSequence[sequence]],
        });
      default:
        throw StateError('Unexpected operation: $operation');
    }
    return result;
  }
}

void main() {
  testWidgets(
    'new simulation resets session and displays each cloud risk',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cloud = SequenceCloud();
      await tester.pumpWidget(
        MaterialApp(
          home: PipelineScreen(
            cloudTransport: cloud,
            imagePicker: TestPicker(),
          ),
        ),
      );

      Future<void> tap(String label) async {
        final button = find.text(label);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      for (final risk in cloud.riskSequence) {
        expect(find.text('Modo cloud • Google Cloud Run'), findsOneWidget);
        await tester.runAsync(() async {
          await tester.tap(find.text('Selecionar imagem'));
          for (var i = 0; i < 200; i++) {
            await tester.pump();
            if (find
                .text('Confira a região selecionada')
                .evaluate()
                .isNotEmpty) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          fail('Image selection did not advance');
        });
        await tester.pumpAndSettle();
        await tap('Confirmar recorte e continuar');
        await tap('Sim, continuar');
        await tap('Concordo com a classe');
        for (var i = 0; i < 3; i++) {
          final field = find.byType(DropdownButtonFormField<String>).at(i);
          await tester.ensureVisible(field);
          await tester.tap(field);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Não informado').last);
          await tester.pumpAndSettle();
        }
        await tap('Concluir simulação');
        expect(find.text(risks[risk]), findsOneWidget);
        for (var other = 0; other < risks.length; other++) {
          if (other != risk) expect(find.text(risks[other]), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tap('Iniciar nova simulação');
        await tap('Nova simulação');
      }
      expect(cloud.sessions.toSet().length, 4);
      for (final operations in cloud.calls.values) {
        expect(operations, [
          'detect',
          'focus',
          'classify',
          'questionnaire',
          'multimodal',
        ]);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
