import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

enum Stage {
  empty,
  crop,
  quality,
  classification,
  questionnaire,
  completed,
  rejected,
}

const lesionClasses = [
  'pápula/nódulo',
  'mácula/mancha',
  'vesícula/bolha',
  'erosão',
  'úlcera',
  'placa',
];
const risks = [
  'risco baixo de câncer',
  'risco médio de câncer',
  'risco alto de câncer',
];
const guidance =
    'Resultado simulado, sem diagnóstico. Busque avaliação médica adequada. Este sistema não substitui avaliação profissional nem exames complementares quando indicados.';
const answerOptions = [
  [
    'Menos de 2 semanas',
    'Entre 2 e 4 semanas',
    'Mais de 4 semanas',
    'Não informado',
  ],
  ['Não', 'Sim', 'Não informado'],
  ['Não', 'Sim', 'Não informado'],
];
const questionIds = ['tempo_evolucao', 'sintomas', 'mudanca_recente'];
const modelNames = [
  'PapuleNoduleMultimodalStub',
  'MaculeSpotMultimodalStub',
  'VesicleBullaMultimodalStub',
  'ErosionMultimodalStub',
  'UlcerMultimodalStub',
  'PlaqueMultimodalStub',
];

class SimulationConfig {
  const SimulationConfig({
    this.detects = true,
    this.suggestedClass = 4,
    this.risk = 1,
    this.focusAdequate = true,
  });
  final bool detects;
  final int suggestedClass;
  final int risk;
  final bool focusAdequate;
}

class CropBox {
  const CropBox(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
  bool get valid =>
      [left, top, right, bottom].every((v) => v.isFinite) &&
      left >= 0 &&
      top >= 0 &&
      right <= 1 &&
      bottom <= 1 &&
      right > left &&
      bottom > top;
  Map<String, double> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };
}

class PreparedPhoto {
  PreparedPhoto(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width, height;
}

PreparedPhoto preparePhoto(Uint8List bytes) {
  if (bytes.length > 25 * 1024 * 1024) {
    throw const FormatException('Selecione uma imagem de até 25 MB.');
  }
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException(
      'Não foi possível abrir esta imagem. Tente JPEG ou PNG.',
    );
  }
  if (decoded == null) {
    throw const FormatException(
      'Não foi possível abrir esta imagem. Tente JPEG ou PNG.',
    );
  }
  var image = img.bakeOrientation(decoded);
  if (image.width > 2560 || image.height > 2560) {
    image = image.width >= image.height
        ? img.copyResize(image, width: 2560)
        : img.copyResize(image, height: 2560);
  }
  // Copy pixels only, excluding EXIF, location and other source metadata.
  final clean = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 4,
  );
  img.compositeImage(clean, image);
  return PreparedPhoto(
    Uint8List.fromList(img.encodePng(clean)),
    clean.width,
    clean.height,
  );
}

Uint8List cropPhoto(Uint8List original, CropBox box) {
  if (!box.valid) {
    throw const FormatException('Ajuste a área de recorte dentro da imagem.');
  }
  final image = img.decodeImage(original);
  if (image == null) {
    throw const FormatException('Imagem indisponível.');
  }
  final left = (box.left * image.width).floor().clamp(0, image.width - 1);
  final top = (box.top * image.height).floor().clamp(0, image.height - 1);
  final right = (box.right * image.width).ceil().clamp(left + 1, image.width);
  final bottom = (box.bottom * image.height).ceil().clamp(
    top + 1,
    image.height,
  );
  return Uint8List.fromList(
    img.encodePng(
      img.copyCrop(
        image,
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
      ),
    ),
  );
}

class Pipeline {
  Pipeline({this.config = const SimulationConfig()});
  final SimulationConfig config;
  Stage stage = Stage.empty;
  PreparedPhoto? original;
  Uint8List? _activeBytes;
  Uint8List? get activeBytes =>
      _activeBytes == null ? null : Uint8List.fromList(_activeBytes!);
  String? activeHash;
  CropBox box = const CropBox(.1, .1, .9, .9);
  int? finalClass;
  bool manualCrop = false;
  bool detectionFailed = false;
  final List<Map<String, Object?>> history = [];
  final List<Map<String, Object?>> feedback = [];
  List<String> answers = [];
  final String sessionId = DateTime.now().microsecondsSinceEpoch.toString();

