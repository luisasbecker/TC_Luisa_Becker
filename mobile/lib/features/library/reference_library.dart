import 'dart:convert';
import 'package:flutter/services.dart';

/// Only published images explicitly classified by the source enter this list.
/// Browsing these assets is local; uploading requires a separate user action.
class ClinicalReference {
  const ClinicalReference({
    required this.id,
    required this.asset,
    required this.classIndex,
    required this.label,
    required this.attribution,
    required this.width,
    required this.height,
    this.qualityLabel,
  });
  final String id, asset, label, attribution;
  final int? classIndex;
  final int width, height;
  final String? qualityLabel;
  Future<Uint8List> bytes() async =>
      (await rootBundle.load(asset)).buffer.asUint8List();
}

class ReferenceLibrary {
  ReferenceLibrary._(this.images);
  final List<ClinicalReference> images;
  static Future<ReferenceLibrary>? _cached;
  static ReferenceLibrary? _ready;
  static Future<ReferenceLibrary> load() =>
      _ready == null ? (_cached ??= _load()) : Future.value(_ready);
  static Future<ReferenceLibrary> _load() async {
    final manifest =
        jsonDecode(
              await rootBundle.loadString('assets/references/manifest.json'),
            )
            as Map<String, dynamic>;
    final images = (manifest['assets'] as List)
        .map((raw) {
          final row = raw as Map<String, dynamic>;
          final dimensions = row['dimensions'] as Map<String, dynamic>;
          final classIndex = row['lesion_class_index'] as int?;
          final quality = row['source_quality_label'] as String?;
          return ClinicalReference(
            id: row['id'] as String,
            asset: 'assets/references/${row['file']}',
            classIndex: classIndex,
            label:
                row['lesion_class_label'] as String? ??
                (quality == 'sharp'
                    ? 'Exemplo de foco adequado'
                    : 'Exemplo de foco inadequado'),
            attribution: row['attribution'] as String,
            width: dimensions['width_px'] as int,
            height: dimensions['height_px'] as int,
            qualityLabel: quality,
          );
        })
        .toList(growable: false);
    final library = ReferenceLibrary._(List.unmodifiable(images));
    _ready = library;
    return library;
  }

  List<ClinicalReference> forClass(int index) => images
      .where((image) => image.classIndex == index)
      .toList(growable: false);
}
