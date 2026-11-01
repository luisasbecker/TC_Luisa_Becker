import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/pipeline.dart' show preparePhoto, cropPhoto;
import '../../core/events/analysis_journal.dart';
import '../../core/models/analysis_models.dart';
import '../../core/policies/uncertainty_policy.dart';
import '../../core/services/analysis_transport.dart';
export '../../core/models/analysis_models.dart';

typedef AnalysisIdFactory = String Function();

String _randomId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// All pipeline decisions live here; widgets only dispatch actions and render
/// the immutable state. An operation owns an input revision, never a screen.
class AnalysisController extends ChangeNotifier {
  AnalysisController({
    AnalysisTransport? cloud,
    AnalysisTransport? offline,
    ExecutionMode mode = ExecutionMode.cloud,
    String executionOrigin = 'manual',
    AnalysisIdFactory? idFactory,
    AnalysisClock? clock,
    UncertaintyPolicy uncertaintyPolicy =
        const UseSuggestedClassProvisionally(),
  }) : _cloud = cloud ?? HttpsAnalysisTransport(),
       _offline = offline ?? OfflineAnalysisTransport(),
       _idFactory = idFactory ?? _randomId,
       _clock = clock,
       _executionOrigin = executionOrigin,
       _uncertaintyPolicy = uncertaintyPolicy {
    _state = AnalysisState(analysisId: _idFactory(), mode: mode);
    _journal = AnalysisJournal(clock: _clock);
  }
  final AnalysisTransport _cloud, _offline;
  final AnalysisIdFactory _idFactory;
  final AnalysisClock? _clock;
  final UncertaintyPolicy _uncertaintyPolicy;
  late AnalysisState _state;
  late AnalysisJournal _journal;
  int _generation = 0;
  bool _disposed = false;
  bool _started = false;
  bool _active = true;
  String _executionOrigin;
  String? _pendingOperation;
  final List<_ArchivedJournal> _archives = [];
  Future<void> Function()? _retry;
  final List<_PendingFeedback> _pendingFeedback = [];
  AnalysisState get state => _state;
  List<Map<String, Object?>> get events => _journal.events;
  bool get canRetry => _retry != null && !state.busy;
  int get pendingFeedbackCount => _pendingFeedback.length;
  bool get hasStarted => _started;
  String get executionOrigin => _executionOrigin;

  /// The operation currently awaiting a validated reply, for truthful UI status.
  String? get pendingOperation => _pendingOperation;
  List<Map<String, Object?>> get archivedSessions =>
      List.unmodifiable(_archives.map((entry) => entry.toJson()));

  void _record(String type, [Map<String, Object?> details = const {}]) =>
      _journal.record(state, type, details);
  void _update(AnalysisState next) {
    if (_disposed) return;
    if (_started &&
        !(state.stage == AnalysisStage.completed &&
            next.stage == AnalysisStage.completed)) {
      _journal.transition(_state, next);
    }
    _state = next;
    notifyListeners();
  }

  void _cancelPendingOperation() {
    _generation++;
    _retry = null;
    _pendingOperation = null;
  }

  void _navigate(AnalysisStage stage, {bool returning = true}) {
    _cancelPendingOperation();
    _record(returning ? 'navigation_return' : 'navigation_advanced', {
      'destination': stage.name,
    });
    _update(state.copyWith(stage: stage, busy: false, error: null));
  }

  AnalysisTransport _transport(ExecutionMode mode) =>
      mode == ExecutionMode.cloud ? _cloud : _offline;

  void newAnalysis({ExecutionMode? mode, String executionOrigin = 'manual'}) {
    if (_started) {
      if (state.stage != AnalysisStage.completed && !state.abandoned) {
        _record('analysis_abandoned', {'reason': 'new_analysis'});
        _state = state.copyWith(abandoned: true, busy: false);
      }
      _journal.close(state);
      final summary = Map<String, Object?>.from(
        jsonDecode(_journal.export(state, executionOrigin: _executionOrigin))
            as Map,
      )..remove('events');
      _archives.add(_ArchivedJournal(summary, _journal));
    }
    _cancelPendingOperation();
    final next = AnalysisState(
      analysisId: _idFactory(),
      mode: mode ?? state.mode,
    );
    _journal = AnalysisJournal(clock: _clock);
    _executionOrigin = executionOrigin;
    _started = true;
    _update(next);
    _journal.setActive(state, _active);
    _record('analysis_started', {
      'execution_mode': next.mode.name,
      'execution_origin': _executionOrigin,
    });
  }

