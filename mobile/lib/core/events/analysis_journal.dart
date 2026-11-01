import 'dart:convert';
import '../models/analysis_models.dart';

typedef AnalysisClock = DateTime Function();

class AnalysisJournal {
  AnalysisJournal({AnalysisClock? clock}) : _clock = clock ?? DateTime.now;
  final AnalysisClock _clock;
  final List<Map<String, Object?>> _events = [];
  DateTime? _entered, _activeSince;
  Duration _activeDuration = Duration.zero;
  AnalysisStage? _stage;
  bool _active = true;
  List<Map<String, Object?>> get events => List.unmodifiable(
    _events.map((e) => Map<String, Object?>.unmodifiable(e)),
  );

  void record(
    AnalysisState state,
    String type, [
    Map<String, Object?> details = const {},
  ]) {
    _events.add({
      'analysis_id': state.analysisId,
      'image_id': state.imageId,
      'stage': state.stage.name,
      'at': _clock().toUtc().toIso8601String(),
      'type': type,
      ...details,
    });
  }

  void transition(AnalysisState before, AnalysisState after) {
    final now = _clock();
    if (_stage == after.stage && before.analysisId == after.analysisId) return;
    close(before);
    _stage = after.stage;
    _entered = now;
    _activeDuration = Duration.zero;
    _activeSince = _active ? now : null;
    record(after, 'stage_entered');
  }

  void close(AnalysisState state) {
    final now = _clock();
    if (_entered != null) {
      final active =
          _activeDuration +
          (_activeSince == null
              ? Duration.zero
              : now.difference(_activeSince!));
      record(state, 'stage_exited', {
        'entered_at': _entered!.toUtc().toIso8601String(),
        'elapsed_ms': now
            .difference(_entered!)
            .inMilliseconds
            .clamp(0, 1 << 53),
        'active_ms': active.inMilliseconds.clamp(0, 1 << 53),
      });
    }
    _stage = null;
    _entered = null;
    _activeDuration = Duration.zero;
    _activeSince = null;
  }

  void setActive(AnalysisState state, bool value) {
    if (_active == value) return;
    final now = _clock();
    if (_activeSince != null) _activeDuration += now.difference(_activeSince!);
    _active = value;
    _activeSince = value && _entered != null ? now : null;
    record(state, value ? 'task_resumed' : 'task_paused');
  }

  String export(
    AnalysisState state, {
    String executionOrigin = 'manual',
  }) => const JsonEncoder.withIndent('  ').convert({
    'schema_version': 2,
    'analysis_id': state.analysisId,
    'simulation_only': true,
    'execution_mode': state.mode.name,
    'execution_origin': executionOrigin,
    'stage': state.stage.name,
    'abandoned': state.abandoned,
    'image_id': state.imageId,
    'active_image_hash': state.activeImage?.hash,
    'decision': state.decision == null
        ? null
        : {
            ...state.decision!.toJson(),
            'effective_class': state.effectiveClass,
            'provisional': state.provisional,
            'class_confirmed': !state.provisional,
          },
    'result': state.result == null
        ? null
        : {
            'risk': state.result!.risk.name,
            'label': state.result!.title,
            'module': state.result!.module,
            'provisional': state.result!.provisional,
          },
    'events': _events,
    'limitations':
        'In-memory only. Force-closing can lose this history; no recoverable abandonment is guaranteed.',
  });
}
