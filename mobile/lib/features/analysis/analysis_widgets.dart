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
  });
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

  Widget editor() {
    final crop = CropEditor(
      bytes: widget.image.bytes,
      ratio: widget.image.width / widget.image.height,
      box: box,
      onChanged: (value) => setState(() => box = value),
    );
    if (zoom) {
      return InteractiveViewer(
        transformationController: transform,
        minScale: 1,
        maxScale: 4,
        child: IgnorePointer(child: crop),
      );
    }
    // The scale recognizer is absent while editing, so corner/area drags
    // reach CropEditor. Preserve the current zoom and inverse hit testing.
    return Transform(
      transform: transform.value,
      transformHitTests: true,
      child: IgnorePointer(ignoring: widget.busy, child: crop),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Arraste os cantos para redimensionar e o centro para mover. Use o modo de ampliação para aproximar a imagem.',
      ),
      const SizedBox(height: 20),
      ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: ColoredBox(
          color: BucalColors.of(context).surfaceSubtle,
          child: Padding(padding: const EdgeInsets.all(18), child: editor()),
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilterChip(
            label: Text(zoom ? 'Ampliação ativa' : 'Ampliar imagem'),
            avatar: const Icon(Icons.zoom_in_rounded, size: 18),
            selected: zoom,
            onSelected: widget.busy
                ? null
                : (value) => setState(() => zoom = value),
          ),
          ActionChip(
            label: const Text('Redefinir visão'),
            avatar: const Icon(Icons.fit_screen, size: 18),
            onPressed: widget.busy
                ? null
                : () {
                    transform.value = Matrix4.identity();
                    setState(() => zoom = false);
                  },
          ),
          ActionChip(
            label: const Text('Imagem inteira'),
            onPressed: widget.busy
                ? null
                : () => setState(() => box = const CropBox(0, 0, 1, 1)),
          ),
        ],
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Ajustes acessíveis'),
        subtitle: const Text('Controles alternativos ao gesto'),
        children: [
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
                ActionChip(
                  label: Text(label),
                  onPressed: widget.busy ? null : () => resize(dx, dy),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              IconButton(
                onPressed: widget.busy ? null : () => nudge(-.025, 0),
                tooltip: 'Mover recorte à esquerda',
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                onPressed: widget.busy ? null : () => nudge(0, -.025),
                tooltip: 'Mover recorte para cima',
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                onPressed: widget.busy ? null : () => nudge(0, .025),
                tooltip: 'Mover recorte para baixo',
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                onPressed: widget.busy ? null : () => nudge(.025, 0),
                tooltip: 'Mover recorte à direita',
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ],
      ),
      const SizedBox(height: 16),
      BucalButton(
        label: 'Confirmar novo recorte',
        loading: widget.busy,
        icon: Icons.check_rounded,
        onPressed: widget.busy ? null : () => widget.onConfirm(box),
      ),
      const SizedBox(height: 8),
      BucalButton(
        label: 'Cancelar ajuste',
        kind: BucalButtonKind.tertiary,
        onPressed: widget.busy ? null : widget.onCancel,
      ),
    ],
  );
}