  void _ensureStarted() {
    if (_started) return;
    _started = true;
    _journal.transition(state, state);
    _journal.setActive(state, _active);
    _record('analysis_started', {
      'execution_mode': state.mode.name,
      'execution_origin': _executionOrigin,
    });
  }

  Future<void> selectImage(Uint8List bytes, {String? referenceId}) async {
    _ensureStarted();
    _cancelPendingOperation();
    try {
      final photo = preparePhoto(bytes);
      if (state.original != null) {
        _record('image_replaced', {'reason': 'selection'});
        _feedback('image_replaced', {'reason': 'selection'});
      }
      final image = AnalysisImage(
        id: _idFactory(),
        photo: photo,
        referenceId: referenceId,
      );
      _update(
        AnalysisState(
          analysisId: state.analysisId,
          mode: state.mode,
          stage: AnalysisStage.preview,
          original: image,
        ),
      );
      _record('image_selected', {
        'image_hash': image.hash,
        'source': referenceId == null ? 'device' : 'reference_library',
      });
    } catch (_) {
      _update(
        state.copyWith(
          busy: false,
          error:
              'Não foi possível abrir a imagem. Selecione um arquivo JPEG ou PNG de até 25 MB.',
        ),
      );
      _record('input_error', {
        'operation': 'select_image',
        'reason': 'invalid_image',
      });
    }
  }

  void replaceImage({String reason = 'professional_requested'}) {
    _ensureStarted();
    _cancelPendingOperation();
    _record('image_replaced', {'reason': reason});
    _feedback('image_replaced', {'reason': reason});
    _update(AnalysisState(analysisId: state.analysisId, mode: state.mode));
  }

  Map<String, Object?> _request({
    AnalysisImage? image,
    bool includePixels = true,
  }) {
    final current = image ?? state.activeImage ?? state.original;
    if (current == null) {
      throw const AnalysisServiceException(
        'Selecione uma imagem para continuar.',
      );
    }
    return {
      'analysis_id': state.analysisId,
      'image_id': state.imageId,
      'request_id': _idFactory(),
      'crop_revision': state.cropRevision,
      'decision_revision': state.decisionRevision,
      'answers_revision': state.answersRevision,
      'image_hash': current.hash,
      if (includePixels) 'image_base64': base64Encode(current.bytes),
    };
  }

  Future<void> _run(
    String operation,
    Map<String, Object?> request, {
    required AnalysisStage running,
    required AnalysisStage recover,
    required void Function(Map<String, dynamic>) apply,
  }) async {
    final ticket = ++_generation;
    final mode = state.mode;
    final startedAt = (_clock ?? DateTime.now)();
    _retry = null;
    _pendingOperation = operation;
    _update(state.copyWith(stage: running, busy: true, error: null));
    _record('operation_started', {
      'operation': operation,
      'request_id': request['request_id'],
      'execution_mode': mode.name,
    });
    try {
      final response = await _transport(mode).call(operation, request);
      if (_disposed || ticket != _generation) return;
      validateReceipt(response, request, operation, mode);
      _pendingOperation = null;
      apply(response);
      _recordFeedbackReceipts(response);
      _record('operation_completed', {
        'operation': operation,
        'request_id': request['request_id'],
        'execution_mode': mode.name,
        'module': response['module'],
        'duration_ms': (_clock ?? DateTime.now)()
            .difference(startedAt)
            .inMilliseconds
            .clamp(0, 1 << 53),
      });
    } catch (error) {
      if (_disposed || ticket != _generation) return;
      _pendingOperation = null;
      _retry = () => _run(
        operation,
        request,
        running: running,
        recover: recover,
        apply: apply,
      );
      _update(
        state.copyWith(
          stage: recover,
          busy: false,
          error: error is AnalysisServiceException
              ? error.message
              : 'Esta etapa retornou dados inválidos. Tente novamente.',
        ),
      );
      _record('operation_error', {
        'operation': operation,
        'request_id': request['request_id'],
        'execution_mode': mode.name,
        'recoverable': true,
      });
    }
  }

