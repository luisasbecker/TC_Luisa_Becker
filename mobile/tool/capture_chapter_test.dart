// Current Flutter UI evidence for the implementation chapter. These captures
// use local, deterministic fixtures; they do not execute HTTP or real AI models.
// Run explicitly: flutter test --no-pub tool/capture_chapter_test.dart --update-goldens
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipeline_bucal/core/services/analysis_transport.dart';
import 'package:pipeline_bucal/design_system/design_system.dart';
import 'package:pipeline_bucal/features/analysis/analysis_controller.dart';
import 'package:pipeline_bucal/features/app/bucal_shell.dart';
import 'package:pipeline_bucal/features/demo/demo_scenarios.dart';
import 'package:pipeline_bucal/features/library/reference_library.dart';

class _ChapterTransport implements AnalysisTransport {
  _ChapterTransport({required DemoScenario scenario, this.hold, this.fail}) {
    fixture.scenario = scenario;
  }
  final fixture = DemoTransport();
  final String? hold, fail;
  final gate = Completer<void>();
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, Object?> payload,
  ) async {
    if (operation == hold) await gate.future;
    if (operation == fail) {
      throw const AnalysisServiceException(
        'Não foi possível concluir esta etapa. Confira a conexão e tente novamente.',
      );
    }
    return fixture.call(operation, payload);
  }

  void release() {
    if (!gate.isCompleted) gate.complete();
  }
}

