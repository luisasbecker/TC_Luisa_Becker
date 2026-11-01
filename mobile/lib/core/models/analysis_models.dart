import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../../domain/pipeline.dart' show CropBox, PreparedPhoto;
export '../../domain/pipeline.dart' show CropBox, lesionClasses, modelNames;

enum ExecutionMode { cloud, offline }

enum AnalysisStage {
  acquisition,
  preview,
  detection,
  crop,
  manualCrop,
  quality,
  classification,
  alternative,
  questionnaire,
  review,
  multimodal,
  result,
  completed,
}

enum ProfessionalDecisionStatus { confirmed, corrected, uncertain }

enum RiskLevel { low, medium, high }

const riskTitles = ['Risco baixo', 'Risco médio', 'Risco alto'];
const riskGuidance = [
  'Esta classificação demonstrativa não garante ausência de câncer. Busque avaliação médica adequada para a alteração observada.',
  'Esta classificação demonstrativa recomenda avaliação médica para investigação da alteração observada.',
  'Esta classificação demonstrativa reforça a importância de buscar avaliação médica especializada.',
];

class AnalysisImage {
  AnalysisImage({
    required this.id,
    required PreparedPhoto photo,
    this.referenceId,
  }) : bytes = Uint8List.fromList(photo.bytes).asUnmodifiableView(),
       width = photo.width,
       height = photo.height,
       hash = sha256.convert(photo.bytes).toString();
  final String id;
  final Uint8List bytes;
  final int width, height;
  final String hash;
  final String? referenceId;
}

class ClassDecision {
  const ClassDecision({
    required this.status,
    required this.suggestedClass,
    required this.effectiveClass,
    this.selectedClass,
  });
  final ProfessionalDecisionStatus status;
  final int suggestedClass, effectiveClass;
  final int? selectedClass;
  bool get provisional => status == ProfessionalDecisionStatus.uncertain;
  bool get confirmed => !provisional;
  Map<String, Object?> toJson() => {
    'status': status.name,
    'suggested_class': suggestedClass,
    'selected_class': selectedClass,
  };
}

class ClinicalQuestion {
  ClinicalQuestion({
    required this.id,
    required this.prompt,
    required List<String> options,
  }) : options = List.unmodifiable(options);
  final String id, prompt;
  final List<String> options;
}

class QuestionSection {
  QuestionSection({
    required this.id,
    required this.title,
    required List<ClinicalQuestion> questions,
  }) : questions = List.unmodifiable(questions);
  final String id, title;
  final List<ClinicalQuestion> questions;
}

class ClinicalQuestionnaire {
  ClinicalQuestionnaire({
    required this.id,
    required this.version,
    required this.classIndex,
    required List<QuestionSection> sections,
  }) : sections = List.unmodifiable(sections);
  final String id;
  final int version, classIndex;
  final List<QuestionSection> sections;
  List<ClinicalQuestion> get questions =>
      sections.expand((s) => s.questions).toList(growable: false);
  bool accepts(Map<String, String> answers) =>
      questions.every((q) => q.options.contains(answers[q.id])) &&
      answers.keys.every((id) => questions.any((q) => q.id == id));
}

class SimulatedResult {
  const SimulatedResult({
    required this.risk,
    required this.classIndex,
    required this.module,
    required this.provisional,
    required this.message,
  });
  final RiskLevel risk;
  final int classIndex;
  final String module, message;
  final bool provisional;
  String get title => riskTitles[risk.index];
  String get guidance => riskGuidance[risk.index];
}

const _unchanged = Object();

