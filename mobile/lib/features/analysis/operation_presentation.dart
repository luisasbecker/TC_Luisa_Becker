/// User-facing names shared by progress and the execution history.
String operationLabel(String operation) => switch (operation) {
  'detect' => 'Localização da região',
  'focus' => 'Avaliação de foco',
  'classify' => 'Comparação da lesão',
  'questionnaire' => 'Questionário da classe',
  'multimodal' => 'Simulação de risco',
  'feedback' => 'Registro de feedback',
  _ => 'Processamento',
};
