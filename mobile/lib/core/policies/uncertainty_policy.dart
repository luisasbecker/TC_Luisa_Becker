import '../models/analysis_models.dart';

abstract interface class UncertaintyPolicy {
  ClassDecision resolve(int suggestedClass);
}

/// Provisional navigation rule, not a clinical confirmation or decision rule.
class UseSuggestedClassProvisionally implements UncertaintyPolicy {
  const UseSuggestedClassProvisionally();
  @override
  ClassDecision resolve(int suggestedClass) => ClassDecision(
    status: ProfessionalDecisionStatus.uncertain,
    suggestedClass: suggestedClass,
    effectiveClass: suggestedClass,
  );
}
