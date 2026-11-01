import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import '../../domain/pipeline.dart' show cropPhoto, PreparedPhoto;
import '../models/analysis_models.dart';

abstract interface class AnalysisTransport {
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  );
}

class AnalysisServiceException implements Exception {
  const AnalysisServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Every request is explicit. Network errors never switch execution mode.
class HttpsAnalysisTransport implements AnalysisTransport {
  HttpsAnalysisTransport({Uri? baseUri, HttpClient? client})
    : baseUri =
          baseUri ??
          Uri.parse(
            const String.fromEnvironment(
              'CLOUD_API_URL',
              defaultValue: 'https://pipeline-bucal-qpkmvmtgra-uc.a.run.app',
            ),
          ),
      _client = client ?? HttpClient() {
    if (this.baseUri.scheme != 'https' || this.baseUri.host.isEmpty) {
      throw ArgumentError('A cloud deve usar HTTPS.');
    }
    _client.connectionTimeout = const Duration(seconds: 20);
  }
  final Uri baseUri;
  final HttpClient _client;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    try {
      return await _send(
        operation,
        payload,
      ).timeout(const Duration(seconds: 45));
    } on AnalysisServiceException {
      rethrow;
    } catch (_) {
      throw const AnalysisServiceException(
        'Não foi possível comunicar com a cloud. Verifique a conexão e tente novamente.',
      );
    }
  }

  Future<Map<String, dynamic>> _send(
    String operation,
    Map<String, Object?> payload,
  ) async {
    final request = await _client.postUrl(baseUri.resolve('/v2/$operation'));
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close();
    final bytes = BytesBuilder();
    await for (final chunk in response) {
      bytes.add(chunk);
      if (bytes.length > 16 * 1024 * 1024) {
        throw const AnalysisServiceException(
          'A resposta da cloud excedeu o limite esperado.',
        );
      }
    }
    if (response.statusCode != 200) {
      throw AnalysisServiceException(
        response.statusCode == 404
            ? 'Esta versão do fluxo ainda não está disponível na cloud. Tente novamente após a atualização do serviço.'
            : 'A cloud não concluiu esta etapa. Tente novamente.',
      );
    }
    final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (decoded is! Map<String, dynamic>) {
      throw const AnalysisServiceException(
        'A cloud enviou uma resposta inválida.',
      );
    }
    return decoded;
  }

  void close() => _client.close(force: true);
}

const envelopeFields = [
  'analysis_id',
  'image_id',
  'request_id',
  'crop_revision',
  'decision_revision',
  'answers_revision',
  'image_hash',
];

void validateReceipt(
  Map<String, dynamic> response,
  Map<String, Object?> request,
  String operation,
  ExecutionMode mode,
) {
  if (response['api_version'] != '2' ||
      response['operation'] != operation ||
      response['simulation_only'] != true ||
      response['data_stored'] != false ||
      response['execution_mode'] != mode.name ||
      response['feedback'] is! List ||
      envelopeFields.any((key) => response[key] != request[key])) {
    throw const AnalysisServiceException(
      'A resposta não corresponde à imagem e às decisões atuais. Tente novamente.',
    );
  }
}

PreparedPhoto decodeProcessedPhoto(String encoded, String expectedHash) {
  final bytes = base64Decode(encoded);
  if (bytes.isEmpty ||
      bytes.length > 12 * 1024 * 1024 ||
      sha256.convert(bytes).toString() != expectedHash) {
    throw const AnalysisServiceException(
      'O recorte recebido não pôde ser verificado.',
    );
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
    throw const AnalysisServiceException(
      'O recorte recebido não é uma imagem válida.',
    );
  }
  return PreparedPhoto(bytes, decoded.width, decoded.height);
}

/// Explicit offline demonstration, with independently sampled outputs tied to
/// a freshly random analysis ID. No clinical image/answer influences the risk.
class OfflineAnalysisTransport implements AnalysisTransport {
  int _sample(String id, String module, int length) =>
      sha256
          .convert(utf8.encode('$id:$module'))
          .bytes
          .take(4)
          .fold<int>(0, (value, byte) => (value << 8) | byte) %
      length;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    final id = payload['analysis_id']! as String;
    final receipt = <String, dynamic>{
      for (final key in envelopeFields) key: payload[key],
      'api_version': '2',
      'operation': operation,
      'simulation_only': true,
      'execution_mode': 'offline',
      'data_stored': false,
      'feedback': <Object>[],
    };
    switch (operation) {
      case 'detect':
        final found = _sample(id, 'detect', 7) != 0;
        const box = CropBox(.12, .14, .88, .86);
        final crop = found
            ? cropPhoto(base64Decode(payload['image_base64']! as String), box)
            : null;
        return {
          ...receipt,
          'detected': found,
          'box': found ? box.toJson() : null,
          'crop_base64': crop == null ? null : base64Encode(crop),
          'crop_hash': crop == null ? null : sha256.convert(crop).toString(),
        };
      case 'focus':
        return {
          ...receipt,
          'adequate': _sample(id, 'focus', 6) != 0,
          'user_decides': true,
        };
      case 'classify':
        final index = _sample(id, 'classify', 6);
        return {
          ...receipt,
          'class_index': index,
          'class_label': lesionClasses[index],
        };
      case 'questionnaire':
      case 'multimodal':
        final decision = Map<String, Object?>.from(payload['decision']! as Map);
        final provisional = decision['status'] == 'uncertain';
        final index =
            (decision['selected_class'] ?? decision['suggested_class'])! as int;
        final metadata = {
          ...receipt,
          'class_index': index,
          'effective_class': index,
          'decision': decision,
          'provisional': provisional,
          'class_confirmed': !provisional,
          'decision_policy': provisional
              ? 'use_suggested_provisionally_v1'
              : null,
        };
        if (operation == 'questionnaire') {
          return {
            ...metadata,
            'questionnaire_id': 'lesion-$index-demo',
            'questionnaire_version': 1,
            'sections': [
              {
                'id': 'context',
                'title': 'Contexto demonstrativo',
                'questions': [
                  {
                    'id': 'c${index}_context',
                    'prompt': 'Há informação sobre o início da alteração?',
                    'options': ['Sim', 'Não', 'Não informado'],
                  },
                ],
              },
              {
                'id': 'observations',
                'title': 'Observações demonstrativas',
                'questions': [
                  {
                    'id': 'c${index}_observation',
                    'prompt': 'Há relato de desconforto?',
                    'options': ['Sim', 'Não', 'Não informado'],
                  },
                  {
                    'id': 'c${index}_change',
                    'prompt': 'Foi relatada alguma mudança na alteração?',
                    'options': ['Sim', 'Não', 'Não informado'],
                  },
                ],
              },
            ],
          };
        }
        final risk = _sample(id, 'multimodal', 3);
        return {
          ...metadata,
          'risk': RiskLevel.values[risk].name,
          'risk_index': risk,
          'risk_label': riskTitles[risk],
          'module': modelNames[index],
          'questionnaire_id': payload['questionnaire_id'],
          'questionnaire_version': payload['questionnaire_version'],
          'message':
              'Classificação de risco apresentada para fins demonstrativos.',
        };
      case 'feedback':
        final event = payload['event']! as Map;
        return {
          ...receipt,
          'received': true,
          'event_id': event['event_id'],
          'status': 'simulated_acknowledged',
          'feedback': [
            {'module': 'IntelligentSystemStub'},
          ],
        };
      default:
        throw const AnalysisServiceException('Etapa desconhecida.');
    }
  }
}
