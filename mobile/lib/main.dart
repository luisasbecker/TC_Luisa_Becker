import 'package:flutter/material.dart';
import 'design_system/design_system.dart';
import 'features/app/bucal_shell.dart';
import 'features/analysis/analysis_controller.dart';

// Kept for v1 regression tests and integrators while the production app uses v2.
export 'features/legacy/legacy_pipeline_screen.dart' show PipelineScreen;

void main() => runApp(const PipelineApp());

class PipelineApp extends StatefulWidget {
  const PipelineApp({
    super.key,
    this.controller,
    this.initialThemeMode = ThemeMode.system,
  });
  final AnalysisController? controller;
  final ThemeMode initialThemeMode;
  @override
  State<PipelineApp> createState() => _PipelineAppState();
}

class _PipelineAppState extends State<PipelineApp> with WidgetsBindingObserver {
  late ThemeMode themeMode = widget.initialThemeMode;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pipeline Bucal',
    debugShowCheckedModeBanner: false,
    theme: BucalTheme.light(),
    darkTheme: BucalTheme.dark(),
    themeMode: themeMode,
    themeAnimationDuration:
        (MediaQuery.maybeOf(context)?.disableAnimations ??
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    home: BucalShell(
      controller: widget.controller,
      themeMode: themeMode,
      onThemeChanged: (mode) => setState(() => themeMode = mode),
    ),
  );
}