  Future<void> confirmImage() async {
    if (state.busy ||
        state.original == null ||
        state.stage != AnalysisStage.preview) {
      return;
    }
    final body = _request(image: state.original);
    await _run(
      'detect',
      body,
      running: AnalysisStage.detection,
      recover: AnalysisStage.preview,
      apply: (data) {
        if (data['detected'] is! bool) throw const FormatException();
        if (data['detected'] == false) {
          _update(
            state.copyWith(
              stage: AnalysisStage.crop,
              busy: false,
              detectionFound: false,
              activeImage: null,
              error: null,
            ),
          );
          _record('detection_not_found');
          _feedback('detection_not_found');
          return;
        }
        final box = data['box'] as Map;
        final roi = CropBox(
          (box['left'] as num).toDouble(),
          (box['top'] as num).toDouble(),
          (box['right'] as num).toDouble(),
          (box['bottom'] as num).toDouble(),
        );
        if (!roi.valid) throw const FormatException();
        final photo = decodeProcessedPhoto(
          data['crop_base64'] as String,
          data['crop_hash'] as String,
        );
        _update(
          state.copyWith(
            stage: AnalysisStage.crop,
            busy: false,
            detectionFound: true,
            cropBox: roi,
            activeImage: AnalysisImage(id: state.imageId!, photo: photo),
            error: null,
          ),
        );
        _record('region_detected', {'crop_hash': state.activeImage!.hash});
      },
    );
  }

  void editCrop() {
    if (state.original == null || state.busy) return;
    _navigate(AnalysisStage.manualCrop, returning: false);
    _record('manual_crop_opened');
  }

  void cancelCropEdit() {
    if (state.stage == AnalysisStage.manualCrop) _navigate(AnalysisStage.crop);
  }

  bool _sameBox(CropBox first, CropBox second) =>
      first.left == second.left &&
      first.top == second.top &&
      first.right == second.right &&
      first.bottom == second.bottom;

  Future<void> confirmCrop([CropBox? box]) async {
    if (state.busy ||
        state.original == null ||
        ![AnalysisStage.crop, AnalysisStage.manualCrop].contains(state.stage)) {
      return;
    }
    final manual = state.stage == AnalysisStage.manualCrop;
    if (!manual && state.detectionFound != true) {
      _update(
        state.copyWith(
          error: 'Defina um recorte manual ou envie outra fotografia.',
        ),
      );
      return;
    }
    final roi = box ?? state.cropBox;
    if (!roi.valid) {
      _update(
        state.copyWith(error: 'Ajuste uma região válida sobre a imagem.'),
      );
      return;
    }
    if (_sameBox(roi, state.cropBox) &&
        state.cropRevision > 0 &&
        state.qualityAdequate != null) {
      _navigate(AnalysisStage.quality, returning: false);
      return;
    }
    _cancelPendingOperation();
    try {
      final changed = manual || !_sameBox(roi, state.cropBox);
      final active = changed || state.activeImage == null
          ? AnalysisImage(
              id: state.imageId!,
              photo: preparePhoto(cropPhoto(state.original!.bytes, roi)),
            )
          : state.activeImage!;
      _update(
        state.copyWith(
          activeImage: active,
          cropBox: roi,
          manualCrop: changed,
          cropRevision: state.cropRevision + 1,
          decisionRevision: 0,
          answersRevision: 0,
          qualityAdequate: null,
          suggestedClass: null,
          decision: null,
          questionnaire: null,
          answers: const {},
          result: null,
          sectionIndex: 0,
          error: null,
        ),
      );
      _record(changed ? 'crop_corrected' : 'crop_accepted', {
        'crop_revision': state.cropRevision,
        'crop_hash': active.hash,
      });
      if (changed) {
        _feedback('crop_corrected', {
          'box': roi.toJson(),
          'candidate_for_review': true,
        });
      }
      await _run(
        'focus',
        {..._request(), 'manual': state.manualCrop, 'box': roi.toJson()},
        running: state.stage,
        recover: state.stage,
        apply: (data) {
          if (data['adequate'] is! bool || data['user_decides'] != true) {
            throw const FormatException();
          }
          _update(
            state.copyWith(
              stage: AnalysisStage.quality,
              busy: false,
              qualityAdequate: data['adequate'] as bool,
            ),
          );
        },
      );
    } catch (_) {
      _update(
        state.copyWith(
          busy: false,
          error:
              'Não foi possível criar o recorte. Ajuste a região e tente novamente.',
        ),
      );
      _record('input_error', {'operation': 'crop', 'reason': 'invalid_crop'});
    }
  }

