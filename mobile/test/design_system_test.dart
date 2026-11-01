import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pipeline_bucal/design_system/design_system.dart';

Widget _app(
  Widget child, {
  bool dark = false,
  double textScale = 1,
  bool reduceMotion = false,
  Widget? navigation,
}) => MaterialApp(
  theme: dark ? BucalTheme.dark() : BucalTheme.light(),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduceMotion,
      ),
      child: Scaffold(
        body: BucalPage(child: child),
        bottomNavigationBar: navigation,
      ),
    ),
  ),
);

void main() {
  test('themes use separate semantic surfaces and the supplied identity', () {
    final light = BucalTheme.light().extension<BucalColors>()!;
    final dark = BucalTheme.dark().extension<BucalColors>()!;
    expect(light.primary, const Color(0xFF904A46));
    expect(light.background, const Color(0xFFFFF8F7));
    expect(dark.background, const Color(0xFF181313));
    expect(dark.surface, isNot(dark.background));
    expect(dark.surfaceRaised, isNot(dark.surface));
    expect(dark.textPrimary, const Color(0xFFF8F9FB));
  });

  for (final dark in [false, true]) {
    testWidgets('components fit a narrow phone with large text; dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BucalStageHeader(
                title: 'Conferir a região selecionada',
                step: 2,
                total: 6,
                subtitle: 'Uma lesão por análise. Você pode ajustar a imagem.',
              ),
              const SizedBox(height: 24),
              BucalButton(
                label: 'Confirmar recorte e continuar',
                icon: Icons.check,
                onPressed: () {},
              ),
              const SizedBox(height: 16),
              BucalChoiceTile(
                title: 'Não consigo determinar',
                subtitle: 'Continuar com a classe provisória.',
                selected: true,
                onTap: () {},
              ),
              const SizedBox(height: 16),
              const BucalNotice(
                title: 'Demonstração acadêmica',
                message: 'Este fluxo não estabelece um diagnóstico clínico.',
              ),
              const SizedBox(height: 16),
              const BucalRiskCard(risk: BucalRisk.high, provisional: true),
            ],
          ),
          dark: dark,
          textScale: 2.5,
          navigation: BucalFloatingNav(
            items: const [
              BucalNavItem(label: 'Início', icon: Icons.home_outlined),
              BucalNavItem(label: 'Análise', icon: Icons.add_a_photo_outlined),
              BucalNavItem(label: 'Sobre', icon: Icons.info_outline),
            ],
            selectedIndex: 1,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.text('Classe não confirmada'), findsOneWidget);
    });
  }

  testWidgets(
    'floating navigation exposes a selected, actionable reader item',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        var selected = -1;
        await tester.pumpWidget(
          _app(
            const Text('Página'),
            navigation: BucalFloatingNav(
              items: const [
                BucalNavItem(label: 'Início', icon: Icons.home_outlined),
                BucalNavItem(label: 'Sobre', icon: Icons.info_outline),
              ],
              selectedIndex: 0,
              onSelected: (index) => selected = index,
            ),
          ),
        );
        final node = tester.getSemantics(find.bySemanticsLabel('Início'));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(
          node.getSemanticsData().flagsCollection.isSelected,
          Tristate.isTrue,
        );
        await tester.tap(find.text('Sobre'));
        expect(selected, 1);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('reduced motion uses a static processing indicator', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const BucalLoading(), reduceMotion: true));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
    final context = tester.element(find.byType(BucalLoading));
    expect(BucalMotion.duration(context), Duration.zero);
  });

  testWidgets('disabled and loading buttons cannot submit', (tester) async {
    var submissions = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            const BucalButton(label: 'Indisponível'),
            BucalButton(
              label: 'Enviando',
              loading: true,
              onPressed: () => submissions++,
            ),
          ],
        ),
        reduceMotion: true,
      ),
    );
    await tester.tap(find.text('Indisponível'));
    await tester.tap(find.text('Enviando'));
    expect(submissions, 0);
  });

  for (final risk in BucalRisk.values) {
    testWidgets(
      '$risk is categorical, simulated, and includes medical guidance',
      (tester) async {
        await tester.pumpWidget(
          _app(BucalRiskCard(risk: risk, provisional: true)),
        );
        expect(find.text('RESULTADO SIMULADO'), findsOneWidget);
        expect(find.text('Não é um diagnóstico'), findsOneWidget);
        expect(find.text('Classe não confirmada'), findsOneWidget);
        expect(find.textContaining('avaliação médica'), findsOneWidget);
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ');
        expect(texts.contains('%'), isFalse);
        expect(texts.contains('validação clínica'), isTrue);
      },
    );
  }
}
