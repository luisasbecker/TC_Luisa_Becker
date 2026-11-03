import 'package:flutter/material.dart';
import 'theme.dart';
import 'tokens.g.dart';

enum BucalButtonKind { primary, secondary, tertiary, destructive }

class BucalButton extends StatelessWidget {
  const BucalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.kind = BucalButtonKind.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final BucalButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final c = BucalColors.of(context);
    final style = ButtonStyle(
      animationDuration: BucalMotion.duration(context, 120),
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading || icon != null) ...[
          if (loading && BucalMotion.duration(context) != Duration.zero)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(loading ? Icons.hourglass_empty_rounded : icon, size: 20),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    final callback = loading ? null : onPressed;
    final Widget button = switch (kind) {
      BucalButtonKind.primary => FilledButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      BucalButtonKind.secondary => OutlinedButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      BucalButtonKind.tertiary => TextButton(
        onPressed: callback,
        style: style,
        child: content,
      ),
      BucalButtonKind.destructive => FilledButton(
        onPressed: callback,
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.disabledSurface
                : c.error,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? c.disabledText
                : c.errorSurface,
          ),
        ),
        child: content,
      ),
    };
    return Semantics(
      liveRegion: loading,
      value: loading ? 'Processando' : null,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

class BucalCard extends StatefulWidget {
  const BucalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.onTap,
    this.selected = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool selected;
  @override
  State<BucalCard> createState() => _BucalCardState();
}

class _BucalCardState extends State<BucalCard> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final c = BucalColors.of(context);
    final radius = BorderRadius.circular(BucalTokens.radiusCard);
    return Semantics(
      selected: widget.onTap == null ? null : widget.selected,
      child: Material(
        color: widget.selected ? c.surfaceSelected : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: _focused
                ? c.focus
                : widget.selected
                ? c.primary
                : c.border,
            width: _focused
                ? 3
                : widget.selected
                ? 2
                : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.onTap == null
            ? Padding(padding: widget.padding, child: widget.child)
            : InkWell(
                onTap: widget.onTap,
                borderRadius: radius,
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(padding: widget.padding, child: widget.child),
                ),
              ),
      ),
    );
  }
}

enum BucalNoticeTone { info, success, warning, error }

class BucalNotice extends StatelessWidget {
  const BucalNotice({
    super.key,
    required this.message,
    this.title,
    this.tone = BucalNoticeTone.info,
    this.announce = false,
    this.action,
  });
  final String message;
  final String? title;
  final BucalNoticeTone tone;
  final bool announce;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final c = BucalColors.of(context);
    final (background, foreground, icon) = switch (tone) {
      BucalNoticeTone.info => (
        c.infoSurface,
        c.info,
        Icons.info_outline_rounded,
      ),
      BucalNoticeTone.success => (
        c.successSurface,
        c.success,
        Icons.check_circle_outline_rounded,
      ),
      BucalNoticeTone.warning => (
        c.warningSurface,
        c.warning,
        Icons.error_outline_rounded,
      ),
      BucalNoticeTone.error => (
        c.errorSurface,
        c.error,
        Icons.report_problem_outlined,
      ),
    };
    return Semantics(
      liveRegion: announce,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 22, color: foreground)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: foreground),
                  ),
                  if (action != null) ...[const SizedBox(height: 12), action!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BucalStageHeader extends StatelessWidget {
  const BucalStageHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.step,
    required this.total,
    this.trailing,
  }) : assert(total > 0),
       assert(step >= 1 && step <= total);
  final String title;
  final String? subtitle;
  final int step;
  final int total;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = BucalColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Etapa $step de $total',
                style: text.labelMedium?.copyWith(color: c.textSecondary),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        Semantics(header: true, child: Text(title, style: text.headlineMedium)),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          Text(
            subtitle!,
            style: text.bodyMedium?.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 24),
        ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: step / total,
              minHeight: 4,
              color: c.primary,
              backgroundColor: c.border,
            ),
          ),
        ),
      ],
    );
  }
}

enum BucalRisk { low, medium, high }

