import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'domain/pipeline.dart';
import 'ui/crop_editor.dart';

void main() => runApp(const PipelineApp());

class PipelineApp extends StatelessWidget {
  const PipelineApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pipeline Bucal',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF4B4B)),
      scaffoldBackgroundColor: const Color(0xFFF8F9FB),
      useMaterial3: true,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
    ),
    home: const PipelineScreen(),
  );
}

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key, this.initialPipeline});
  final Pipeline? initialPipeline;
  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  late Pipeline pipeline;
  final picker = ImagePicker();
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
    pipeline = widget.initialPipeline ?? Pipeline();
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
    setState(() {
      if (replacement) {
        pipeline.confirmCropBytes(
          prepared.bytes,
          const CropBox(0, 0, 1, 1),
          manual: true,
          replacement: true,
        );
      } else {
        pipeline.start(prepared);
        box = pipeline.box;
      }
    });
    toTop();
  }

  Future<void> pick(ImageSource source, {bool replacement = false}) =>
      perform(() async {
        final file = await picker.pickImage(
          source: source,
          maxWidth: 2560,
          maxHeight: 2560,
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
        pipeline = Pipeline(config: pipeline.config);
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
            'Escolha uma imagem de teste ou use a câmera. O fluxo funciona localmente no aparelho.',
          ),
          primary('Selecionar imagem', () => pick(ImageSource.gallery)),
          secondary('Tirar foto', () => pick(ImageSource.camera)),
          const SizedBox(height: 20),
          ExpansionTile(
            title: const Text('Configuração da simulação'),
            subtitle: const Text('Resultados fixos, sem análise clínica'),
            children: [
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
                onChanged: busy ? null : (v) => configure(lesion: v),
              ),
              DropdownButtonFormField<int>(
                initialValue: pipeline.config.risk,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Risco simulado'),
                items: [
                  for (var i = 0; i < risks.length; i++)
                    DropdownMenuItem(value: i, child: Text(risks[i])),
                ],
                onChanged: busy ? null : (v) => configure(risk: v),
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
              final bytes = await compute(_crop, (original.bytes, selected));
              if (mounted) {
                advance(
                  () => pipeline.confirmCropBytes(
                    bytes,
                    selected,
                    manual: wasManual,
                  ),
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
            () => advance(() => pipeline.validateQuality(true)),
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
            () => advance(
              () => pipeline.confirmClass(pipeline.config.suggestedClass),
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
              'A correção será registrada para curadoria futura. Não há retreinamento automático.',
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
            primary(
              'Confirmar classe corrigida',
              () => advance(() => pipeline.confirmClass(correctedClass)),
            ),
          ],
        ];
      case Stage.questionnaire:
        final label = lesionClasses[pipeline.finalClass!];
        final prompts = [
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
            advance(() => pipeline.complete(answers.cast<String>()));
          }),
        ];
      case Stage.completed:
        return [
          heading('Resultado da simulação', risks[pipeline.config.risk]),
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
      setState(
        () => pipeline = Pipeline(
          config: SimulationConfig(
            detects: detects ?? pipeline.config.detects,
            focusAdequate: focus ?? pipeline.config.focusAdequate,
            suggestedClass: lesion ?? pipeline.config.suggestedClass,
            risk: risk ?? pipeline.config.risk,
          ),
        ),
      );
}

Uint8List _crop((Uint8List, CropBox) input) => cropPhoto(input.$1, input.$2);