const _targets = <(String, String)>[
  ('01-inicio', 'home'),
  ('02-aquisicao', 'acquisition'),
  ('03-previsualizacao', 'preview'),
  ('04-deteccao-processando', 'detecting'),
  ('05-conferencia-recorte', 'crop'),
  ('06-editor-recorte', 'manual'),
  ('07-deteccao-sem-regiao', 'missing'),
  ('08-foco-processando', 'focusing'),
  ('09-foco-adequado', 'quality'),
  ('10-foco-inadequado', 'quality-bad'),
  ('11-classificacao-processando', 'classifying'),
  ('12-classificacao', 'classification'),
  ('13-classificacao-galeria', 'classification-gallery'),
  ('14-classes-alternativas', 'alternative'),
  ('15-opcao-incerteza', 'uncertainty-option'),
  ('16-questionario', 'questionnaire'),
  ('17-questionario-secao-2', 'questionnaire-second'),
  ('18-questionario-classe-provisoria', 'questionnaire-provisional'),
  ('19-revisao-respostas', 'review'),
  ('20-multimodal-processando', 'multimodal'),
  ('21-risco-baixo', 'risk-low'),
  ('22-risco-medio', 'risk-medium'),
  ('23-risco-alto', 'risk-high'),
  ('24-risco-classe-provisoria', 'risk-provisional'),
  ('25-conclusao', 'completed'),
  ('26-biblioteca', 'library'),
  ('27-imagem-ampliada', 'viewer'),
  ('28-sobre', 'about'),
  ('29-configuracoes', 'settings'),
  ('30-painel-demonstracao', 'demos'),
  ('31-historico', 'history'),
  ('32-arquivo-invalido', 'invalid'),
  ('33-erro-recuperavel', 'error'),
  ('34-modo-execucao', 'execution'),
  ('35-questionario-acoes', 'questionnaire-actions'),
  ('36-revisao-confirmacao', 'review-confirmation'),
  ('37-resultado-orientacoes', 'risk-guidance'),
  ('38-escuro-inicio', 'dark-home'),
  ('39-escuro-recorte', 'dark-crop'),
  ('40-escuro-resultado', 'dark-risk'),
  ('41-questionario-classe-corrigida', 'questionnaire-corrected'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'render current application states for the TCC chapter',
    (tester) async {
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await (FontLoader(
          'Inter',
        )..addFont(rootBundle.load('assets/fonts/Inter-Variable.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        await ReferenceLibrary.load();
      });
      final library = await ReferenceLibrary.load();
      final reference = library.forClass(4).first;
      final photo = (await tester.runAsync(reference.bytes))!;
      final records = <Map<String, Object?>>[];
      for (final (filename, originalTarget) in _targets) {
        final dark = originalTarget.startsWith('dark-');
        final theme = dark ? ThemeMode.dark : ThemeMode.light;
        final target = switch (originalTarget) {
          'dark-home' => 'home',
          'dark-crop' => 'crop',
          'dark-risk' => 'risk-medium',
          _ => originalTarget,
        };
        final hold = switch (target) {
          'detecting' => 'detect',
          'focusing' => 'focus',
          'classifying' => 'classify',
          'multimodal' => 'multimodal',
          _ => null,
        };
        final transport = _ChapterTransport(
          scenario: DemoScenario(
            'chapter',
            'Captura determinística do capítulo',
            '',
            detects: target != 'missing',
            focus: target != 'quality-bad',
            classIndex: 4,
            risk: target == 'risk-low'
                ? RiskLevel.low
                : target == 'risk-high' || target == 'risk-provisional'
                ? RiskLevel.high
                : RiskLevel.medium,
          ),
          hold: hold,
          fail: target == 'error' ? 'detect' : null,
        );
        var counter = 0;
        final controller = AnalysisController(
          mode: ExecutionMode.offline,
          offline: transport,
          executionOrigin: 'automated:chapter_visual_fixture',
          idFactory: () => 'chapter-${(++counter).toString().padLeft(6, '0')}',
          clock: () => DateTime.utc(2026, 11, 2, 15),
        );
        Future<void>? pending;
        final simple = {
          'home',
          'acquisition',
          'library',
          'viewer',
          'about',
          'settings',
          'demos',
          'execution',
          'invalid',
        }.contains(target);
        if (target == 'invalid') {
          await controller.selectImage(Uint8List.fromList([0, 1, 2, 3]));
        } else if (!simple) {
          await controller.selectImage(photo, referenceId: reference.id);
          if (target != 'preview') {
            if (target == 'detecting') {
              pending = controller.confirmImage();
            } else {
              await controller.confirmImage();
              if (target == 'manual') {
                controller.editCrop();
              } else if (!{'crop', 'missing', 'error'}.contains(target)) {
                if (target == 'focusing') {
                  pending = controller.confirmCrop();
                } else {
                  await controller.confirmCrop();
                  if (!{'quality', 'quality-bad'}.contains(target)) {
                    if (target == 'classifying') {
                      pending = controller.acceptQuality(true);
                    } else {
                      await controller.acceptQuality(true);
                      if ({
                        'alternative',
                        'uncertainty-option',
                      }.contains(target)) {
                        controller.disagree();
                      } else if (!{
                        'classification',
                        'classification-gallery',
                      }.contains(target)) {
                        if (target.contains('provisional')) {
                          controller.disagree();
                          await controller.declareUncertainty();
                        } else if (target == 'questionnaire-corrected') {
                          controller.disagree();
                          await controller.chooseClass(5);
                        } else {
                          await controller.confirmSuggestedClass();
                        }
                        for (final question
                            in controller.state.questionnaire!.questions) {
                          controller.answer(
                            question.id,
                            question.options.first,
                          );
                        }
                        if (target == 'questionnaire-second') {
                          controller.nextSection();
                        } else if (!{
                          'questionnaire',
                          'questionnaire-provisional',
                          'questionnaire-corrected',
                          'questionnaire-actions',
                        }.contains(target)) {
                          controller.reviewAnswers();
                          if (!{
                            'review',
                            'review-confirmation',
                          }.contains(target)) {
                            if (target == 'multimodal') {
                              pending = controller.submitAnswers();
                            } else {
                              await controller.submitAnswers();
                              if (target == 'completed' ||
                                  target == 'history') {
                                controller.finish();
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        expect(
          controller.state.error,
          target == 'invalid' || target == 'error' ? isNotNull : isNull,
          reason: filename,
        );
        final initialTab = {'library', 'viewer'}.contains(target)
            ? 2
            : {
                'home',
                'about',
                'settings',
                'demos',
                'execution',
              }.contains(target)
            ? 0
            : 1;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('chapter-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: BucalTheme.light(),
              darkTheme: BucalTheme.dark(),
              themeMode: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: BucalShell(
                key: ValueKey(filename),
                controller: controller,
                initialTab: initialTab,
                themeMode: theme,
                onThemeChanged: (_) {},
              ),
            ),
          ),
        );
        if (hold == null) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump(const Duration(milliseconds: 100));
        }
        if ({'about', 'settings', 'demos', 'execution'}.contains(target)) {
          await tester.tap(find.byTooltip('Sobre e configurações'));
          await tester.pumpAndSettle();
          if (target == 'settings') {
            await tester.ensureVisible(find.text('Tema escuro'));
          } else if (target == 'demos' || target == 'execution') {
            final button = find.text(
              target == 'demos'
                  ? 'Painel de demonstração'
                  : 'Configurar próxima análise',
            );
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            await tester.tap(button);
          }
          await tester.pumpAndSettle();
        } else if (target == 'viewer') {
          final referenceTile = find.text('Ampliar e ver fonte').first;
          await tester.ensureVisible(referenceTile);
          await tester.tap(referenceTile);
          await tester.pumpAndSettle();
        } else if (target == 'history') {
          await tester.tap(find.byTooltip('Histórico desta análise'));
          await tester.pumpAndSettle();
        }
        final scrollTarget = switch (target) {
          'classification-gallery' => 'Concordo com a classe',
          'uncertainty-option' => 'Não consigo determinar',
          'questionnaire-actions' => 'Próxima seção',
          'review-confirmation' => 'Confirmar e ver resultado',
          'risk-guidance' => 'Concluir análise',
          _ => null,
        };
        if (scrollTarget != null) {
          await tester.ensureVisible(find.text(scrollTarget));
          await tester.pumpAndSettle();
        }
        await tester.runAsync(() async {
          final context = tester.element(find.byType(MaterialApp));
          await Future.wait(
            tester
                .widgetList<Image>(find.byType(Image))
                .map((widget) => precacheImage(widget.image, context)),
          );
        });
        if (hold == null) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull, reason: filename);
        await expectLater(
          find.byKey(const ValueKey('chapter-capture')),
          matchesGoldenFile(
            '../../docs/tcc/capitulo-implementacao/figuras/$filename.png',
          ),
        );
        records.add({
          'file': '$filename.png',
          'target': target,
          'theme': theme.name,
          'stage': controller.state.stage.name,
          'busy_operation': controller.pendingOperation,
          'scroll_excerpt': scrollTarget != null || target == 'settings',
          'reference_id': simple ? null : reference.id,
        });
        final extra = switch (target) {
          'preview' => ('03b-previsualizacao-acoes', 'Usar esta imagem'),
          'crop' when !dark => (
            '05b-conferencia-recorte-acoes',
            'O recorte está adequado',
          ),
          'missing' => (
            '07b-deteccao-sem-regiao-acoes',
            'Fazer recorte manual',
          ),
          'quality' => ('09b-foco-acoes', 'A qualidade está adequada'),
          'quality-bad' => (
            '10b-foco-inadequado-acoes',
            'Imagem inadequada: enviar outra',
          ),
          'risk-provisional' => (
            '24b-resultado-aviso-incerteza',
            'CLASSE PROVISÓRIA',
          ),
          _ => null,
        };
        if (extra != null) {
          await tester.ensureVisible(find.text(extra.$2));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: extra.$1);
          await expectLater(
            find.byKey(const ValueKey('chapter-capture')),
            matchesGoldenFile(
              '../../docs/tcc/capitulo-implementacao/figuras/${extra.$1}.png',
            ),
          );
          records.add({
            'file': '${extra.$1}.png',
            'target': target,
            'theme': theme.name,
            'stage': controller.state.stage.name,
            'scroll_excerpt': true,
            'reference_id': reference.id,
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        transport.release();
        if (pending != null) await pending;
        controller.dispose();
      }
      if (autoUpdateGoldenFiles) {
        final manifest = {
          'schema_version': 1,
          'source_commit': '765c732',
          'source':
              'Rendered current Flutter widgets using the real app and controller',
          'execution': 'Local deterministic offline fixtures, no HTTP requests',
          'not_evidence_of': [
            'physical-device captures',
            'cloud execution',
            'clinical validity',
            'user evaluation',
          ],
          'viewport': {'width': 390, 'height': 844, 'device_pixel_ratio': 1},
          'reduced_motion': true,
          'clinical_images':
              'Authorized bundled article references; see mobile/assets/references/manifest.json for source, attribution, license and explicit class mapping',
          'loading_states':
              'Fixture transport paused until capture, then released',
          'history_clock':
              'Fixed 2026-11-02T15:00:00Z for reproducibility; not measured task timings',
          'captures': records,
        };
        await tester.runAsync(
          () => File('../docs/tcc/capitulo-implementacao/figuras/manifest.json')
              .writeAsString(
                '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
              ),
        );
      }
      debugDisableShadows = true;
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