  void _require(Stage expected) {
    if (stage != expected) {
      throw StateError('Esta ação não está disponível na etapa atual.');
    }
  }

  void _record(String event, [Map<String, Object?> details = const {}]) {
    history.add({
      'event': event,
      'at': DateTime.now().toUtc().toIso8601String(),
      'image_hash': activeHash,
      ...details,
    });
  }

  void start(PreparedPhoto photo) {
    _require(Stage.empty);
    original = photo;
    _record('imagem carregada', {
      'original_hash': sha256.convert(photo.bytes).toString(),
    });
    detectionFailed = !config.detects;
    stage = detectionFailed ? Stage.rejected : Stage.crop;
    _record(
      detectionFailed
          ? 'detecção não concluída'
          : 'recorte automático simulado',
    );
  }

  void confirmCrop(CropBox selected, {required bool manual}) {
    _require(Stage.crop);
    final bytes = cropPhoto(original!.bytes, selected);
    confirmCropBytes(bytes, selected, manual: manual);
  }

  void confirmCropBytes(
    Uint8List bytes,
    CropBox selected, {
    required bool manual,
    bool replacement = false,
  }) {
    _require(Stage.crop);
    if (!selected.valid || img.decodeImage(bytes) == null) {
      throw const FormatException('Recorte inválido.');
    }
    box = selected;
    _activeBytes = Uint8List.fromList(bytes);
    activeHash = sha256.convert(_activeBytes!).toString();
    manualCrop = manual;
    if (manual) {
      feedback.add({
        'event': 'recorte manual',
        'candidate_for_curation': true,
        'automatic_retraining': false,
        'image_hash': activeHash,
        'source': replacement ? 'corrected_upload' : 'visual_crop',
        'box': selected.toJson(),
      });
    }
    stage = Stage.quality;
    _record('recorte validado', {'manual': manual, 'box': selected.toJson()});
    _record('foco simulado', {'adequate': config.focusAdequate});
  }

  void reviseCrop() {
    _require(Stage.quality);
    _record('revisão do recorte solicitada');
    stage = Stage.crop;
    _activeBytes = null;
    activeHash = null;
  }

  void validateQuality(bool accepted) {
    _require(Stage.quality);
    stage = accepted ? Stage.classification : Stage.rejected;
    _record(accepted ? 'qualidade aceita' : 'qualidade rejeitada');
    if (accepted) {
      _record('CNN simulada', {
        'suggested_class': lesionClasses[config.suggestedClass],
      });
    }
  }

  void confirmClass(int selected) {
    _require(Stage.classification);
    if (selected < 0 || selected >= lesionClasses.length) {
      throw ArgumentError('Classe inválida.');
    }
    finalClass = selected;
    if (selected != config.suggestedClass) {
      feedback.add({
        'event': 'classe corrigida',
        'suggested': lesionClasses[config.suggestedClass],
        'corrected': lesionClasses[selected],
        'image_hash': activeHash,
        'candidate_for_curation': true,
        'automatic_retraining': false,
      });
    }
    stage = Stage.questionnaire;
    _record('classe confirmada', {'class': lesionClasses[selected]});
  }

  void complete(List<String> responses) {
    _require(Stage.questionnaire);
    if (responses.length != 3 ||
        List.generate(
          3,
          (i) => !answerOptions[i].contains(responses[i]),
        ).any((v) => v)) {
      throw ArgumentError('Responda todas as perguntas antes de continuar.');
    }
    answers = List.of(responses);
    stage = Stage.completed;
    _record('multimodal simulado', {
      'model': modelNames[finalClass!],
      'risk': risks[config.risk],
    });
  }

  String summary() => const JsonEncoder.withIndent('  ').convert({
    'session_id': sessionId,
    'simulation_only': true,
    'stage': stage.name,
    'active_image_hash': activeHash,
    'manual_crop': manualCrop,
    'final_class': finalClass == null ? null : lesionClasses[finalClass!],
    'answers': {
      for (int i = 0; i < answers.length; i++) questionIds[i]: answers[i],
    },
    'result': stage == Stage.completed
        ? {
            'risk': risks[config.risk],
            'model': modelNames[finalClass!],
            'message': guidance,
          }
        : null,
    'history': history,
    'feedback': feedback,
  });
}