class BucalRiskCard extends StatelessWidget {
  const BucalRiskCard({
    super.key,
    required this.risk,
    this.provisional = false,
  });
  final BucalRisk risk;
  final bool provisional;
  @override
  Widget build(BuildContext context) {
    final c = BucalColors.of(context);
    final (label, description, icon, surface, foreground) = switch (risk) {
      BucalRisk.low => (
        'Risco baixo',
        'Este resultado demonstrativo não garante ausência de doença. A alteração observada requer avaliação médica adequada.',
        Icons.info_outline_rounded,
        c.successSurface,
        c.success,
      ),
      BucalRisk.medium => (
        'Risco médio',
        'Para investigar a alteração observada, busque avaliação médica. Esta orientação acompanha um resultado exclusivamente demonstrativo.',
        Icons.search_rounded,
        c.warningSurface,
        c.warning,
      ),
      BucalRisk.high => (
        'Risco alto',
        'É importante buscar avaliação médica especializada da alteração observada. Este resultado é exclusivamente demonstrativo.',
        Icons.priority_high_rounded,
        c.errorSurface,
        c.error,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: 32),
              const SizedBox(height: 20),
              Text(
                'RESULTADO SIMULADO',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: foreground),
              ),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(color: foreground),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const BucalNotice(
          title: 'Não é um diagnóstico',
          message:
              'Classificação de risco apresentada para fins demonstrativos. Os textos são demonstrativos e estão sujeitos à revisão por especialista.',
        ),
        if (provisional) ...[
          const SizedBox(height: 12),
          const BucalNotice(
            tone: BucalNoticeTone.warning,
            title: 'Classe não confirmada',
            message:
                'A classe sugerida foi utilizada provisoriamente para continuar o fluxo. O profissional registrou incerteza; isso não representa validação clínica.',
          ),
        ],
      ],
    );
  }
}

@immutable
class BucalNavItem {
  const BucalNavItem({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// Place in Scaffold.bottomNavigationBar; route/session ownership stays outside.
class BucalFloatingNav extends StatefulWidget {
  const BucalFloatingNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.hideWhenKeyboard = true,
  }) : assert(items.length >= 2 && items.length <= 4),
       assert(selectedIndex >= 0 && selectedIndex < items.length);
  final List<BucalNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool hideWhenKeyboard;
  @override
  State<BucalFloatingNav> createState() => _BucalFloatingNavState();
}

class _BucalFloatingNavState extends State<BucalFloatingNav> {
  int _focusedIndex = -1;

  Widget _item(BuildContext context, int index) {
    final c = BucalColors.of(context);
    final selected = index == widget.selectedIndex;
    final foreground = selected ? c.onNavigationSelected : c.onNavigation;
    return Semantics(
      selected: selected,
      button: true,
      label: widget.items[index].label,
      onTap: () => widget.onSelected(index),
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: BucalMotion.duration(context, 120),
          decoration: BoxDecoration(
            color: selected ? c.navigationSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _focusedIndex == index
                  ? (selected ? c.onNavigationSelected : c.navigationSelected)
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () => widget.onSelected(index),
            onFocusChange: (focused) =>
                setState(() => _focusedIndex = focused ? index : -1),
            borderRadius: BorderRadius.circular(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.items[index].icon, size: 22, color: foreground),
                    const SizedBox(height: 4),
                    Text(
                      widget.items[index].label,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hideWhenKeyboard &&
        MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final c = BucalColors.of(context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: c.navigation,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(36),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < widget.items.length; index++)
                    Expanded(child: _item(context, index)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BucalChoiceTile extends StatelessWidget {
  const BucalChoiceTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    required this.selected,
    this.onTap,
    this.enabled = true,
  });
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final c = BucalColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: BucalCard(
        selected: selected,
        padding: const EdgeInsets.all(16),
        onTap: enabled ? onTap : null,
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: enabled ? c.textPrimary : c.disabledText,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            ExcludeSemantics(
              child: Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: enabled ? c.primary : c.disabledText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BucalSectionField extends StatelessWidget {
  const BucalSectionField({
    super.key,
    required this.label,
    this.helper,
    this.error,
    required this.child,
  });
  final String label;
  final String? helper;
  final String? error;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        header: true,
        child: Text(label, style: Theme.of(context).textTheme.titleSmall),
      ),
      if (helper != null) ...[
        const SizedBox(height: 4),
        Text(helper!, style: Theme.of(context).textTheme.bodySmall),
      ],
      const SizedBox(height: 12),
      child,
      if (error != null) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 20,
                color: BucalColors.of(context).error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BucalColors.of(context).error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class BucalEmptyState extends StatelessWidget {
  const BucalEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.image_outlined,
    this.action,
  });
  final String title;
  final String message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => BucalCard(
    child: Column(
      children: [
        Icon(icon, size: 36, color: BucalColors.of(context).primary),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ],
    ),
  );
}

class BucalLoading extends StatelessWidget {
  const BucalLoading({super.key, this.label = 'Processando…'});
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: label,
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (BucalMotion.duration(context) == Duration.zero)
            Icon(
              Icons.hourglass_empty_rounded,
              size: 32,
              color: BucalColors.of(context).primary,
            )
          else
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          const SizedBox(height: 20),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class BucalPage extends StatelessWidget {
  const BucalPage({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.scrollable = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;
  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(padding: padding, child: child),
      ),
    );
    return SafeArea(
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}