  Future<void> acceptQuality(bool adequate) async {
    if (state.busy ||
        state.stage != AnalysisStage.quality ||
        state.activeImage == null ||
        state.cropRevision < 1) {
      return;
    }
    _record('quality_decision', {
      'adequate': adequate,
      'simulated_suggestion': state.qualityAdequate,
    });
    if (!adequate) {
      _feedback('quality_rejected');
      replaceImage(reason: 'quality_inadequate');
      return;
    }
    if (state.suggestedClass != null) {
      _navigate(AnalysisStage.classification, returning: false);
      return;
    }
    await _run(
      'classify',
      _request(),
      running: AnalysisStage.classification,
      recover: AnalysisStage.quality,
      apply: (data) {
        final index = data['class_index'];
        if (index is! int ||
            index < 0 ||
            index >= lesionClasses.length ||
            data['class_label'] != lesionClasses[index]) {
          throw const FormatException();
        }
        _update(
          state.copyWith(
            stage: AnalysisStage.classification,
            busy: false,
            suggestedClass: index,
          ),
        );
        _record('class_suggested', {'suggested_class': index});
      },
    );
  }

  void disagree() {
    if (state.busy || state.suggestedClass == null) return;
    _navigate(AnalysisStage.alternative, returning: false);
    _record('class_disagreed', {'suggested_class': state.suggestedClass});
    _feedback('class_disagreed', {'suggested_class': state.suggestedClass});
  }

  Future<void> confirmSuggestedClass() async {
    if (state.busy || state.suggestedClass == null) return;
    await _setDecision(
      ClassDecision(
        status: ProfessionalDecisionStatus.confirmed,
        suggestedClass: state.suggestedClass!,
        effectiveClass: state.suggestedClass!,
        selectedClass: state.suggestedClass,
      ),
    );
  }

  Future<void> chooseClass(int index) async {
    if (state.busy ||
        state.suggestedClass == null ||
        index < 0 ||
        index >= lesionClasses.length ||
        index == state.suggestedClass) {
      return;
    }
    await _setDecision(
      ClassDecision(
        status: ProfessionalDecisionStatus.corrected,
        suggestedClass: state.suggestedClass!,
        effectiveClass: index,
        selectedClass: index,
      ),
    );
  }

  Future<void> declareUncertainty() async {
    if (state.busy || state.suggestedClass == null) return;
    await _setDecision(_uncertaintyPolicy.resolve(state.suggestedClass!));
  }

  void _validateDecision(Map<String, dynamic> data) {
    final decision = state.decision!;
    final returned = data['decision'] as Map;
    if (data['class_index'] != decision.effectiveClass ||
        data['effective_class'] != decision.effectiveClass ||
        data['provisional'] != decision.provisional ||
        data['class_confirmed'] != !decision.provisional ||
        returned['status'] != decision.status.name ||
        returned['suggested_class'] != decision.suggestedClass ||
        returned['selected_class'] != decision.selectedClass ||
        (decision.provisional &&
            data['decision_policy'] != 'use_suggested_provisionally_v1')) {
      throw const FormatException();
    }
  }

