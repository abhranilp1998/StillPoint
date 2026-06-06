import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenPadding extends StatelessWidget {
  const ScreenPadding({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 720 ? 24.0 : 16.0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            16 + MediaQuery.paddingOf(context).bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

class CalmCard extends StatefulWidget {
  const CalmCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<CalmCard> createState() => _CalmCardState();
}

class _CalmCardState extends State<CalmCard> {
  bool _hovered = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final interactive = widget.onTap != null;
    final active = interactive && (_hovered || _pressed);
    final offset = !reduceMotion && active
        ? Offset(0, _pressed ? -1.5 : -.75)
        : Offset.zero;
    final scale = !reduceMotion && _pressed
        ? 1.004
        : (_hovered && !reduceMotion ? 1.001 : 1.0);
    final shadowAlpha = interactive
        ? (_pressed ? .14 : (_hovered ? .12 : .06))
        : .06;

    final card = AnimatedContainer(
      duration: Duration(milliseconds: reduceMotion ? 1 : 170),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(offset.dx, offset.dy, 0)
        ..scaleByDouble(scale, scale, scale, 1),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.color ?? theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active
              ? theme.colorScheme.primary.withValues(alpha: .36)
              : theme.colorScheme.outlineVariant.withValues(alpha: .48),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: shadowAlpha),
            blurRadius: active ? 22 : 14,
            offset: Offset(0, active ? 10 : 6),
          ),
        ],
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (!interactive) return card;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            _setPressed(true);
          },
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          onTap: widget.onTap,
          child: card,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    );
  }
}

class SoftMessage extends StatelessWidget {
  const SoftMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CalmCard(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: .42),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedPressable extends StatefulWidget {
  const AnimatedPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            setState(() => _pressed = true);
          },
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed && !reduceMotion
                ? 1.004
                : (_hovered && !reduceMotion ? 1.006 : 1),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
