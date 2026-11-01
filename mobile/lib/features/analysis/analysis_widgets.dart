import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';
import '../../ui/crop_editor.dart';
import 'analysis_controller.dart';

class ClinicalImageView extends StatelessWidget {
  const ClinicalImageView({
    super.key,
    required this.bytes,
    required this.label,
    this.imageKey,
    this.height = 224,
    this.caption = true,
  });
  final Uint8List bytes;
  final String label;
  final Key? imageKey;
  final double height;
  final bool caption;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Material(
        color: BucalColors.of(context).surfaceSubtle,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showClinicalImage(context, bytes, label),
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: height,
                child: Image.memory(
                  bytes,
                  key: imageKey,
                  fit: BoxFit.contain,
                  semanticLabel: label,
                  gaplessPlayback: true,
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton.filledTonal(
                  onPressed: () => showClinicalImage(context, bytes, label),
                  tooltip: 'Ampliar $label',
                  icon: const Icon(Icons.zoom_in_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      if (caption)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
    ],
  );
}

Future<void> showClinicalImage(
  BuildContext context,
  Uint8List bytes,
  String label, {
  String? source,
  Widget? action,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: AnimationStyle(
    duration: BucalMotion.duration(context),
    reverseDuration: BucalMotion.duration(context, 180),
  ),
  builder: (context) => FractionallySizedBox(
    heightFactor: .9,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Fechar imagem ampliada',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: (MediaQuery.sizeOf(context).height * .42).clamp(
                180.0,
                420.0,
              ),
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 5,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    semanticLabel: label,
                  ),
                ),
              ),
            ),
            if (source != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(
                  source,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: action,
              ),
          ],
        ),
      ),
    ),
  ),
);

class ImageCropPanel extends StatefulWidget {
  const ImageCropPanel({
    super.key,
    required this.image,
    required this.initialBox,
    required this.onConfirm,
    required this.onCancel,
    this.busy = false,
    this.processingLabel,
  });
  final String? processingLabel;
  final AnalysisImage image;
  final CropBox initialBox;
  final ValueChanged<CropBox> onConfirm;
  final VoidCallback onCancel;
  final bool busy;
  @override
  State<ImageCropPanel> createState() => _ImageCropPanelState();
}

class _ImageCropPanelState extends State<ImageCropPanel> {
  late CropBox box = widget.initialBox;
  bool zoom = false;
  final transform = TransformationController();

  bool sameBox(CropBox a, CropBox b) =>
      a.left == b.left &&
      a.top == b.top &&
      a.right == b.right &&
      a.bottom == b.bottom;

