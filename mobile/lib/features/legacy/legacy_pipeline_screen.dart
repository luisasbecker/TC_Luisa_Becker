import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/pipeline.dart';
import '../../services/cloud_api.dart';
import '../../services/cloud_endpoint.dart';
import '../../services/pipeline_runner.dart';
import '../../ui/crop_editor.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({
    super.key,
    this.initialPipeline,
    this.cloudTransport,
    this.imagePicker,
  });
  final Pipeline? initialPipeline;
  final CloudTransport? cloudTransport;
  final ImagePicker? imagePicker;
  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  late Pipeline pipeline;
  late PipelineRunner runner;
  bool cloudMode = true, randomResults = true;
  Future<void> Function()? retryAction;

  void attachRunner() {
    runner = PipelineRunner(
      pipeline,
      cloud: cloudMode
          ? widget.cloudTransport ?? CloudApi(cloudEndpoint)
          : null,
    );
  }

  Future<void> step(Future<void> Function() action) async {
    retryAction = action;
    await action();
    retryAction = null;
    toTop();
  }

  late final ImagePicker picker;
  final scroll = ScrollController();
  CropBox box = const CropBox(.1, .1, .9, .9);
  bool busy = false, manual = false, disagree = false;
  String? error;
  int correctedClass = 0;
  List<String?> answers = [null, null, null];
  Uint8List? preview;
  @override
  void initState() {
    super.initState();
    picker = widget.imagePicker ?? ImagePicker();
    cloudMode = widget.initialPipeline?.executionMode != 'offline';
    pipeline = widget.initialPipeline ?? Pipeline(executionMode: 'cloud');
    attachRunner();
    if (widget.initialPipeline == null) {
      recoverPhoto();
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> recoverPhoto() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await perform(() async {
      final response = await picker.retrieveLostData();
      if (response.exception != null) {
        throw response.exception!;
      }
      if (response.files?.isNotEmpty ?? false) {
        await load(response.files!.first);
      }
    });
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on CloudFailure catch (e) {
      if (mounted) setState(() => error = e.message);
    } on PlatformException catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Não foi possível acessar a câmera ou as fotos. Confira as permissões nos Ajustes e tente novamente.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? e.message.toString()
              : 'Não foi possível concluir esta ação. Tente novamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> load(XFile file, {bool replacement = false}) async {
    if (await file.length() > 25 * 1024 * 1024) {
      throw const FormatException('Selecione uma imagem de até 25 MB.');
    }
    final prepared = await compute(preparePhoto, await file.readAsBytes());
    if (!mounted) {
      return;
    }
    await step(() async {
      if (replacement) {
        await runner.confirmCrop(
          prepared.bytes,
          const CropBox(0, 0, 1, 1),
          manual: true,
          replacement: true,
        );
      } else {
        await runner.start(prepared);
        box = pipeline.box;
        preview = runner.automaticCrop;
      }
    });
    toTop();
  }

  Future<void> pick(ImageSource source, {bool replacement = false}) =>
      perform(() async {
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          requestFullMetadata: false,
        );
        if (file != null) {
          await load(file, replacement: replacement);
        }
      });
  void toTop() {
    if (scroll.hasClients) {
      scroll.jumpTo(0);
    }
  }

  void advance(VoidCallback action) {
    setState(() {
      action();
      error = null;
      retryAction = null;
    });
    toTop();
  }

  Future<void> reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar nova simulação?'),
        content: const Text(
          'A imagem e o histórico desta sessão serão descartados. Você pode compartilhar o resumo antes de reiniciar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continuar sessão'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nova simulação'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      advance(() {
        pipeline = Pipeline(
          config: randomResults || cloudMode ? null : pipeline.config,
          executionMode: cloudMode ? 'cloud' : 'offline',
        );
        attachRunner();
        preview = null;
        manual = false;
        disagree = false;
        answers = [null, null, null];
      });
    }
  }

  Widget primary(String label, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: FilledButton(
      onPressed: busy ? null : action,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
  Widget secondary(String label, VoidCallback action) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: OutlinedButton(
      onPressed: busy ? null : action,
      child: Text(label, textAlign: TextAlign.center),
    ),
  );
  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(subtitle),
      ],
    ),
  );
  Widget photo(Uint8List bytes, {String label = 'Recorte validado em uso'}) =>
      Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                bytes,
                key: ValueKey('${pipeline.activeHash ?? bytes.length}:$label'),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                semanticLabel: label,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
        ],
      );
  Future<void> export(BuildContext buttonContext) => perform(() async {
    final render = buttonContext.findRenderObject() as RenderBox;
    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(pipeline.summary())),
          mimeType: 'application/json',
        ),
      ],
      fileNameOverrides: ['pipeline_${pipeline.sessionId}.json'],
      sharePositionOrigin: render.localToGlobal(Offset.zero) & render.size,
    );
  });
  @override
  Widget build(BuildContext context) {
    final active = pipeline.activeBytes;
    final stageNumber = switch (pipeline.stage) {
      Stage.empty => 1,
      Stage.crop => 2,
      Stage.quality => 3,
      Stage.classification => 4,
      Stage.questionnaire => 5,
      Stage.completed => 6,
      Stage.rejected => 3,
    };
    return PopScope(
      canPop: pipeline.stage == Stage.empty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) {
          reset();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pipeline Bucal'),
          actions: [
            if (pipeline.stage != Stage.empty)
              IconButton(
                onPressed: busy ? null : reset,
                tooltip: 'Nova simulação',
                icon: const Icon(Icons.restart_alt),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'PROTÓTIPO ACADÊMICO • SIMULAÇÃO',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sem IA real e sem diagnóstico. Use apenas imagens simuladas, sem dados de pacientes.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cloudMode
                        ? 'Modo cloud • Google Cloud Run'
                        : 'Demonstração offline • neste aparelho',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: stageNumber / 6),
                  const SizedBox(height: 6),
                  Text('Etapa $stageNumber de 6'),
                  const SizedBox(height: 24),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (error != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (error != null && retryAction != null)
                    secondary(
                      'Tentar novamente',
                      () => perform(() => step(retryAction!)),
                    ),
                  if (active != null) ...[
                    photo(active),
                    ExpansionTile(
                      title: const Text('Comparar com a imagem original'),
                      children: [
                        photo(
                          pipeline.original!.bytes,
                          label: 'Original — somente para comparação',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  ...stageContent(),
                  if (pipeline.stage != Stage.empty) ...[
                    const SizedBox(height: 24),
                    ExpansionTile(
                      title: const Text('Histórico da simulação'),
                      children: [
                        for (final event in pipeline.history)
                          ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            title: Text(event['event'].toString()),
                          ),
                        Builder(
                          builder: (buttonContext) => secondary(
                            'Compartilhar resumo JSON',
                            () => export(buttonContext),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> stageContent() {
    switch (pipeline.stage) {
      case Stage.empty:
        return [
          heading(
            'Comece por uma imagem',
            cloudMode
                ? 'A imagem de teste será enviada ao Google Cloud para executar o fluxo simulado. As imagens e respostas não são guardadas pelo aplicativo na cloud.'
                : 'A demonstração é executada neste aparelho, sem envio de imagens. Os resultados continuam simulados.',
          ),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Cloud'),
                icon: Icon(Icons.cloud_outlined),
              ),
              ButtonSegment(
                value: false,
                label: Text('Offline'),
                icon: Icon(Icons.phonelink_off),
              ),
            ],
            selected: {cloudMode},
            onSelectionChanged: busy
                ? null
                : (selection) => advance(() {
                    cloudMode = selection.single;
                    pipeline = Pipeline(
                      executionMode: cloudMode ? 'cloud' : 'offline',
                    );
                    attachRunner();
                    preview = null;
                  }),
          ),
          const SizedBox(height: 12),
          primary('Selecionar imagem', () => pick(ImageSource.gallery)),
          secondary('Tirar foto', () => pick(ImageSource.camera)),
          const SizedBox(height: 20),
          if (!cloudMode)
            ExpansionTile(
              title: const Text('Configuração da demonstração offline'),
              subtitle: Text(
                randomResults
                    ? 'Sorteio a cada nova simulação'
                    : 'Cenário fixo para teste',
              ),
              children: [
                SwitchListTile(
                  title: const Text('Sortear classe e risco a cada simulação'),
                  value: randomResults,
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          randomResults = value;
                          if (value) {
                            pipeline = Pipeline();
                            attachRunner();
                          }
                        }),
                ),
                SwitchListTile(
                  title: const Text('Detecção simulada bem-sucedida'),
                  value: pipeline.config.detects,
                  onChanged: busy ? null : (v) => configure(detects: v),
                ),
                SwitchListTile(
                  title: const Text('Foco interno adequado'),
                  value: pipeline.config.focusAdequate,
                  onChanged: busy ? null : (v) => configure(focus: v),
                ),
                DropdownButtonFormField<int>(
                  initialValue: pipeline.config.suggestedClass,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Classe sugerida pela CNN simulada',
                  ),
                  items: [
                    for (var i = 0; i < lesionClasses.length; i++)
                      DropdownMenuItem(value: i, child: Text(lesionClasses[i])),
                  ],
                  onChanged: busy || randomResults
                      ? null
                      : (v) => configure(lesion: v),
                ),
                DropdownButtonFormField<int>(
                  initialValue: pipeline.config.risk,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Risco simulado',
                  ),
                  items: [
                    for (var i = 0; i < risks.length; i++)
                      DropdownMenuItem(value: i, child: Text(risks[i])),
                  ],
                  onChanged: busy || randomResults
                      ? null
                      : (v) => configure(risk: v),
                ),
              ],
            ),
        ];
      case Stage.crop:
        final original = pipeline.original!;
        return [
          heading(
            manual ? 'Ajuste o recorte' : 'Confira a região selecionada',
            manual
                ? 'Arraste os cantos sobre a imagem. Arraste o centro para mover a seleção.'
                : 'A área sugerida é simulada. Confira antes de continuar.',
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: CropEditor(
                bytes: original.bytes,
                ratio: original.width / original.height,
                box: box,
                onChanged: busy
                    ? (_) {}
                    : (v) => setState(() {
                        box = v;
                        manual = true;
                        preview = null;
                      }),
              ),
            ),
          ),
          secondary(
            'Ver prévia do recorte',
            () => perform(() async {
              final selected = box;
              final bytes = await compute(_crop, (original.bytes, selected));
              if (mounted) {
                setState(() => preview = bytes);
              }
            }),
          ),
          if (preview != null)
            photo(preview!, label: 'Prévia da seleção atual'),
          primary(
            'Confirmar recorte e continuar',
            () => perform(() async {
              final selected = box;
              final wasManual = manual;
              final bytes = !wasManual && runner.automaticCrop != null
                  ? runner.automaticCrop!
                  : await compute(_crop, (original.bytes, selected));
              if (mounted) {
                await step(
                  () => runner.confirmCrop(bytes, selected, manual: wasManual),
                );
              }
            }),
          ),
          secondary(
            'Usar imagem já corrigida',
            () => pick(ImageSource.gallery, replacement: true),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    box = const CropBox(0, 0, 1, 1);
                    manual = true;
                    preview = null;
                  }),
            child: const Text('Selecionar imagem inteira'),
          ),
        ];
      case Stage.quality:
        return [
          heading(
            'A qualidade está adequada?',
            'Confira o recorte acima. A avaliação visual é sua; o módulo de foco é simulado.',
          ),
          ExpansionTile(
            title: const Text('Detalhes da simulação de foco'),
            children: [
              Text(
                pipeline.config.focusAdequate
                    ? 'Status interno: adequado'
                    : 'Status interno: inadequado',
              ),
            ],
          ),
          primary(
            'Sim, continuar',
            () => perform(() => step(() => runner.validateQuality(true))),
          ),
          secondary(
            'Ajustar recorte novamente',
            () => advance(() {
              box = pipeline.box;
              manual = true;
              preview = null;
              pipeline.reviseCrop();
            }),
          ),
          secondary(
            'Não, solicitar nova imagem',
            () => advance(() => pipeline.validateQuality(false)),
          ),
        ];
      case Stage.classification:
        return [
          heading(
            'Confira a classe sugerida',
            'Similaridade simulada: ${lesionClasses[pipeline.config.suggestedClass]}',
          ),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'EXEMPLO SIMULADO — referência sintética, sem fotografia clínica.',
              ),
            ),
          ),
          primary(
            'Concordo com a classe',
            () => perform(
              () => step(
                () => runner.confirmClass(pipeline.config.suggestedClass),
              ),
            ),
          ),
          secondary(
            'Escolher outra classe',
            () => setState(() {
              disagree = !disagree;
              correctedClass = pipeline.config.suggestedClass == 0 ? 1 : 0;
            }),
          ),
          if (disagree) ...[
            const SizedBox(height: 16),
            const Text(
              'A correção seguirá para uma avaliação simulada. Nenhum modelo será treinado nesta versão.',
            ),
            DropdownButtonFormField<int>(
              initialValue: correctedClass,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Classe corrigida'),
              items: [
                for (var i = 0; i < lesionClasses.length; i++)
                  if (i != pipeline.config.suggestedClass)
                    DropdownMenuItem(value: i, child: Text(lesionClasses[i])),
              ],
              onChanged: busy
                  ? null
                  : (v) => setState(() => correctedClass = v!),
            ),
            primary('Confirmar classe corrigida', () {
              final selected = correctedClass;
              perform(() => step(() => runner.confirmClass(selected)));
            }),
          ],
        ];
      case Stage.questionnaire:
        final label = lesionClasses[pipeline.finalClass!];
        final prompts =
            runner.questionPrompts ??
            [
              'Há quanto tempo a alteração semelhante a $label foi percebida?',
              'Há sintomas associados à alteração semelhante a $label?',
              'Foi percebida mudança recente na alteração semelhante a $label?',
            ];
        return [
          heading(
            'Questionário de $label',
            'Perguntas simuladas. O conteúdo clínico será definido por especialista.',
          ),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ${prompts[i]}'),
                  DropdownButtonFormField<String>(
                    key: ValueKey('${pipeline.sessionId}_$i'),
                    initialValue: answers[i],
                    isExpanded: true,
                    hint: const Text('Selecione uma opção'),
                    items: [
                      for (final option in answerOptions[i])
                        DropdownMenuItem(value: option, child: Text(option)),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => answers[i] = v),
                  ),
                ],
              ),
            ),
          Text(
            '${answers.whereType<String>().length} de 3 respostas preenchidas',
          ),
          primary('Concluir simulação', () {
            if (answers.contains(null)) {
              setState(
                () => error = 'Responda as três perguntas antes de continuar.',
              );
              return;
            }
            final responses = answers.cast<String>().toList();
            perform(() => step(() => runner.complete(responses)));
          }),
        ];
      case Stage.completed:
        return [
          heading('Resultado da simulação', pipeline.resultRiskLabel!),
          const Text(guidance),
          const SizedBox(height: 16),
          Text('Modelo simulado: ${modelNames[pipeline.finalClass!]}'),
          Builder(
            builder: (buttonContext) =>
                primary('Compartilhar resumo', () => export(buttonContext)),
          ),
          secondary('Iniciar nova simulação', reset),
        ];
      case Stage.rejected:
        return [
          heading(
            'Precisamos de outra imagem',
            pipeline.detectionFailed
                ? 'A detecção simulada não encontrou uma região. Inicie outra sessão ou ajuste a configuração.'
                : 'Você considerou a qualidade insuficiente. O fluxo foi encerrado antes da classificação.',
          ),
          primary('Iniciar nova simulação', reset),
        ];
    }
  }

  void configure({bool? detects, bool? focus, int? lesion, int? risk}) =>
      setState(() {
        pipeline = Pipeline(
          config: SimulationConfig(
            detects: detects ?? pipeline.config.detects,
            focusAdequate: focus ?? pipeline.config.focusAdequate,
            suggestedClass: lesion ?? pipeline.config.suggestedClass,
            risk: risk ?? pipeline.config.risk,
          ),
        );
        attachRunner();
      });
}

Uint8List _crop((Uint8List, CropBox) input) => cropPhoto(input.$1, input.$2);