/// Immutable UI projection. Pixels and collections cannot mutate underneath a
/// request or a completed result; all transitions belong to AnalysisController.
class AnalysisState {
  AnalysisState({
    required this.analysisId,
    this.mode = ExecutionMode.cloud,
    this.stage = AnalysisStage.acquisition,
    this.original,
    this.activeImage,
    this.cropBox = const CropBox(.1, .1, .9, .9),
    this.detectionFound,
    this.qualityAdequate,
    this.suggestedClass,
    this.decision,
    this.questionnaire,
    Map<String, String> answers = const {},
    this.sectionIndex = 0,
    this.result,
    this.busy = false,
    this.error,
    this.cropRevision = 0,
    this.decisionRevision = 0,
    this.answersRevision = 0,
    this.manualCrop = false,
    this.abandoned = false,
  }) : answers = Map.unmodifiable(answers);
  final String analysisId;
  final ExecutionMode mode;
  final AnalysisStage stage;
  final AnalysisImage? original, activeImage;
  String? get imageId => original?.id;
  final CropBox cropBox;
  final bool? detectionFound, qualityAdequate;
  final int? suggestedClass;
  final ClassDecision? decision;
  final ClinicalQuestionnaire? questionnaire;
  final Map<String, String> answers;
  final int sectionIndex, cropRevision, decisionRevision, answersRevision;
  final SimulatedResult? result;
  final bool busy, manualCrop, abandoned;
  final String? error;
  int? get effectiveClass => decision?.effectiveClass;
  bool get provisional => decision?.provisional ?? false;
  bool get canSubmit => questionnaire?.accepts(answers) ?? false;
  double get progress {
    if (stage == AnalysisStage.completed) return 1;
    if (stage == AnalysisStage.result) return 1;
    if (stage == AnalysisStage.multimodal ||
        stage == AnalysisStage.review ||
        stage == AnalysisStage.questionnaire) {
      return 5 / 6;
    }
    if (stage == AnalysisStage.classification ||
        stage == AnalysisStage.alternative) {
      return 4 / 6;
    }
    if (stage == AnalysisStage.quality) return 3 / 6;
    if (stage == AnalysisStage.crop || stage == AnalysisStage.manualCrop) {
      return 2 / 6;
    }
    return 1 / 6;
  }

  AnalysisState copyWith({
    ExecutionMode? mode,
    AnalysisStage? stage,
    Object? original = _unchanged,
    Object? activeImage = _unchanged,
    CropBox? cropBox,
    Object? detectionFound = _unchanged,
    Object? qualityAdequate = _unchanged,
    Object? suggestedClass = _unchanged,
    Object? decision = _unchanged,
    Object? questionnaire = _unchanged,
    Map<String, String>? answers,
    int? sectionIndex,
    Object? result = _unchanged,
    bool? busy,
    Object? error = _unchanged,
    int? cropRevision,
    int? decisionRevision,
    int? answersRevision,
    bool? manualCrop,
    bool? abandoned,
  }) => AnalysisState(
    analysisId: analysisId,
    mode: mode ?? this.mode,
    stage: stage ?? this.stage,
    original: identical(original, _unchanged)
        ? this.original
        : original as AnalysisImage?,
    activeImage: identical(activeImage, _unchanged)
        ? this.activeImage
        : activeImage as AnalysisImage?,
    cropBox: cropBox ?? this.cropBox,
    detectionFound: identical(detectionFound, _unchanged)
        ? this.detectionFound
        : detectionFound as bool?,
    qualityAdequate: identical(qualityAdequate, _unchanged)
        ? this.qualityAdequate
        : qualityAdequate as bool?,
    suggestedClass: identical(suggestedClass, _unchanged)
        ? this.suggestedClass
        : suggestedClass as int?,
    decision: identical(decision, _unchanged)
        ? this.decision
        : decision as ClassDecision?,
    questionnaire: identical(questionnaire, _unchanged)
        ? this.questionnaire
        : questionnaire as ClinicalQuestionnaire?,
    answers: answers ?? this.answers,
    sectionIndex: sectionIndex ?? this.sectionIndex,
    result: identical(result, _unchanged)
        ? this.result
        : result as SimulatedResult?,
    busy: busy ?? this.busy,
    error: identical(error, _unchanged) ? this.error : error as String?,
    cropRevision: cropRevision ?? this.cropRevision,
    decisionRevision: decisionRevision ?? this.decisionRevision,
    answersRevision: answersRevision ?? this.answersRevision,
    manualCrop: manualCrop ?? this.manualCrop,
    abandoned: abandoned ?? this.abandoned,
  );
}
