import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/models/analysis_models.dart';
import '../../core/services/analysis_transport.dart';
import '../../domain/pipeline.dart' show cropPhoto;

class DemoScenario {
  const DemoScenario(
    this.id,
    this.title,
    this.task, {
    this.detects = true,
    this.focus = true,
    this.classIndex = 4,
    this.risk = RiskLevel.medium,
  });
  final String id, title, task;
  final bool detects, focus;
  final int classIndex;
  final RiskLevel risk;
}

const demoScenarios = [
  DemoScenario(
    'complete',
    '01 · Percurso completo',
    'Confirme o recorte, a qualidade e a classe. Preencha e revise as respostas.',
  ),
  DemoScenario(
    'crop-manual',
    '02 · Corrigir o recorte',
    'Rejeite a sugestão e ajuste o recorte manualmente.',
  ),
  DemoScenario(
    'crop-replace',
    '03 · Recorte e novo envio',
    'Na conferência do recorte, escolha enviar outra fotografia.',
  ),
  DemoScenario(
    'missing-manual',
    '04 · Falha e recorte manual',
    'A detecção falha. Delimite a região manualmente.',
    detects: false,
  ),
  DemoScenario(
    'missing-replace',
    '05 · Falha e novo envio',
    'A detecção falha. Envie outra fotografia e confira o reinício.',
    detects: false,
  ),
  DemoScenario(
    'quality',
    '06 · Imagem inadequada',
    'Na qualidade, escolha enviar outra imagem.',
    focus: false,
  ),
  DemoScenario(
    'agree',
    '07 · Concordar com a sugestão',
    'Confirme a classe e percorra seu questionário.',
    classIndex: 0,
  ),
  DemoScenario(
    'correct',
    '08 · Escolher outra classe',
    'Discorde e escolha outra classe. A sugestão original deve permanecer registrada.',
    classIndex: 1,
  ),
  DemoScenario(
    'uncertain',
    '09 · Registrar incerteza',
    'Discorde e escolha “Não consigo determinar”. Continue com a classe provisória.',
    classIndex: 2,
  ),
  DemoScenario(
    'low',
    '10 · Resultado de risco baixo',
    'Conclua o fluxo para verificar a apresentação de baixo risco.',
    risk: RiskLevel.low,
  ),
  DemoScenario(
    'medium',
    '11 · Resultado de risco médio',
    'Conclua o fluxo para verificar a apresentação de médio risco.',
  ),
  DemoScenario(
    'high',
    '12 · Resultado de risco alto',
    'Conclua o fluxo para verificar a apresentação de alto risco.',
    risk: RiskLevel.high,
  ),
  DemoScenario(
    'return',
    '13 · Revisar decisões',
    'Volte para alterar o recorte, a classe e as respostas. Os resultados dependentes devem ser invalidados.',
    classIndex: 3,
  ),
  DemoScenario(
    'invalid',
    '14 · Arquivo inválido',
    'Ao iniciar este cenário, o aplicativo tentará abrir uma entrada inválida e exibirá recuperação.',
  ),
  DemoScenario(
    'feedback',
    '15 · Fluxo com feedback',
    'Corrija o recorte, discorde da classe e conclua. Consulte os eventos de feedback.',
    classIndex: 5,
  ),
];

/// Test fixtures live outside the normal service. A null scenario preserves the
/// random per-analysis offline behavior; cloud is never intercepted here.
class DemoTransport implements AnalysisTransport {
  final AnalysisTransport normal = OfflineAnalysisTransport();
  DemoScenario? scenario;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    final response = await normal.call(operation, payload);
    final fixture = scenario;
    if (fixture == null) return response;
    switch (operation) {
      case 'detect':
        const box = CropBox(.18, .2, .82, .8);
        final crop = fixture.detects
            ? cropPhoto(base64Decode(payload['image_base64']! as String), box)
            : null;
        return {
          ...response,
          'detected': fixture.detects,
          'box': fixture.detects ? box.toJson() : null,
          'crop_base64': crop == null ? null : base64Encode(crop),
          'crop_hash': crop == null ? null : sha256.convert(crop).toString(),
        };
      case 'focus':
        return {...response, 'adequate': fixture.focus};
      case 'classify':
        return {
          ...response,
          'class_index': fixture.classIndex,
          'class_label': lesionClasses[fixture.classIndex],
        };
      case 'multimodal':
        return {
          ...response,
          'risk': fixture.risk.name,
          'risk_index': fixture.risk.index,
          'risk_label': riskTitles[fixture.risk.index],
        };
      default:
        return response;
    }
  }
}
