import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../design_system/design_system.dart';
import '../library/library_widgets.dart';
import 'analysis_controller.dart';
import 'analysis_widgets.dart';
import 'operation_presentation.dart';

/// Presentation only: every pipeline transition and invalidation belongs to the
/// controller, so a visual tab change never creates or discards an analysis.
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({
    super.key,
    required this.controller,
    required this.onPick,
    required this.onLibrary,
    required this.onNewAnalysis,
    required this.onExport,
    required this.onHome,
  });
  final AnalysisController controller;
  final ValueChanged<ImageSource> onPick;
  final VoidCallback onLibrary, onNewAnalysis, onExport, onHome;
  AnalysisState get state => controller.state;
  Widget gap([double height = 16]) => SizedBox(height: height);
  Widget button(
    String label,
    VoidCallback action, {
    bool secondary = false,
    IconData? icon,
  }) => BucalButton(
    label: label,
    icon: icon,
    kind: secondary ? BucalButtonKind.secondary : BucalButtonKind.primary,
    onPressed: state.busy ? null : action,
  );
  Widget link(String label, VoidCallback action) => BucalButton(
    label: label,
    kind: BucalButtonKind.tertiary,
    onPressed: state.busy ? null : action,
  );
  Widget patient({bool original = false}) {
    final image = original ? state.original : state.activeImage;
    if (image == null) {
      return const BucalEmptyState(
        title: 'Nenhuma imagem selecionada',
        message: 'Selecione uma imagem para continuar.',
      );
    }
    return ClinicalImageView(
      bytes: image.bytes,
      imageKey: ValueKey('${image.hash}:${original ? 'original' : 'active'}'),
      label: original ? 'Imagem original' : 'Recorte em uso nesta análise',
    );
  }

  Widget provisional() => const BucalNotice(
    title: 'Classe não confirmada',
    tone: BucalNoticeTone.warning,
    message:
        'A sugestão inicial será usada provisoriamente para continuar. Sua incerteza foi registrada e não significa concordância ou validação clínica.',
  );

  (String, String, int) get heading => switch (state.stage) {
    AnalysisStage.acquisition => (
      'Selecionar imagem',
      'Uma lesão por análise. Escolha uma imagem do aparelho ou faça uma fotografia.',
      1,
    ),
    AnalysisStage.preview => (
      'Confira a imagem',
      'Verifique se esta é a imagem que deseja usar.',
      1,
    ),
    AnalysisStage.detection => (
      'Localizando a região',
      'Preparando uma sugestão de recorte para sua conferência.',
      2,
    ),
    AnalysisStage.crop =>
      state.detectionFound == false
          ? (
              'Precisamos delimitar a região',
              'A simulação não encontrou uma região de interesse.',
              2,
            )
          : (
              'Conferir recorte',
              'A região sugerida corresponde à alteração que você deseja observar?',
              2,
            ),
    AnalysisStage.manualCrop => (
      'Ajustar recorte',
      'Selecione uma única região sobre a imagem original.',
      2,
    ),
    AnalysisStage.quality => (
      'Verificar qualidade',
      'A imagem está nítida e permite observar a região selecionada?',
      3,
    ),
    AnalysisStage.classification => (
      'Comparar lesão',
      'Confira a classe sugerida e compare com as referências.',
      4,
    ),
    AnalysisStage.alternative => (
      'Qual classe é mais semelhante?',
      'Sua avaliação pode ser diferente da sugestão apresentada.',
      4,
    ),
    AnalysisStage.questionnaire => (
      'Informações clínicas',
      'Perguntas demonstrativas. O conteúdo será revisado por especialista.',
      5,
    ),
    AnalysisStage.review => (
      'Revisar informações',
      'Confira suas respostas antes de continuar.',
      5,
    ),
    AnalysisStage.multimodal => (
      'Preparando o resultado',
      'Conectando a imagem, a classe utilizada e as respostas.',
      5,
    ),
    AnalysisStage.result => (
      'Resultado da simulação',
      'Classificação de risco apresentada para fins demonstrativos.',
      6,
    ),
    AnalysisStage.completed => (
      'Análise concluída',
      'O percurso desta sessão foi registrado.',
      6,
    ),
  };

  @override
  Widget build(BuildContext context) {
    if (state.stage == AnalysisStage.manualCrop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.error != null)
            TextButton.icon(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (sheetContext) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(state.error!),
                      if (controller.canRetry) ...[
                        gap(),
                        BucalButton(
                          label: 'Tentar novamente',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            controller.retry();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              icon: const Icon(Icons.error_outline),
              label: const Text('Ver detalhes do erro'),
            ),
          Expanded(child: body(context).single),
        ],
      );
    }
    final (title, subtitle, step) = heading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                state.mode == ExecutionMode.cloud
                    ? 'SIMULAÇÃO • CLOUD'
                    : 'SIMULAÇÃO • OFFLINE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: BucalColors.of(context).primary,
                ),
              ),
            ),
            if (state.original != null &&
                state.stage != AnalysisStage.completed)
              IconButton(
                onPressed: state.busy ? null : onNewAnalysis,
                tooltip: 'Iniciar nova análise',
                icon: const Icon(Icons.add_rounded),
              ),
          ],
        ),
        gap(1),
        BucalStageHeader(
          title: title,
          subtitle: subtitle,
          step: step,
          total: 6,
        ),
        gap(24),
        if (!state.busy && receivedOperation != null) ...[
          Row(
            children: [
              Icon(
                state.mode == ExecutionMode.cloud
                    ? Icons.cloud_done_outlined
                    : Icons.phone_android_outlined,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${operationLabel(receivedOperation!)}: '
                  '${state.mode == ExecutionMode.cloud ? 'retorno recebido da nuvem' : 'simulação local concluída'}.',
                  key: const ValueKey('operation-receipt'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          gap(),
        ],
        if (state.error != null) ...[
          BucalNotice(
            title: 'Não foi possível continuar',
            message: state.error!,
            tone: BucalNoticeTone.error,
            announce: true,
            action: controller.canRetry
                ? BucalButton(
                    label: 'Tentar novamente',
                    kind: BucalButtonKind.secondary,
                    onPressed: state.busy ? null : controller.retry,
                  )
                : null,
          ),
          gap(),
        ],
        if (state.busy) ...[
          BucalLoading(
            label:
                '${operationLabel(controller.pendingOperation ?? '')} '
                '${state.mode == ExecutionMode.cloud ? 'na nuvem' : 'no aparelho'}…',
          ),
          gap(20),
        ],
        ...body(context),
      ],
    );
  }

  String? get receivedOperation => switch (state.stage) {
    AnalysisStage.crop when state.detectionFound != null => 'detect',
    AnalysisStage.quality when state.qualityAdequate != null => 'focus',
    AnalysisStage.classification when state.suggestedClass != null =>
      'classify',
    AnalysisStage.questionnaire when state.questionnaire != null =>
      'questionnaire',
    AnalysisStage.result when state.result != null => 'multimodal',
    _ => null,
  };

  List<Widget> body(BuildContext context) {
    switch (state.stage) {
      case AnalysisStage.acquisition:
        return [
          BucalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 40,
                  color: BucalColors.of(context).primary,
                ),
                gap(),
                Text(
                  'Comece pela imagem.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                gap(8),
                const Text(
                  'JPEG, PNG ou uma fotografia da câmera. Evite incluir rostos ou informações identificáveis.',
                ),
                gap(24),
                button(
                  'Selecionar imagem',
                  () => onPick(ImageSource.gallery),
                  icon: Icons.photo_library_outlined,
                ),
                gap(12),
                button(
                  'Tirar foto',
                  () => onPick(ImageSource.camera),
                  secondary: true,
                  icon: Icons.camera_alt_outlined,
                ),
              ],
            ),
          ),
          gap(16),
          link('Usar um exemplo da biblioteca', onLibrary),
          gap(20),
          const BucalNotice(
            message:
                'Este protótipo demonstra o fluxo de informações. Os módulos de análise são simulados e não produzem um diagnóstico.',
          ),
        ];
      case AnalysisStage.preview:
        return [
          patient(original: true),
          gap(20),
          BucalNotice(
            message: state.mode == ExecutionMode.cloud
                ? 'Ao continuar, esta imagem será enviada por conexão segura à cloud para executar a simulação. O serviço não armazena imagens.'
                : 'Esta análise será executada em modo demonstrativo no aparelho.',
          ),
          gap(20),
          button(
            'Usar esta imagem',
            controller.confirmImage,
            icon: Icons.arrow_forward_rounded,
          ),
          gap(12),
          button(
            'Escolher outra imagem',
            () => controller.replaceImage(reason: 'preview_replacement'),
            secondary: true,
          ),
        ];
      case AnalysisStage.detection:
        return [
          patient(original: true),
          gap(),
          const Text(
            'A sugestão é demonstrativa. Você poderá ajustar ou substituir o recorte antes de seguir.',
          ),
        ];
      case AnalysisStage.crop:
        if (state.detectionFound == false) {
          return [
            patient(original: true),
            gap(20),
            const BucalNotice(
              title: 'Nenhuma região encontrada',
              message:
                  'Faça um recorte manual ou escolha outra imagem para continuar.',
              tone: BucalNoticeTone.warning,
            ),
            gap(20),
            button(
              'Fazer recorte manual',
              controller.editCrop,
              icon: Icons.crop_rounded,
            ),
            gap(12),
            button(
              'Enviar outra fotografia',
              () => controller.replaceImage(reason: 'detection_not_found'),
              secondary: true,
            ),
          ];
        }
        return [
          if (state.original != null) _DetectionPreview(state: state),
          gap(20),
          button(
            'O recorte está adequado',
            () => controller.confirmCrop(),
            icon: Icons.check_rounded,
          ),
          gap(12),
          button(
            'Ajustar recorte manualmente',
            controller.editCrop,
            secondary: true,
            icon: Icons.crop_rounded,
          ),
          gap(8),
          link(
            'Enviar outra fotografia',
            () => controller.replaceImage(reason: 'incorrect_crop'),
          ),
        ];
      case AnalysisStage.manualCrop:
        final image = state.original;
        if (image == null) {
          return [
            const BucalEmptyState(
              title: 'Imagem indisponível',
              message: 'Selecione outra imagem para continuar.',
            ),
          ];
        }
        return [
          ImageCropPanel(
            key: ValueKey('${image.id}:${state.cropRevision}'),
            image: image,
            initialBox: state.cropBox,
            busy: state.busy,
            processingLabel: state.mode == ExecutionMode.cloud
                ? 'Verificando foco na nuvem…'
                : 'Verificando foco no aparelho…',
            onConfirm: controller.confirmCrop,
            onCancel: controller.cancelCropEdit,
          ),
        ];
      case AnalysisStage.quality:
        return [
          patient(),
          gap(20),
          BucalNotice(
            title: state.qualityAdequate == true
                ? 'Sugestão simulada: foco adequado'
                : 'Sugestão simulada: foco inadequado',
            tone: state.qualityAdequate == true
                ? BucalNoticeTone.info
                : BucalNoticeTone.warning,
            message:
                'Esta sugestão automática é fictícia e não mede a nitidez real. Confira a imagem; a decisão sobre a qualidade visual continua sendo sua.',
          ),
          gap(20),
          button(
            'A qualidade está adequada',
            () => controller.acceptQuality(true),
            icon: Icons.check_rounded,
          ),
          gap(12),
          button(
            'Imagem inadequada: enviar outra',
            () => controller.acceptQuality(false),
            secondary: true,
          ),
          gap(8),
          link('Revisar o recorte', controller.backToCrop),
        ];
      case AnalysisStage.classification:
        final index = state.suggestedClass;
        if (index == null) {
          return [
            patient(),
            gap(),
            const Text('Aguardando a sugestão simulada da classe.'),
          ];
        }
        return [
          patient(),
          gap(24),
          BucalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLASSE SUGERIDA • SIMULADA',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                gap(8),
                Text(
                  lesionClasses[index],
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                gap(12),
                const Text(
                  'A imagem apresenta características semelhantes à classe de lesão elementar indicada. Esta sugestão não é um diagnóstico clínico.',
                ),
              ],
            ),
          ),
          gap(24),
          ReferenceGallery(classIndex: index),
          gap(24),
          button(
            'Concordo com a classe',
            controller.confirmSuggestedClass,
            icon: Icons.check_rounded,
          ),
          gap(12),
          button(
            'Discordo da classificação',
            controller.disagree,
            secondary: true,
          ),
          gap(8),
          link('Revisar qualidade', controller.backToQuality),
        ];
      case AnalysisStage.alternative:
        final suggested = state.suggestedClass;
        return [
          if (suggested != null) ...[
            BucalNotice(
              title: 'Discordância registrada',
              message:
                  'Sugestão original preservada: ${lesionClasses[suggested]}. Selecione outra classe ou registre sua incerteza.',
            ),
            gap(24),
            for (var i = 0; i < lesionClasses.length; i++)
              if (i != suggested) ...[
                Text(
                  lesionClasses[i],
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                gap(12),
                ReferenceGallery(classIndex: i),
                gap(12),
                button(
                  'Selecionar ${lesionClasses[i]}',
                  () => controller.chooseClass(i),
                  secondary: true,
                ),
                gap(28),
              ],
          ],
          BucalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ainda está em dúvida?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                gap(8),
                const Text(
                  'Você pode continuar sem confirmar a classe. A sugestão inicial ficará identificada como provisória.',
                ),
                gap(20),
                button(
                  'Não consigo determinar',
                  controller.declareUncertainty,
                  icon: Icons.help_outline_rounded,
                ),
              ],
            ),
          ),
          gap(8),
          link('Voltar à sugestão', controller.backToClassification),
        ];
      case AnalysisStage.questionnaire:
        final form = state.questionnaire;
        if (form == null) {
          return [
            const Text('Preparando o questionário da classe selecionada.'),
          ];
        }
        final section = form.sections[state.sectionIndex];
        return [
          if (state.provisional) ...[provisional(), gap(20)],
          _ClassSummary(state: state),
          gap(20),
          Text(
            'Seção ${state.sectionIndex + 1} de ${form.sections.length}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          gap(8),
          Text(section.title, style: Theme.of(context).textTheme.titleLarge),
          gap(20),
          for (final question in section.questions) ...[
            BucalSectionField(
              label: question.prompt,
              child: Column(
                children: [
                  for (final option in question.options) ...[
                    BucalChoiceTile(
                      title: option,
                      selected: state.answers[question.id] == option,
                      enabled: !state.busy,
                      onTap: () => controller.answer(question.id, option),
                    ),
                    gap(8),
                  ],
                ],
              ),
            ),
            gap(16),
          ],
          button(
            state.sectionIndex == form.sections.length - 1
                ? 'Revisar respostas'
                : 'Próxima seção',
            () {
              if (state.sectionIndex == form.sections.length - 1) {
                controller.reviewAnswers();
              } else {
                controller.nextSection();
              }
            },
            icon: Icons.arrow_forward_rounded,
          ),
          gap(8),
          if (state.sectionIndex > 0)
            link('Seção anterior', controller.previousSection),
          link('Revisar a classe', controller.backToClassification),
        ];
      case AnalysisStage.review:
        final form = state.questionnaire;
        return [
          if (state.provisional) ...[provisional(), gap(20)],
          _ClassSummary(state: state),
          gap(20),
          if (form != null)
            for (var i = 0; i < form.sections.length; i++) ...[
              BucalCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      form.sections[i].title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    gap(16),
                    for (final question in form.sections[i].questions) ...[
                      Text(
                        question.prompt,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      gap(4),
                      Text(
                        state.answers[question.id] ?? 'Não respondida',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      gap(16),
                    ],
                    link(
                      'Editar seção ${i + 1}',
                      () => controller.editAnswers(sectionIndex: i),
                    ),
                  ],
                ),
              ),
              gap(16),
            ],
          const BucalNotice(
            message:
                'As respostas organizam a demonstração do fluxo. Nenhum critério clínico real será aplicado nesta simulação.',
          ),
          gap(20),
          button(
            'Confirmar e ver resultado',
            controller.submitAnswers,
            icon: Icons.arrow_forward_rounded,
          ),
          gap(8),
          link('Revisar a classe', controller.backToClassification),
        ];
      case AnalysisStage.multimodal:
        return [
          patient(),
          gap(20),
          if (state.provisional) provisional(),
          gap(),
          const Text(
            'O resultado será apenas demonstrativo, sem probabilidade ou diagnóstico clínico.',
          ),
        ];
      case AnalysisStage.result:
        final result = state.result;
        if (result == null) {
          return [
            const BucalEmptyState(
              title: 'Resultado indisponível',
              message: 'Retorne às informações e tente novamente.',
            ),
          ];
        }
        return [
          BucalRiskCard(
            risk: BucalRisk.values[result.risk.index],
            provisional: result.provisional,
          ),
          gap(20),
          _ClassSummary(state: state),
          gap(20),
          const BucalNotice(
            message:
                'Textos demonstrativos, sujeitos à revisão por especialista. Esta ferramenta não substitui avaliação médica.',
          ),
          gap(24),
          button(
            'Concluir análise',
            controller.finish,
            icon: Icons.check_rounded,
          ),
          gap(12),
          button(
            'Revisar respostas',
            () => controller.editAnswers(),
            secondary: true,
          ),
          gap(8),
          link('Iniciar nova análise', onNewAnalysis),
        ];
      case AnalysisStage.completed:
        return [
          BucalCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: BucalColors.of(context).success,
                  size: 48,
                ),
                gap(20),
                Text(
                  'Cada decisão faz parte do percurso.',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                gap(12),
                const Text(
                  'O histórico está disponível nesta sessão. Você pode exportá-lo antes de fechar o aplicativo.',
                ),
                gap(24),
                button(
                  'Exportar histórico JSON',
                  onExport,
                  secondary: true,
                  icon: Icons.ios_share_rounded,
                ),
              ],
            ),
          ),
          gap(24),
          button('Nova análise', onNewAnalysis, icon: Icons.add_rounded),
          gap(8),
          link('Voltar ao início', onHome),
        ];
    }
  }
}