  Future<void> _setDecision(ClassDecision decision) async {
    _cancelPendingOperation();
    final previous = state.decision;
    if (previous?.status == decision.status &&
        previous?.selectedClass == decision.selectedClass &&
        state.questionnaire != null) {
      _navigate(AnalysisStage.questionnaire, returning: false);
      return;
    }
    final sameClass = previous?.effectiveClass == decision.effectiveClass;
    _update(
      state.copyWith(
        decision: decision,
        decisionRevision: state.decisionRevision + 1,
        questionnaire: sameClass ? state.questionnaire : null,
        answers: sameClass ? state.answers : const {},
        answersRevision: sameClass ? state.answersRevision : 0,
        result: null,
        sectionIndex: 0,
        error: null,
      ),
    );
    _record('class_decision', {
      ...decision.toJson(),
      'effective_class': decision.effectiveClass,
      'provisional': decision.provisional,
    });
    if (decision.status != ProfessionalDecisionStatus.confirmed) {
      _feedback(decision.provisional ? 'class_uncertain' : 'class_corrected', {
        ...decision.toJson(),
        'effective_class': decision.effectiveClass,
        'candidate_for_review': true,
      });
    }
    final recover = state.stage;
    await _run(
      'questionnaire',
      {..._request(), 'decision': decision.toJson()},
      running: AnalysisStage.questionnaire,
      recover: recover,
      apply: (data) {
        _validateDecision(data);
        final sections = (data['sections'] as List).map((raw) {
          final section = raw as Map;
          return QuestionSection(
            id: section['id'] as String,
            title: section['title'] as String,
            questions: (section['questions'] as List).map((raw) {
              final question = raw as Map;
              final options = (question['options'] as List).cast<String>();
              if (options.isEmpty) throw const FormatException();
              return ClinicalQuestion(
                id: question['id'] as String,
                prompt: question['prompt'] as String,
                options: options,
              );
            }).toList(),
          );
        }).toList();
        final questionnaire = ClinicalQuestionnaire(
          id: data['questionnaire_id'] as String,
          version: data['questionnaire_version'] as int,
          classIndex: decision.effectiveClass,
          sections: sections,
        );
        if (questionnaire.id.isEmpty ||
            questionnaire.version < 1 ||
            sections.isEmpty ||
            sections.any((s) => s.questions.isEmpty) ||
            questionnaire.questions.map((q) => q.id).toSet().length !=
                questionnaire.questions.length) {
          throw const FormatException();
        }
        final compatible = <String, String>{
          for (final q in questionnaire.questions)
            if (q.options.contains(state.answers[q.id]))
              q.id: state.answers[q.id]!,
        };
        _update(
          state.copyWith(
            stage: AnalysisStage.questionnaire,
            busy: false,
            questionnaire: questionnaire,
            answers: compatible,
            sectionIndex: 0,
          ),
        );
      },
    );
  }

  void answer(String questionId, String value) {
    if (state.busy || state.questionnaire == null) return;
    final matching = state.questionnaire!.questions.where(
      (q) => q.id == questionId && q.options.contains(value),
    );
    if (matching.isEmpty || state.answers[questionId] == value) return;
    _cancelPendingOperation();
    _update(
      state.copyWith(
        stage:
            state.stage == AnalysisStage.result ||
                state.stage == AnalysisStage.completed
            ? AnalysisStage.questionnaire
            : state.stage,
        answers: {...state.answers, questionId: value},
        answersRevision: state.answersRevision + 1,
        result: null,
        error: null,
      ),
    );
    _record('answer_changed', {
      'questionnaire_id': state.questionnaire!.id,
      'question_id': questionId,
      'answer': value,
      'answers_revision': state.answersRevision,
    });
  }

  bool nextSection() {
    if (state.busy || state.questionnaire == null) return false;
    final section = state.questionnaire!.sections[state.sectionIndex];
    if (!section.questions.every(
      (q) => q.options.contains(state.answers[q.id]),
    )) {
      _update(
        state.copyWith(
          error: 'Responda as perguntas desta seção para continuar.',
        ),
      );
      _record('input_error', {
        'operation': 'questionnaire',
        'reason': 'missing_answers',
      });
      return false;
    }
    if (state.sectionIndex + 1 == state.questionnaire!.sections.length) {
      return reviewAnswers();
    }
    _update(state.copyWith(sectionIndex: state.sectionIndex + 1, error: null));
    _record('questionnaire_section_entered', {
      'section_index': state.sectionIndex,
    });
    return true;
  }

  void previousSection() {
    if (state.busy || state.questionnaire == null) return;
    if (state.stage == AnalysisStage.review) {
      _navigate(AnalysisStage.questionnaire);
    } else if (state.sectionIndex > 0) {
      _update(
        state.copyWith(sectionIndex: state.sectionIndex - 1, error: null),
      );
      _record('questionnaire_section_return', {
        'section_index': state.sectionIndex,
      });
    } else {
      backToClassification();
    }
  }

