/// The floating control that fans out over the board.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';

/// One action on the radial menu.
@immutable
class RadialAction {
  /// Creates a radial action.
  const RadialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.keepsMenuOpen = false,
  });

  /// Glyph shown in the button.
  final IconData icon;

  /// Name, shown beside the button while the menu is open.
  final String label;

  /// Invoked on tap, or null to show the action as unavailable.
  final VoidCallback? onPressed;

  /// Whether the action is currently toggled on.
  final bool selected;

  /// Whether running this action should leave the menu open.
  ///
  /// Set on toggles, so several can be flipped in one visit. Inferring this
  /// from [selected] does not work: that is the value from before the action
  /// ran, so switching a toggle on would read as "not a toggle".
  final bool keepsMenuOpen;
}

/// A single button that fans its actions out along an arc.
///
/// On a phone the board takes the whole screen, so the controls cannot live
/// beside it. This keeps one small target at rest and puts everything else a
/// tap away -- the same idea as the original's circular FAB, rebuilt so it
/// animates per item and does not depend on an abandoned package.
class RadialMenu extends StatefulWidget {
  /// Creates a radial menu.
  const RadialMenu({
    required this.actions,
    this.status,
    this.radius = 160,
    super.key,
  });

  /// Actions to fan out, in order from the horizontal outward.
  final List<RadialAction> actions;

  /// Optional line shown above the menu while it is open, for the clock and
  /// score that the immersive layout otherwise has nowhere to put.
  final Widget? status;

  /// Distance from the button to the fanned-out actions.
  ///
  /// The fan covers a quarter turn, so the arc between neighbours is
  /// `radius * (pi/2) / (count - 1)`. That gap has to clear the widest label,
  /// not just the 46px circle, which caps the arc at about five actions.
  final double radius;

  @override
  State<RadialMenu> createState() => _RadialMenuState();
}

class _RadialMenuState extends State<RadialMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );

  bool get _open => _controller.value > 0.5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _close() => _controller.reverse();

  /// Runs an action, then closes unless it asked to stay open.
  void _run(RadialAction action) {
    if (action.onPressed == null) return;
    action.onPressed!.call();
    if (!action.keepsMenuOpen) _close();
  }

  /// Inset of the trigger from the bottom-right corner.
  static const double _margin = 12;

  @override
  Widget build(BuildContext context) {
    final count = widget.actions.length;
    _controller
      ..duration = motionOf(context, const Duration(milliseconds: 320))
      ..reverseDuration = motionOf(context, const Duration(milliseconds: 220));

    // Deliberately fills its parent. A Stack only hit-tests within its own
    // bounds, so a small Stack with items fanned out beyond it would draw
    // them correctly and then refuse every tap.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Tapping anywhere outside closes the menu.
            if (t > 0)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _close,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.scrim
                        .withValues(alpha: 0.5 * t),
                  ),
                ),
              ),

            if (widget.status != null && t > 0)
              Positioned(
                right: _margin,
                bottom: widget.radius + 96,
                child: Opacity(
                  opacity: Curves.easeOut.transform(t),
                  child: widget.status,
                ),
              ),

            // Built only while open. Leaving them in the tree at zero opacity
            // would keep them in the semantics tree, so a screen reader would
            // announce controls that are not on screen.
            if (t > 0)
              for (var i = 0; i < count; i++) _item(context, i, count, t),

            Positioned(
              right: _margin,
              bottom: _margin,
              child: _trigger(context, t),
            ),
          ],
        );
      },
    );
  }

  Widget _item(BuildContext context, int index, int count, double t) {
    // Fan across a quarter turn, from straight up to straight left, so the
    // items stay on screen when the button sits in the bottom-right corner.
    final fraction = count == 1 ? 0.5 : index / (count - 1);
    final angle = math.pi + fraction * (math.pi / 2);

    // Stagger so the arc unrolls instead of appearing all at once.
    final delay = 0.06 * index;
    final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOutBack.transform(local).clamp(0.0, 1.4);

    final dx = math.cos(angle) * widget.radius * eased;
    final dy = math.sin(angle) * widget.radius * eased;

    final action = widget.actions[index];
    final scheme = Theme.of(context).colorScheme;

    return Positioned(
      right: _margin + 5 - dx,
      bottom: _margin + 5 - dy,
      child: Opacity(
        opacity: local,
        child: Transform.scale(
          scale: 0.6 + 0.4 * local,
          child: _ActionButton(
            action: action,
            enabled: action.onPressed != null,
            scheme: scheme,
            onTap: () => _run(action),
          ),
        ),
      ),
    );
  }

  Widget _trigger(BuildContext context, double t) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: _open ? 'Close controls' : 'Open controls',
      child: Material(
        color: scheme.primaryContainer,
        shape: const CircleBorder(),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _toggle,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Transform.rotate(
              angle: t * math.pi * 0.75,
              child: Icon(
                t > 0.5 ? Icons.close : Icons.apps,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.enabled,
    required this.scheme,
    required this.onTap,
  });

  final RadialAction action;
  final bool enabled;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = action.selected
        ? scheme.tertiaryContainer
        : scheme.surfaceContainerHigh;
    final foreground = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
        : action.selected
        ? scheme.onTertiaryContainer
        : scheme.onSurface;

    // The whole item is the target, label included: on a phone the circle
    // alone is a smaller tap area than it looks.
    return Semantics(
      button: true,
      enabled: enabled,
      selected: action.selected,
      label: action.label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: action.selected
                        ? scheme.tertiary
                        : scheme.outlineVariant,
                    width: action.selected ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(action.icon, size: 20, color: foreground),
              ),
              const SizedBox(height: 4),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 3,
                    vertical: 1,
                  ),
                  child: Text(
                    action.label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontSize: 9,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
