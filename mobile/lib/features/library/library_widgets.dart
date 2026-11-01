import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../core/models/analysis_models.dart';
import '../analysis/analysis_widgets.dart';
import 'reference_library.dart';

class ReferenceGallery extends StatelessWidget {
  const ReferenceGallery({super.key, required this.classIndex});
  final int classIndex;
  @override
  Widget build(BuildContext context) => FutureBuilder<ReferenceLibrary>(
    future: ReferenceLibrary.load(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const BucalNotice(
          message:
              'As referências não puderam ser carregadas. Você ainda pode registrar sua avaliação.',
          tone: BucalNoticeTone.warning,
        );
      }
      if (!snapshot.hasData) {
        return const BucalLoading(label: 'Carregando referências locais…');
      }
      final images = snapshot.data!.forClass(classIndex);
      if (images.isEmpty) {
        return const BucalEmptyState(
          title: 'Referência indisponível',
          message: 'Não há exemplo identificado na fonte para esta classe.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referências da classe',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120 + MediaQuery.textScalerOf(context).scale(12) * 2.6,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => SizedBox(
                width: 164,
                child: _ReferenceTile(reference: images[index], compact: true),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Gomes et al. (2023), Fig. 2 • toque para ampliar',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}

class ReferenceBrowser extends StatelessWidget {
  const ReferenceBrowser({super.key, required this.onUse});
  final ValueChanged<ClinicalReference> onUse;
  @override
  Widget build(BuildContext context) => FutureBuilder<ReferenceLibrary>(
    future: ReferenceLibrary.load(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const BucalEmptyState(
          title: 'Biblioteca indisponível',
          message:
              'Os recursos locais não foram encontrados. Reinicie o aplicativo.',
        );
      }
      if (!snapshot.hasData) {
        return const BucalLoading(label: 'Abrindo biblioteca…');
      }
      final library = snapshot.data!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BIBLIOTECA', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 12),
          Text(
            'Referências para comparar.',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Exemplos dos artigos do projeto, identificados pela classificação descrita nas fontes.',
          ),
          const SizedBox(height: 20),
          const BucalNotice(
            message:
                'Consultar as imagens não inicia uma análise. Para testar o fluxo, abra um exemplo e escolha “Usar em uma análise”.',
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < lesionClasses.length; i++) ...[
            Text(
              lesionClasses[i],
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            for (final reference in library.forClass(i)) ...[
              _ReferenceTile(reference: reference, onUse: onUse),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
          ],
          Text(
            'Qualidade da imagem',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Exemplos de foco do artigo de Souza et al. A fonte não define a classe de lesão ou o risco.',
          ),
          const SizedBox(height: 12),
          for (final reference in library.images.where(
            (item) => item.classIndex == null,
          )) ...[
            _ReferenceTile(reference: reference, onUse: onUse),
            const SizedBox(height: 12),
          ],
          const BucalNotice(
            message:
                'As fotografias têm a resolução disponibilizada pelos artigos. Ampliar não recupera detalhes clínicos. Nenhuma imagem determina o risco simulado.',
          ),
        ],
      );
    },
  );
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.reference,
    this.compact = false,
    this.onUse,
  });
  final ClinicalReference reference;
  final bool compact;
  final ValueChanged<ClinicalReference>? onUse;
  Future<void> open(BuildContext context) async {
    final bytes = await reference.bytes();
    if (!context.mounted) return;
    await showClinicalImage(
      context,
      bytes,
      reference.label,
      source:
          '${reference.attribution}\n\nResolução original: ${reference.width} × ${reference.height} px. Ampliação apenas para consulta.',
      action: onUse == null
          ? null
          : BucalButton(
              label: 'Usar em uma análise',
              icon: Icons.add_rounded,
              onPressed: () {
                Navigator.pop(context);
                onUse!(reference);
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) => BucalCard(
    padding: EdgeInsets.all(compact ? 8 : 16),
    onTap: () => open(context),
    child: compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    reference.asset,
                    fit: BoxFit.contain,
                    semanticLabel: reference.label,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Ampliar',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  const Icon(Icons.open_in_full_rounded, size: 16),
                ],
              ),
            ],
          )
        : Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Image.asset(
                    reference.asset,
                    fit: BoxFit.contain,
                    semanticLabel: reference.label,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reference.classIndex == null
                          ? 'Souza et al. • Fig. 1'
                          : 'Gomes et al. (2023) • Fig. 2',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ampliar e ver fonte',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: BucalColors.of(context).primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