  void editAnswers({int sectionIndex = 0}) {
    if (state.questionnaire == null ||
        sectionIndex < 0 ||
        sectionIndex >= state.questionnaire!.sections.length) {
      return;
    }
    _navigate(AnalysisStage.questionnaire);
    _update(state.copyWith(sectionIndex: sectionIndex));
  }

  bool reviewAnswers() {
    if (state.busy || !state.canSubmit) {
      _update(
        state.copyWith(
          error: 'Complete as perguntas demonstrativas antes de revisar.',
        ),
      );
      return false;
    }
    _navigate(AnalysisStage.review, returning: false);
    _record('answers_reviewed');
    return true;
  }

  Future<void> submitAnswers() async {
    if (state.busy ||
        state.stage != AnalysisStage.review ||
        !state.canSubmit ||
        state.decision == null ||
        state.activeImage == null) {
      return;
    }
    await _run(
      'multimodal',
      {
        ..._request(),
        'decision': state.decision!.toJson(),
        'questionnaire_id': state.questionnaire!.id,
        'questionnaire_version': state.questionnaire!.version,
        'answers': state.answers,
      },
      running: AnalysisStage.multimodal,
      recover: AnalysisStage.review,
      apply: (data) {
        _validateDecision(data);
        final index = data['risk_index'];
        if (index is! int ||
            index < 0 ||
            index > 2 ||
            data['risk'] != RiskLevel.values[index].name ||
            data['risk_label'] != riskTitles[index] ||
            data['module'] != modelNames[state.effectiveClass!] ||
            data['message'] is! String ||
            data['questionnaire_id'] != state.questionnaire!.id ||
            data['questionnaire_version'] != state.questionnaire!.version) {
          throw const FormatException();
        }
        final result = SimulatedResult(
          risk: RiskLevel.values[index],
          classIndex: state.effectiveClass!,
          module: data['module'] as String,
          provisional: state.provisional,
          message: data['message'] as String,
        );
        _update(
          state.copyWith(
            stage: AnalysisStage.result,
            busy: false,
            result: result,
          ),
        );
        _record('simulated_result', {
          'risk': result.risk.name,
          'class_index': result.classIndex,
          'module': result.module,
          'provisional': result.provisional,
        });
      },
    );
  }

  /// Returns false when the shell should leave the analysis tab. Pipeline
  /// navigation and preservation of valid decisions stay outside the widgets.
  bool goBack() {
    if (state.busy) return false;
    switch (state.stage) {
      case AnalysisStage.preview:
        replaceImage(reason: 'preview_return');
      case AnalysisStage.manualCrop:
        cancelCropEdit();
      case AnalysisStage.quality:
        backToCrop();
      case AnalysisStage.classification:
        backToQuality();
      case AnalysisStage.alternative:
        backToClassification();
      case AnalysisStage.questionnaire:
        if (state.sectionIndex > 0) {
          previousSection();
        } else {
          backToClassification();
        }
      case AnalysisStage.review:
      case AnalysisStage.result:
        editAnswers();
      case AnalysisStage.acquisition:
      case AnalysisStage.crop:
      case AnalysisStage.completed:
      case AnalysisStage.detection:
      case AnalysisStage.multimodal:
        return false;
    }
    return true;
  }

  void backToClassification() {
    if (state.suggestedClass != null) _navigate(AnalysisStage.classification);
  }

  void backToCrop() {
    if (state.original != null && state.detectionFound != null) {
      _navigate(AnalysisStage.crop);
    }
  }

  void backToQuality() {
    if (state.activeImage != null && state.qualityAdequate != null) {
      _navigate(AnalysisStage.quality);
    }
  }

  void finish() {
    if (state.stage != AnalysisStage.result || state.result == null) return;
    _navigate(AnalysisStage.completed, returning: false);
    _record('analysis_completed');
    _journal.close(state);
  }

  void abandon() {
    if (!_started || state.stage == AnalysisStage.completed) return;
    _cancelPendingOperation();
    _record('analysis_abandoned', {'reason': 'explicit'});
    _update(
      state.copyWith(
        stage: AnalysisStage.completed,
        abandoned: true,
        busy: false,
        error: null,
      ),
    );
    _journal.close(state);
  }

  Future<void> retry() async {
    if (state.busy || _retry == null) return;
    _record('operation_retry');
    await _retry!();
  }