class _ClassSummary extends StatelessWidget {
  const _ClassSummary({required this.state});
  final AnalysisState state;
  @override
  Widget build(BuildContext context) => BucalCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.provisional ? 'CLASSE PROVISÓRIA' : 'CLASSE UTILIZADA',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          state.effectiveClass == null
              ? 'Aguardando seleção'
              : lesionClasses[state.effectiveClass!],
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (state.decision?.status == ProfessionalDecisionStatus.corrected) ...[
          const SizedBox(height: 8),
          Text(
            'Escolha do profissional. Sugestão original: ${lesionClasses[state.suggestedClass!]}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state.provisional) ...[
          const SizedBox(height: 8),
          const Text('Não confirmada pelo profissional.'),
        ],
      ],
    ),
  );
}

class _DetectionPreview extends StatelessWidget {
  const _DetectionPreview({required this.state});
  final AnalysisState state;
  @override
  Widget build(BuildContext context) {
    final original = state.original!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: 300,
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final viewport = constraints.biggest;
                    final fitted = applyBoxFit(
                      BoxFit.contain,
                      Size(
                        original.width.toDouble(),
                        original.height.toDouble(),
                      ),
                      viewport,
                    );
                    final imageRect = Alignment.center.inscribe(
                      fitted.destination,
                      Offset.zero & viewport,
                    );
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(
                            original.bytes,
                            fit: BoxFit.contain,
                            semanticLabel:
                                'Imagem original com região sugerida',
                          ),
                        ),
                        Positioned(
                          left:
                              imageRect.left +
                              state.cropBox.left * imageRect.width,
                          top:
                              imageRect.top +
                              state.cropBox.top * imageRect.height,
                          width:
                              (state.cropBox.right - state.cropBox.left) *
                              imageRect.width,
                          height:
                              (state.cropBox.bottom - state.cropBox.top) *
                              imageRect.height,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 3),
                              color: Colors.black.withValues(alpha: .08),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Região sugerida sobre a imagem original',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