  @override
  void didUpdateWidget(ImageCropPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.id != widget.image.id ||
        oldWidget.image.hash != widget.image.hash ||
        !sameBox(oldWidget.initialBox, widget.initialBox)) {
      box = widget.initialBox;
      zoom = false;
      transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  void nudge(double dx, double dy) => setState(() {
    final x = dx.clamp(-box.left, 1 - box.right);
    final y = dy.clamp(-box.top, 1 - box.bottom);
    box = CropBox(box.left + x, box.top + y, box.right + x, box.bottom + y);
  });

  void resize(double widthDelta, double heightDelta) => setState(() {
    final width = (box.right - box.left + widthDelta).clamp(.05, 1.0);
    final height = (box.bottom - box.top + heightDelta).clamp(.05, 1.0);
    final left = ((box.left + box.right - width) / 2).clamp(0.0, 1 - width);
    final top = ((box.top + box.bottom - height) / 2).clamp(0.0, 1 - height);
    box = CropBox(left, top, left + width, top + height);
  });

  Widget editor(Size imageSize) {
    final crop = Center(
      child: SizedBox(
        width: imageSize.width,
        height: imageSize.height,
        child: CropEditor(
          bytes: widget.image.bytes,
          ratio: widget.image.width / widget.image.height,
          box: box,
          onChanged: (value) => setState(() => box = value),
        ),
      ),
    );
    // Both modes transform the entire viewport, so visible enlarged handles
    // remain interactive outside the original fitted image rectangle.
    // Only one recognizer owns the surface at a time. A zoomed view remains
    // available when returning to crop mode, with inverse transformed hit tests.
    return IgnorePointer(
      ignoring: widget.busy,
      child: zoom
          ? InteractiveViewer(
              transformationController: transform,
              minScale: 1,
              maxScale: 4,
              child: IgnorePointer(child: crop),
            )
          : Transform(
              transform: transform.value,
              transformHitTests: true,
              child: crop,
            ),
    );
  }

  Future<void> showAdjustments() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: BucalMotion.duration(context),
      reverseDuration: BucalMotion.duration(context, 180),
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ajustes acessíveis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Fechar ajustes',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              'Controles alternativos ao gesto. Os ajustes são aplicados ao recorte ao tocar.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, dx, dy) in [
                  ('Alargar', .05, 0.0),
                  ('Estreitar', -.05, 0.0),
                  ('Aumentar altura', 0.0, .05),
                  ('Diminuir altura', 0.0, -.05),
                ])
                  OutlinedButton(
                    onPressed: () {
                      if (!widget.busy) resize(dx, dy);
                    },
                    child: Text(label),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final (label, icon, dx, dy) in [
                  ('Mover recorte à esquerda', Icons.arrow_back, -.025, 0.0),
                  ('Mover recorte para cima', Icons.arrow_upward, 0.0, -.025),
                  ('Mover recorte para baixo', Icons.arrow_downward, 0.0, .025),
                  ('Mover recorte à direita', Icons.arrow_forward, .025, 0.0),
                ])
                  IconButton(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () {
                      if (!widget.busy) nudge(dx, dy);
                    },
                    tooltip: label,
                    icon: Icon(icon),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            BucalButton(
              label: 'Voltar ao recorte',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> showHelp() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Como ajustar o recorte'),
      scrollable: true,
      content: const Text(
        'Arraste os cantos para redimensionar e o centro para mover. '
        'Toque na lupa para ampliar e mover a imagem com gestos. '
        'Toque novamente na lupa para ajustar o recorte na imagem ampliada. '
        'Use Redefinir visão para voltar à imagem completa. '
        'Os Ajustes acessíveis oferecem botões para mover e redimensionar sem arrastar.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );

  Widget tool(
    String label,
    IconData icon,
    VoidCallback action, {
    bool selected = false,
  }) => IconButton(
    tooltip: label,
    isSelected: selected,
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      backgroundColor: selected
          ? BucalColors.of(context).surfaceSelected
          : null,
    ),
    onPressed: widget.busy ? null : action,
    icon: Icon(icon),
  );

  /// The shell gives this workspace a bounded height; only the image expands.
  /// The page itself never scrolls while its crop handles are being dragged.
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(14) > 22;
    final theme = Theme.of(context);
    Widget action({
      required String label,
      required String shortLabel,
      required VoidCallback? onPressed,
      bool primary = false,
    }) => Semantics(
      label: compact ? label : null,
      excludeSemantics: compact,
      onTap: compact ? onPressed : null,
      button: true,
      enabled: onPressed != null,
      child: Theme(
        data: compact
            ? theme.copyWith(
                filledButtonTheme: FilledButtonThemeData(
                  style: theme.filledButtonTheme.style?.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                textButtonTheme: TextButtonThemeData(
                  style: theme.textButtonTheme.style?.copyWith(
                    padding: const WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
              )
            : theme,
        child: BucalButton(
          label: compact ? shortLabel : label,
          loading: primary && widget.busy,
          icon: primary && !compact ? Icons.check_rounded : null,
          kind: primary ? BucalButtonKind.primary : BucalButtonKind.tertiary,
          onPressed: onPressed,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            key: const ValueKey('crop-viewport'),
            borderRadius: BorderRadius.circular(24),
            child: ColoredBox(
              color: BucalColors.of(context).surfaceSubtle,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ratio = widget.image.width / widget.image.height;
                  final availableWidth = (constraints.maxWidth - 36).clamp(
                    0.0,
                    double.infinity,
                  );
                  final availableHeight = (constraints.maxHeight - 36).clamp(
                    0.0,
                    double.infinity,
                  );
                  final width = availableWidth.clamp(
                    0.0,
                    availableHeight * ratio,
                  );
                  return editor(Size(width, width / ratio));
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            tool(
              zoom ? 'Voltar a ajustar o recorte' : 'Ampliar imagem',
              zoom ? Icons.crop_rounded : Icons.zoom_in_rounded,
              () => setState(() => zoom = !zoom),
              selected: zoom,
            ),
            tool('Redefinir visão', Icons.fit_screen, () {
              transform.value = Matrix4.identity();
              setState(() => zoom = false);
            }),
            tool(
              'Imagem inteira',
              Icons.photo_size_select_large_rounded,
              () => setState(() => box = const CropBox(0, 0, 1, 1)),
            ),
            tool('Ajustes acessíveis', Icons.tune_rounded, showAdjustments),
            tool(
              'Como ajustar o recorte',
              Icons.help_outline_rounded,
              showHelp,
            ),
          ],
        ),
        if (!compact)
          Semantics(
            liveRegion: true,
            child: Text(
              zoom
                  ? 'Ampliação ativa · use dois dedos.'
                  : 'Arraste a região e os cantos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        action(
          label: widget.busy
              ? widget.processingLabel ?? 'Verificando foco…'
              : 'Confirmar novo recorte',
          shortLabel: widget.busy ? 'Aguarde…' : 'Confirmar',
          primary: true,
          onPressed: widget.busy ? null : () => widget.onConfirm(box),
        ),
        const SizedBox(height: 4),
        action(
          label: 'Cancelar ajuste',
          shortLabel: 'Cancelar',
          onPressed: widget.busy ? null : widget.onCancel,
        ),
      ],
    );
  }
}
