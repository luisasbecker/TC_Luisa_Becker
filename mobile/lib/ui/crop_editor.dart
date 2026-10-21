import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../domain/pipeline.dart';

class CropEditor extends StatelessWidget {
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
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: ratio,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth, h = constraints.maxHeight;
        void change(DragUpdateDetails d, int corner) {
          final dx = d.delta.dx / w, dy = d.delta.dy / h;
          var l = box.left, t = box.top, r = box.right, b = box.bottom;
          if (corner == -1) {
            final x = dx.clamp(-l, 1 - r), y = dy.clamp(-t, 1 - b);
            l += x;
            r += x;
            t += y;
            b += y;
          } else {
            if (corner == 0 || corner == 2) {
              l = (l + dx).clamp(0, r - .05);
            }
            if (corner == 1 || corner == 3) {
              r = (r + dx).clamp(l + .05, 1);
            }
            if (corner == 0 || corner == 1) {
              t = (t + dy).clamp(0, b - .05);
            }
            if (corner == 2 || corner == 3) {
              b = (b + dy).clamp(t + .05, 1);
            }
          }
          onChanged(CropBox(l, t, r, b));
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.memory(
                bytes,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _Shade(box))),
            ),
            Positioned(
              left: box.left * w,
              top: box.top * h,
              width: (box.right - box.left) * w,
              height: (box.bottom - box.top) * h,
              child: Semantics(
                label: 'Área selecionada. Arraste para mover.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => change(d, -1),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            for (var i = 0; i < 4; i++)
              Positioned(
                left: ((i.isEven ? box.left : box.right) * w - 24).clamp(
                  -12,
                  w - 36,
                ),
                top: ((i < 2 ? box.top : box.bottom) * h - 24).clamp(
                  -12,
                  h - 36,
                ),
                child: Semantics(
                  label: 'Ajustar canto ${i + 1} do recorte',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => change(d, i),
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
                              color: Colors.redAccent,
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
