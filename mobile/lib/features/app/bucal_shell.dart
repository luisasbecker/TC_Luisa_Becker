import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../design_system/design_system.dart';
import '../analysis/analysis_controller.dart';
import '../analysis/analysis_screen.dart';
import '../analysis/operation_presentation.dart';
import '../demo/demo_scenarios.dart';
import '../library/library_widgets.dart';
import '../library/reference_library.dart';

class BucalShell extends StatefulWidget {
  const BucalShell({
    super.key,
    this.controller,
    this.imagePicker,
    required this.themeMode,
    required this.onThemeChanged,
    this.initialTab = 0,
  });
  final AnalysisController? controller;
  final ImagePicker? imagePicker;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final int initialTab;
  @override
  State<BucalShell> createState() => _BucalShellState();
}

class _BucalShellState extends State<BucalShell> with WidgetsBindingObserver {
  late final DemoTransport demo = DemoTransport();
  late final AnalysisController controller =
      widget.controller ?? AnalysisController(offline: demo);
  late final ImagePicker picker = widget.imagePicker ?? ImagePicker();
  late int tab = widget.initialTab;
  final scroll = ScrollController();
  AnalysisStage? priorStage;
  int? priorSection;
  String? priorError;
  bool choosingImage = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(onState);
    controller.setActive(tab == 1);
    if (Platform.isAndroid && widget.controller == null) recoverPhoto();
  }

  void onState() {
    if (!mounted) return;
    final state = controller.state;
    final shouldReturnToStart =
        priorStage != state.stage ||
        priorSection != state.sectionIndex ||
        (state.error != null && state.error != priorError);
    priorStage = state.stage;
    priorSection = state.sectionIndex;
    priorError = state.error;
    if (shouldReturnToStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) scroll.jumpTo(0);
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      controller.setActive(state == AppLifecycleState.resumed && tab == 1);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(onState);
    if (widget.controller == null) controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  void selectTab(int value) {
    setState(() => tab = value);
    controller.setActive(value == 1);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> recoverPhoto() async {
    try {
      final lost = await picker.retrieveLostData();
      if (lost.exception != null) throw lost.exception!;
      if (lost.files?.isNotEmpty ?? false) {
        await loadFile(lost.files!.first);
        if (mounted) selectTab(1);
      }
    } catch (_) {
      controller.recordExternalError(
        'gallery',
        message: 'Não foi possível recuperar a imagem. Selecione-a novamente.',
      );
    }
  }

  Future<void> loadFile(XFile file) async {
    if (await file.length() > 25 * 1024 * 1024) {
      controller.recordExternalError(
        'gallery',
        message: 'Selecione uma imagem de até 25 MB.',
      );
      return;
    }
    await controller.selectImage(await file.readAsBytes());
  }

  Future<void> pick(ImageSource source) async {
    if (choosingImage || controller.state.busy) return;
    setState(() => choosingImage = true);
    try {
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        requestFullMetadata: false,
      );
      if (image == null) {
        controller.pickCancelled();
      } else {
        await loadFile(image);
      }
    } on PlatformException {
      controller.recordExternalError(
        'permission',
        message:
            'Não foi possível acessar a câmera ou as fotos. Confira as permissões nos Ajustes do aparelho e tente novamente.',
      );
    } catch (_) {
      controller.recordExternalError(
        source == ImageSource.camera ? 'camera' : 'gallery',
        message:
            'Não foi possível abrir a imagem. Tente selecionar outra fotografia.',
      );
    } finally {
      if (mounted) setState(() => choosingImage = false);
    }
  }

  Future<bool> confirmNew() async {
    if (controller.state.original == null ||
        controller.state.stage == AnalysisStage.completed) {
      return true;
    }
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Começar outra análise?'),
            content: const Text(
              'A análise atual será encerrada e sua imagem será descartada. O histórico permanece na memória até o aplicativo ser fechado e pode ser exportado.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Continuar análise'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Nova análise'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String get sessionOrigin =>
      demo.scenario == null ? 'manual' : 'fixture:${demo.scenario!.id}';

  Future<void> start({
    ExecutionMode mode = ExecutionMode.cloud,
    bool resetScenario = true,
  }) async {
    if (!await confirmNew() || !mounted) return;
    if (resetScenario) demo.scenario = null;
    controller.newAnalysis(mode: mode, executionOrigin: sessionOrigin);
    selectTab(1);
    if (demo.scenario?.id == 'invalid') {
      await controller.selectImage(Uint8List.fromList([0, 1, 2, 3]));
    }
  }

  Future<void> useReference(ClinicalReference reference) async {
    // Choosing a reference is also image acquisition. Preserve an explicitly
    // started demo or a replacement image in the same analysis; otherwise this
    // is a new normal (cloud) analysis, never an inherited offline scenario.
    final awaitingImage =
        controller.hasStarted &&
        controller.state.stage == AnalysisStage.acquisition &&
        controller.state.original == null;
    if (!awaitingImage) {
      if (!await confirmNew() || !mounted) return;
      demo.scenario = null;
      controller.newAnalysis(mode: ExecutionMode.cloud);
    }
    selectTab(1);
    try {
      await controller.selectImage(
        await reference.bytes(),
        referenceId: reference.id,
      );
    } catch (_) {
      controller.recordExternalError(
        'gallery',
        message: 'Não foi possível abrir esta referência. Tente novamente.',
      );
    }
  }

  Future<void> exportHistory() async {
    try {
      final render = context.findRenderObject() as RenderBox;
      await Share.shareXFiles(
        [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(controller.exportHistory())),
            mimeType: 'application/json',
          ),
        ],
        fileNameOverrides: ['pipeline_${controller.state.analysisId}.json'],
        sharePositionOrigin: render.localToGlobal(Offset.zero) & render.size,
      );
    } catch (_) {
      controller.recordExternalError(
        'share',
        message: 'Não foi possível exportar o histórico. Tente novamente.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível exportar o histórico.'),
          ),
        );
      }
    }
  }

  void goBack() {
    if (controller.state.busy) return;
    if (tab != 1) {
      selectTab(0);
      return;
    }
    if (!controller.goBack()) selectTab(0);
  }

  bool get editingCrop =>
      tab == 1 && controller.state.stage == AnalysisStage.manualCrop;

  Widget analysis() => AnalysisScreen(
    controller: controller,
    onPick: pick,
    onLibrary: () => selectTab(2),
    onNewAnalysis: start,
    onExport: exportHistory,
    onHome: () => selectTab(0),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: tab == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) goBack();
    },
    child: Scaffold(
      appBar: AppBar(
        toolbarHeight: editingCrop ? 56 : 72,
        leading: tab == 1 && controller.state.stage != AnalysisStage.acquisition
            ? IconButton(
                onPressed: controller.state.busy ? null : goBack,
                tooltip: 'Voltar à etapa anterior',
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: Text(
          editingCrop
              ? MediaQuery.textScalerOf(context).scale(14) > 22
                    ? 'Recorte'
                    : 'Ajustar recorte'
              : 'Pipeline Bucal',
        ),
        actions: [
          IconButton(
            onPressed: showHistory,
            tooltip: 'Histórico desta análise',
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            onPressed: showAbout,
            tooltip: 'Sobre e configurações',
            icon: const Icon(Icons.more_horiz_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: editingCrop,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: editingCrop ? 960 : 640),
            child: editingCrop
                ? Padding(
                    key: const ValueKey('fixed-crop-workspace'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: analysis(),
                  )
                : SingleChildScrollView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: AnimatedSwitcher(
                      duration: BucalMotion.duration(context),
                      child: KeyedSubtree(
                        key: ValueKey(tab),
                        child: switch (tab) {
                          0 => home(context),
                          1 => Column(
                            children: [
                              if (demo.scenario != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: BucalNotice(
                                    title: 'Cenário de demonstração fixo',
                                    message:
                                        '${demo.scenario!.title}\n${demo.scenario!.task}',
                                    tone: BucalNoticeTone.warning,
                                  ),
                                ),
                              if (choosingImage)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 20),
                                  child: BucalLoading(label: 'Abrindo imagem…'),
                                ),
                              analysis(),
                            ],
                          ),
                          _ => ReferenceBrowser(onUse: useReference),
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ),
      bottomNavigationBar: editingCrop
          ? null
          : BucalFloatingNav(
              items: const [
                BucalNavItem(label: 'Início', icon: Icons.home_outlined),
                BucalNavItem(
                  label: 'Análise',
                  icon: Icons.add_circle_outline_rounded,
                ),
                BucalNavItem(
                  label: 'Biblioteca',
                  icon: Icons.grid_view_rounded,
                ),
              ],
              selectedIndex: tab,
              onSelected: selectTab,
            ),
    ),
  );

  Widget home(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'PROTÓTIPO ACADÊMICO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: BucalColors.of(context).primary,
        ),
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Clareza em\ncada etapa.',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/branding/app_icon.png',
              width: 80,
              height: 80,
              semanticLabel: 'Símbolo do Pipeline Bucal',
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'Um percurso guiado para observar imagens de lesões bucais e organizar informações.',
      ),
      const SizedBox(height: 28),
      BucalCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: BucalColors.of(context).primary,
              size: 28,
            ),
            const SizedBox(height: 16),
            Text(
              'Da imagem à informação.',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Selecione uma imagem, confira cada etapa e acompanhe um resultado demonstrativo.',
            ),
            const SizedBox(height: 24),
            BucalButton(
              label:
                  controller.state.original != null &&
                      controller.state.stage != AnalysisStage.completed
                  ? 'Continuar análise'
                  : 'Nova análise',
              icon: Icons.arrow_forward_rounded,
              onPressed: () {
                if (controller.state.original != null &&
                    controller.state.stage != AnalysisStage.completed) {
                  selectTab(1);
                } else {
                  start();
                }
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      BucalCard(
        padding: const EdgeInsets.all(20),
        onTap: () => selectTab(2),
        child: Row(
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              color: BucalColors.of(context).primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conheça as referências',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Seis classes de lesões elementares',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const BucalNotice(
        title: 'Apoio à avaliação, sem diagnóstico',
        message:
            'Os resultados desta versão são simulados. A ferramenta não substitui avaliação médica.',
      ),
    ],
  );

  void showAbout() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Sobre o sistema')),
        body: BucalPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/branding/app_icon.png',
                    width: 104,
                    height: 104,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pipeline Bucal',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Projeto acadêmico de apoio à decisão clínica. Esta etapa valida o percurso das imagens e informações; todos os módulos inteligentes permanecem simulados.',
              ),
              const SizedBox(height: 24),
              const BucalNotice(
                message:
                    'Nenhum modelo real é executado ou retreinado. Os níveis de risco são sorteados por análise, sem representar a condição clínica da imagem.',
              ),
              const SizedBox(height: 28),
              Text('Aparência', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, update) => Column(
                  children: [
                    for (final (mode, label, icon) in [
                      (
                        ThemeMode.system,
                        'Acompanhar o aparelho',
                        Icons.brightness_auto_rounded,
                      ),
                      (
                        ThemeMode.light,
                        'Tema claro',
                        Icons.light_mode_outlined,
                      ),
                      (ThemeMode.dark, 'Tema escuro', Icons.dark_mode_outlined),
                    ]) ...[
                      BucalChoiceTile(
                        title: label,
                        leading: Icon(icon),
                        selected: widget.themeMode == mode,
                        onTap: () {
                          widget.onThemeChanged(mode);
                          update(() {});
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Execução', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'A cloud utiliza conexão HTTPS. O modo offline é uma demonstração local escolhida explicitamente.',
              ),
              const SizedBox(height: 16),
              BucalButton(
                label: 'Configurar próxima análise',
                kind: BucalButtonKind.secondary,
                onPressed: () {
                  Navigator.pop(context);
                  showExecution();
                },
              ),
              const SizedBox(height: 24),
              BucalButton(
                label: 'Painel de demonstração',
                kind: BucalButtonKind.tertiary,
                icon: Icons.science_outlined,
                onPressed: () {
                  Navigator.pop(context);
                  showDemos();
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Referências visuais clínicas: Gomes et al. (2023), DOI 10.3390/ijerph20053894, CC BY 4.0; Souza et al., artigo fornecido no projeto. Fontes e limitações disponíveis ao ampliar cada imagem.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void showExecution() => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: BucalMotion.duration(context),
      reverseDuration: BucalMotion.duration(context, 180),
    ),
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .9,
    ),
    builder: (context) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Como executar a próxima análise?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          BucalButton(
            label: 'Google Cloud Run',
            icon: Icons.cloud_outlined,
            onPressed: () {
              Navigator.pop(context);
              start(mode: ExecutionMode.cloud, resetScenario: true);
            },
          ),
          const SizedBox(height: 12),
          BucalButton(
            label: 'Demonstração offline',
            kind: BucalButtonKind.secondary,
            icon: Icons.phone_iphone_rounded,
            onPressed: () {
              Navigator.pop(context);
              start(mode: ExecutionMode.offline, resetScenario: true);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Os dois modos sorteiam os resultados a cada nova análise. Repetições são possíveis.',
          ),
        ],
      ),
    ),
  );

  void showDemos() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Painel de demonstração')),
        body: BucalPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BucalNotice(
                title: 'Cenários fixos de teste',
                message:
                    'Estes roteiros executam respostas locais reproduzíveis. A utilização normal do aplicativo e da cloud continua aleatória por análise.',
              ),
              const SizedBox(height: 24),
              for (final scenario in demoScenarios) ...[
                BucalCard(
                  onTap: widget.controller != null
                      ? null
                      : () async {
                          Navigator.pop(context);
                          if (!await confirmNew() || !mounted) return;
                          demo.scenario = scenario;
                          controller.newAnalysis(
                            mode: ExecutionMode.offline,
                            executionOrigin: sessionOrigin,
                          );
                          selectTab(1);
                          if (scenario.id == 'invalid') {
                            await controller.selectImage(
                              Uint8List.fromList([0, 1, 2, 3]),
                            );
                          }
                        },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scenario.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(scenario.task),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              BucalButton(
                label: 'Voltar ao sorteio normal',
                kind: BucalButtonKind.secondary,
                onPressed: () {
                  Navigator.pop(context);
                  start(mode: ExecutionMode.cloud, resetScenario: true);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  void showHistory() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Histórico da análise')),
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => BucalPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BucalNotice(
                  message:
                      'Histórico mantido apenas na memória do aplicativo. A exportação contém eventos e referências técnicas, sem fotografias ou dados identificáveis.',
                ),
                const SizedBox(height: 20),
                BucalButton(
                  label: 'Exportar histórico JSON',
                  icon: Icons.ios_share_rounded,
                  onPressed: exportHistory,
                ),
                const SizedBox(height: 20),
                if (controller.pendingFeedbackCount > 0) ...[
                  BucalNotice(
                    title: 'Feedback pendente',
                    message:
                        '${controller.pendingFeedbackCount} evento(s) aguardam confirmação da simulação.',
                    tone: BucalNoticeTone.warning,
                    action: BucalButton(
                      label: 'Tentar enviar feedback',
                      kind: BucalButtonKind.secondary,
                      onPressed: controller.retryPendingFeedback,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                for (final event in controller.events.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BucalCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eventLabel(event['type'] as String),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (event['operation'] is String)
                            Text(
                              '${operationLabel(event['operation'] as String)}'
                              '${event['execution_mode'] == 'cloud'
                                  ? ' · Google Cloud Run'
                                  : event['execution_mode'] == 'offline'
                                  ? ' · No aparelho'
                                  : ''}',
                            ),
                          if (event['type'] == 'operation_completed' &&
                              event['execution_mode'] == 'cloud')
                            const Text(
                              'Resposta da nuvem recebida e verificada.',
                            ),
                          if (event['module'] is String)
                            Text(
                              'Módulo simulado: ${event['module']}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (event['duration_ms'] is num)
                            Text(
                              'Tempo de comunicação e processamento: ${((event['duration_ms'] as num) / 1000).toStringAsFixed(2)} s',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 4),
                          Text(
                            '${event['stage']} · ${event['at']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (event['active_ms'] != null)
                            Text(
                              'Tempo ativo: ${((event['active_ms'] as num) / 1000).toStringAsFixed(1)} s',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

String eventLabel(String event) =>
    const {
      'analysis_started': 'Análise iniciada',
      'analysis_completed': 'Análise concluída',
      'analysis_abandoned': 'Análise interrompida',
      'stage_entered': 'Etapa acessada',
      'stage_exited': 'Etapa concluída',
      'image_selected': 'Imagem selecionada',
      'image_replaced': 'Troca de imagem',
      'region_detected': 'Região delimitada',
      'manual_crop_opened': 'Editor de recorte aberto',
      'crop_confirmed': 'Recorte confirmado',
      'quality_decision': 'Qualidade avaliada',
      'class_disagreed': 'Discordância registrada',
      'class_decided': 'Decisão sobre a classe',
      'class_uncertain': 'Incerteza registrada',
      'answer_changed': 'Resposta alterada',
      'operation_started': 'Processamento iniciado',
      'operation_completed': 'Processamento concluído',
      'operation_error': 'Erro de processamento',
      'input_error': 'Erro de entrada',
      'navigation_return': 'Retorno a uma etapa',
      'navigation_advanced': 'Avanço de etapa',
      'feedback_pending': 'Feedback candidato registrado',
      'feedback_acknowledged': 'Feedback recebido pelo módulo simulado',
      'task_paused': 'Atividade pausada',
      'task_resumed': 'Atividade retomada',
    }[event] ??
    event.replaceAll('_', ' ');
