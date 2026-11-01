import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../domain/pipeline.dart';

class CropEditor extends StatefulWidget {
  const CropEditor({
    super.key,
    required this.bytes,
    required this.ratio,
    required this.box,
    required this.onChanged,
  });
  final Uint8List bytes;
  final double ratio;
  final CropBox box;
  final ValueChanged<CropBox> onChanged;

  @override
  State<CropEditor> createState() => _CropEditorState();
}

class _CropEditorState extends State<CropEditor> {
  late CropBox _box = widget.box;
  late Widget _image = _buildImage();
  CropBox? _gestureBox;
  Offset _gestureDelta = Offset.zero;

  Widget _buildImage() => RepaintBoundary(
    child: Image.memory(
      widget.bytes,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    ),
  );

  bool _sameBox(CropBox a, CropBox b) =>
      a.left == b.left &&
      a.top == b.top &&
      a.right == b.right &&
      a.bottom == b.bottom;

  @override
  void didUpdateWidget(CropEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      _image = _buildImage();
      _gestureBox = null;
      _box = widget.box;
    } else if (!_sameBox(widget.box, _box)) {
      // External actions (reset, accessible nudges) replace the selection.
      _box = widget.box;
      _gestureBox = null;
    }
  }

  void _beginGesture(DragStartDetails _) {
    _gestureBox = _box;
    _gestureDelta = Offset.zero;
  }

  void _change(DragUpdateDetails details, int corner, Size size) {
    if (size.isEmpty) return;
    final start = _gestureBox ?? _box;
    _gestureBox ??= start;
    _gestureDelta += details.delta;
    final dx = _gestureDelta.dx / size.width;
    final dy = _gestureDelta.dy / size.height;
    var l = start.left, t = start.top, r = start.right, b = start.bottom;
    if (corner == -1) {
      final x = dx.clamp(-l, 1 - r), y = dy.clamp(-t, 1 - b);
      l += x;
      r += x;
      t += y;
      b += y;
    } else {
      if (corner == 0 || corner == 2) l = (l + dx).clamp(0, r - .05);
      if (corner == 1 || corner == 3) r = (r + dx).clamp(l + .05, 1);
      if (corner == 0 || corner == 1) t = (t + dy).clamp(0, b - .05);
      if (corner == 2 || corner == 3) b = (b + dy).clamp(t + .05, 1);
    }
    final next = CropBox(l, t, r, b);
    setState(() => _box = next);
    widget.onChanged(next);
  }

  Widget _dragTarget({
    required Widget child,
    required int corner,
    required Size size,
  }) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    dragStartBehavior: DragStartBehavior.down,
    onPanStart: _beginGesture,
    onPanUpdate: (details) => _change(details, corner, size),
    onPanEnd: (_) => _gestureBox = null,
    onPanCancel: () => _gestureBox = null,
    child: child,
  );

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: widget.ratio,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth, h = constraints.maxHeight;
        final size = Size(w, h);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: _image),
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _Shade(_box))),
            ),
            Positioned(
              left: _box.left * w,
              top: _box.top * h,
              width: (_box.right - _box.left) * w,
              height: (_box.bottom - _box.top) * h,
              child: Semantics(
                label: 'Área selecionada. Arraste para mover.',
                child: _dragTarget(
                  corner: -1,
                  size: size,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: ((i.isEven ? _box.left : _box.right) * w - 24).clamp(
                  -12,
                  w < 24 ? -12 : w - 36,
                ),
                top: ((i < 2 ? _box.top : _box.bottom) * h - 24).clamp(
                  -12,
                  h < 24 ? -12 : h - 36,
                ),
                child: Semantics(
                  label: 'Ajustar canto ${i + 1} do recorte',
                  child: _dragTarget(
                    corner: i,
                    size: size,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class _Shade extends CustomPainter {
  _Shade(this.box);
  final CropBox box;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTRB(
      box.left * size.width,
      box.top * size.height,
      box.right * size.width,
      box.bottom * size.height,
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRect(rect);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .5));
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_Shade oldDelegate) => oldDelegate.box != box;
}
