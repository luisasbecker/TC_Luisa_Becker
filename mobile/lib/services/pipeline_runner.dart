import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../domain/pipeline.dart';
import 'cloud_api.dart';

/// Network work completes and is validated before any domain transition commits.
class PipelineRunner {
  PipelineRunner(this.pipeline, {this.cloud});
  final Pipeline pipeline;
  final CloudTransport? cloud;
  bool get isCloud => cloud != null;
  Uint8List? automaticCrop;
  List<String>? questionPrompts;

  Future<Map<String, dynamic>> _call(
    String operation,
    Uint8List image, [
    Map<String, Object?> extra = const {},
  ]) async {
    final hash = sha256.convert(image).toString();
    final result = await cloud!.call(operation, {
      'session_id': pipeline.sessionId,
      'image_base64': base64Encode(image),
      'image_hash': hash,
      ...extra,
    });
    if (result['api_version'] != '1' ||
        result['simulation_only'] != true ||
        result['execution_mode'] != 'cloud' ||
        result['session_id'] != pipeline.sessionId ||
        result['operation'] != operation ||
        result['image_hash'] != hash ||
        result['data_stored'] != false ||
        result['feedback'] is! List) {
      throw const CloudFailure(
        'A resposta não corresponde a esta sessão ou imagem. Tente novamente.',
      );
    }
    return result;
  }

  void _receipt(Map<String, dynamic> result) {
    pipeline.history.add({
      'event': '${result['module']} • cloud',
      'image_hash': result['image_hash'],
      'simulation_only': true,
    });
    for (final event in result['feedback'] as List) {
      if (event is Map<String, dynamic>) {
        pipeline.feedback.add(Map<String, Object?>.from(event));
      }
    }
  }

  void _config({int? lesion, bool? focus}) {
    final old = pipeline.config;
    pipeline.config = SimulationConfig(
      detects: old.detects,
      suggestedClass: lesion ?? old.suggestedClass,
      risk: old.risk,
      focusAdequate: focus ?? old.focusAdequate,
    );
  }

  int _index(Map<String, dynamic> data, String key, int length) {
    final value = data[key];
    if (value is! int || value < 0 || value >= length) {
      throw const CloudFailure('Resultado simulado inválido. Tente novamente.');
    }
    return value;
  }

  Future<void> start(PreparedPhoto photo) async {
    if (!isCloud) {
      pipeline.start(photo);
      return;
    }
    final result = await _call('detect', photo.bytes);
    try {
      final map = result['box'] as Map;
      final box = CropBox(
        (map['left'] as num).toDouble(),
        (map['top'] as num).toDouble(),
        (map['right'] as num).toDouble(),
        (map['bottom'] as num).toDouble(),
      );
      final bytes = base64Decode(result['crop_base64'] as String);
      if (!box.valid ||
          result['detected'] != true ||
          sha256.convert(bytes).toString() != result['crop_hash']) {
        throw const FormatException('Recorte inválido');
      }
      // Decode before accepting a remote image; do not change the confirmed crop.
      preparePhoto(bytes);
      pipeline.start(photo);
      pipeline.box = box;
      automaticCrop = bytes;
      _receipt(result);
    } on CloudFailure {
      rethrow;
    } catch (_) {
      throw const CloudFailure(
        'A cloud não devolveu um recorte válido. Tente novamente.',
      );
    }
  }

  Future<void> confirmCrop(
    Uint8List bytes,
    CropBox selected, {
    required bool manual,
    bool replacement = false,
  }) async {
    Map<String, dynamic>? result;
    if (isCloud) {
      result = await _call('focus', bytes, {
        'manual': manual,
        'box': selected.toJson(),
      });
      if (result['adequate'] is! bool || result['user_decides'] != true) {
        throw const CloudFailure('Resposta de foco inválida. Tente novamente.');
      }
      _config(focus: result['adequate'] as bool);
    }
    pipeline.confirmCropBytes(
      bytes,
      selected,
      manual: manual,
      replacement: replacement,
    );
    if (result != null) _receipt(result);
  }

  Future<void> validateQuality(bool accepted) async {
    Map<String, dynamic>? result;
    if (isCloud && accepted) {
      result = await _call('classify', pipeline.activeBytes!);
      _config(lesion: _index(result, 'class_index', lesionClasses.length));
    }
    pipeline.validateQuality(accepted);
    if (result != null) _receipt(result);
  }

  Future<void> confirmClass(int selected) async {
    Map<String, dynamic>? result;
    if (isCloud) {
      result = await _call('questionnaire', pipeline.activeBytes!, {
        'class_index': selected,
        'suggested_class': pipeline.config.suggestedClass,
      });
      final questions = result['questions'];
      if (result['class_index'] != selected ||
          questions is! List ||
          questions.length != 3) {
        throw const CloudFailure('Questionário inválido. Tente novamente.');
      }
      final prompts = <String>[];
      for (var i = 0; i < 3; i++) {
        final q = questions[i];
        if (q is! Map ||
            q['id'] != questionIds[i] ||
            q['prompt'] is! String ||
            jsonEncode(q['options']) != jsonEncode(answerOptions[i])) {
          throw const CloudFailure(
            'Questionário incompatível com esta versão do app.',
          );
        }
        prompts.add(q['prompt'] as String);
      }
      questionPrompts = prompts;
    }
    pipeline.confirmClass(selected);
    if (result != null) _receipt(result);
  }

  Future<void> complete(List<String> answers) async {
    if (answers.length != 3 ||
        List.generate(
          3,
          (i) => !answerOptions[i].contains(answers[i]),
        ).any((v) => v)) {
      throw ArgumentError('Responda todas as perguntas antes de continuar.');
    }
    Map<String, dynamic>? result;
    int? receivedRisk;
    if (isCloud) {
      result = await _call('multimodal', pipeline.activeBytes!, {
        'class_index': pipeline.finalClass,
        'answers': answers,
      });
      if (result['class_index'] != pipeline.finalClass ||
          result['module'] != modelNames[pipeline.finalClass!]) {
        throw const CloudFailure(
          'A resposta não corresponde à classe confirmada.',
        );
      }
      receivedRisk = _index(result, 'risk_index', risks.length);
      if (result['risk_label'] != risks[receivedRisk]) {
        throw const CloudFailure(
          'Risco recebido inconsistente. Tente novamente.',
        );
      }
    }
    pipeline.complete(answers, cloudRisk: receivedRisk);
    if (result != null) _receipt(result);
  }
}
