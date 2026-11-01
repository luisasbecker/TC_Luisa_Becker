import 'package:flutter/material.dart';
import 'tokens.g.dart';

/// Semantic colors shared with the JSON/Figma modes; no pipeline state here.
@immutable
class BucalColors extends ThemeExtension<BucalColors> {
  const BucalColors(this.values);
  final Map<String, Color> values;

  static BucalColors of(BuildContext context) =>
      Theme.of(context).extension<BucalColors>() ??
      BucalColors(
        Theme.of(context).brightness == Brightness.dark
            ? BucalTokens.dark
            : BucalTokens.light,
      );

  Color operator [](String name) => values[name]!;
  Color get background => this['background'];
  Color get surface => this['surface'];
  Color get surfaceRaised => this['surfaceRaised'];
  Color get surfaceSubtle => this['surfaceSubtle'];
  Color get surfaceSelected => this['surfaceSelected'];
  Color get textPrimary => this['textPrimary'];
  Color get textSecondary => this['textSecondary'];
  Color get textMuted => this['textMuted'];
  Color get border => this['border'];
  Color get outline => this['outline'];
  Color get divider => this['divider'];
  Color get primary => this['primary'];
  Color get onPrimary => this['onPrimary'];
  Color get primaryHover => this['primaryHover'];
  Color get primaryPressed => this['primaryPressed'];
  Color get secondary => this['secondary'];
  Color get onSecondary => this['onSecondary'];
  Color get focus => this['focus'];
  Color get disabledSurface => this['disabledSurface'];
  Color get disabledText => this['disabledText'];
  Color get navigation => this['navigation'];
  Color get onNavigation => this['onNavigation'];
  Color get navigationSelected => this['navigationSelected'];
  Color get onNavigationSelected => this['onNavigationSelected'];
  Color get success => this['success'];
  Color get successSurface => this['successSurface'];
  Color get warning => this['warning'];
  Color get warningSurface => this['warningSurface'];
  Color get error => this['error'];
  Color get errorSurface => this['errorSurface'];
  Color get info => this['info'];
  Color get infoSurface => this['infoSurface'];

  @override
  BucalColors copyWith({Map<String, Color>? values}) =>
      BucalColors(values == null ? this.values : {...this.values, ...values});

  @override
  BucalColors lerp(covariant BucalColors? other, double t) => other == null
      ? this
      : BucalColors({
          for (final name in values.keys)
            name: Color.lerp(values[name], other.values[name], t)!,
        });
}

abstract final class BucalMotion {
  static Duration duration(BuildContext context, [int milliseconds = 220]) {
    final media = MediaQuery.maybeOf(context);
    return media?.disableAnimations == true ||
            media?.accessibleNavigation == true
        ? Duration.zero
        : Duration(milliseconds: milliseconds);
  }
}

abstract final class BucalTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final c = BucalColors(
      brightness == Brightness.dark ? BucalTokens.dark : BucalTokens.light,
    );
    TextStyle type(String name, {Color? color}) {
      final t = BucalTokens.typography[name]!;
      return TextStyle(
        fontFamily: BucalTokens.fontFamily,
        fontSize: t['size'],
        height: t['lineHeight']! / t['size']!,
        fontWeight: FontWeight.values[(t['weight']! ~/ 100) - 1],
        letterSpacing: t['letterSpacing'],
        color: color ?? c.textPrimary,
      );
    }

    final text = TextTheme(
      displayLarge: type('display'),
      displayMedium: type('display'),
      displaySmall: type('page'),
      headlineLarge: type('page'),
      headlineMedium: type('page'),
      headlineSmall: type('section'),
      titleLarge: type('section'),
      titleMedium: type('subtitle'),
      titleSmall: type('bodySmall').copyWith(fontWeight: FontWeight.w600),
      bodyLarge: type('body'),
      bodyMedium: type('body'),
      bodySmall: type('bodySmall', color: c.textSecondary),
      labelLarge: type('button'),
      labelMedium: type('caption'),
      labelSmall: type('eyebrow'),
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: brightness,
        ).copyWith(
          primary: c.primary,
          onPrimary: c.onPrimary,
          primaryContainer: c.surfaceSelected,
          onPrimaryContainer: c.textPrimary,
          secondary: c.secondary,
          onSecondary: c.onSecondary,
          secondaryContainer: c.surfaceSelected,
          onSecondaryContainer: c.textPrimary,
          surface: c.surface,
          onSurface: c.textPrimary,
          onSurfaceVariant: c.textSecondary,
          surfaceContainerLowest: c.background,
          surfaceContainerLow: c.surface,
          surfaceContainer: c.surfaceSubtle,
          surfaceContainerHigh: c.surfaceRaised,
          surfaceContainerHighest: c.surfaceRaised,
          outline: c.outline,
          outlineVariant: c.border,
          error: c.error,
          onError: c.errorSurface,
          errorContainer: c.errorSurface,
          onErrorContainer: c.error,
          inverseSurface: c.navigation,
          onInverseSurface: c.onNavigation,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BucalTokens.radiusButton),
    );
    final baseButton = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(
          BucalTokens.dimensionsMinimumTouch,
          BucalTokens.dimensionsButtonMinHeight,
        ),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
      tapTargetSize: MaterialTapTargetSize.padded,
      animationDuration: const Duration(milliseconds: 120),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(BucalTokens.radiusInput),
      borderSide: BorderSide(color: c.outline),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: BucalTokens.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      extensions: [c],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      dividerColor: c.divider,
      disabledColor: c.disabledText,
      focusColor: c.focus.withValues(alpha: .14),
      hoverColor: c.primary.withValues(alpha: .08),
      highlightColor: c.primary.withValues(alpha: .12),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.border),
          borderRadius: BorderRadius.circular(BucalTokens.radiusCard),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: baseButton.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return c.disabledSurface;
            if (states.contains(WidgetState.pressed)) return c.primaryPressed;
            if (states.contains(WidgetState.hovered)) return c.primaryHover;
            return c.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.disabledText
                : c.onPrimary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: c.onPrimary, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: baseButton.copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.disabledText
                : c.primary,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused) ? c.focus : c.outline,
              width: states.contains(WidgetState.focused) ? 3 : 1,
            ),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: baseButton.copyWith(
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? c.focus
                  : Colors.transparent,
              width: 2,
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.disabledText
                : c.primary,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: text.bodySmall,
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: c.error),
        errorMaxLines: 4,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: border,
        enabledBorder: border,
        disabledBorder: border.copyWith(
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: c.focus, width: 3),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: c.error, width: 2),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: c.error, width: 3),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceSubtle,
        selectedColor: c.surfaceSelected,
        disabledColor: c.disabledSurface,
        labelStyle: text.bodySmall,
        side: BorderSide(color: c.border),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.navigation,
        contentTextStyle: text.bodySmall?.copyWith(color: c.onNavigation),
        actionTextColor: c.navigationSelected,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.border,
      ),
    );
  }
}