  void setActive(bool active) {
    _active = active;
    if (_started && state.stage != AnalysisStage.completed) {
      _journal.setActive(state, active);
    }
  }

  String exportHistory({String? executionOrigin}) =>
      const JsonEncoder.withIndent('  ').convert({
        ...Map<String, Object?>.from(
          jsonDecode(
                _journal.export(
                  state,
                  executionOrigin: executionOrigin ?? _executionOrigin,
                ),
              )
              as Map,
        ),
        'analysis_started': _started,
        'previous_sessions': _archives.map((entry) => entry.toJson()).toList(),
      });

  void pickCancelled() {
    _ensureStarted();
    _record('image_selection_cancelled');
  }

  void recordExternalError(String operation, {String? message}) {
    _ensureStarted();
    _record('input_error', {
      'operation':
          ['camera', 'gallery', 'share', 'permission'].contains(operation)
          ? operation
          : 'device',
      'reason': 'device_operation_failed',
    });
    _update(
      state.copyWith(
        error:
            message ??
            'Não foi possível concluir esta ação no dispositivo. Tente novamente.',
      ),
    );
  }

  void clearError() => _update(state.copyWith(error: null));

  void _recordFeedbackReceipts(Map<String, dynamic> response) {
    for (final raw in response['feedback'] as List) {
      if (raw is! Map) continue;
      // Only public simulation metadata enters the journal, never arbitrary
      // response bodies, pixels, filenames or patient data.
      final details = <String, Object?>{};
      for (final key in [
        'module',
        'target',
        'reason',
        'event_id',
        'candidate_for_curation',
        'approved_simulated',
        'clinical_validation',
        'data_stored',
      ]) {
        final value = raw[key];
        if (value is String || value is bool) details[key] = value;
      }
      final retraining = raw['retraining'];
      if (retraining is Map) {
        details['retraining_status'] = retraining['status'];
        details['model_updated'] = retraining['model_updated'] == true;
      }
      _record('intelligent_system_receipt', details);
    }
  }

  void _feedback(String type, [Map<String, Object?> details = const {}]) {
    if (state.original == null) return;
    final eventId = _idFactory();
    final feedback = _PendingFeedback(state, _journal, {
      ..._request(includePixels: false),
      'event': {'event_id': eventId, 'type': type, 'details': details},
    });
    _pendingFeedback.add(feedback);
    _journal.record(state, 'feedback_pending', {
      'event_id': eventId,
      'feedback_type': type,
    });
    unawaited(_sendFeedback(feedback));
  }

  Future<void> _sendFeedback(_PendingFeedback pending) async {
    if (pending.sending) return;
    pending.sending = true;
    try {
      final response = await _transport(
        pending.state.mode,
      ).call('feedback', pending.request);
      validateReceipt(
        response,
        pending.request,
        'feedback',
        pending.state.mode,
      );
      final event = pending.request['event']! as Map;
      if (response['received'] != true ||
          response['status'] != 'simulated_acknowledged' ||
          response['event_id'] != event['event_id']) {
        throw const FormatException();
      }
      pending.journal.record(pending.state, 'feedback_acknowledged', {
        'event_id': event['event_id'],
        'persisted': false,
      });
      _pendingFeedback.remove(pending);
    } catch (_) {
      pending.journal.record(pending.state, 'feedback_pending', {
        'reason': 'delivery_failed',
      });
    } finally {
      pending.sending = false;
      if (!_disposed && pending.state.analysisId == state.analysisId) {
        notifyListeners();
      }
    }
  }

  Future<void> retryPendingFeedback() async {
    for (final pending in List<_PendingFeedback>.of(_pendingFeedback)) {
      await _sendFeedback(pending);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _pendingOperation = null;
    if (_cloud is HttpsAnalysisTransport) _cloud.close();
    super.dispose();
  }
}

class _ArchivedJournal {
  _ArchivedJournal(this.summary, this.journal);
  final Map<String, Object?> summary;
  final AnalysisJournal journal;
  Map<String, Object?> toJson() => {...summary, 'events': journal.events};
}

class _PendingFeedback {
  _PendingFeedback(this.state, this.journal, this.request);
  final AnalysisState state;
  final AnalysisJournal journal;
  final Map<String, Object?> request;
  bool sending = false;
}
