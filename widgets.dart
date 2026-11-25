import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brands.dart';
import 'models.dart';
import 'paper.dart';
import 'totp.dart';

export 'paper.dart';

/// Small fingerprint seal used on welcome and account sheets.
class LogoMark extends StatelessWidget {
  final double size;
  final bool? onDark;

  const LogoMark({super.key, this.size = 40, this.onDark});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.primary,
        borderRadius: BorderRadius.circular(size * .32),
        border: Border.all(color: p.primary),
        boxShadow: [
          BoxShadow(
            color: p.ink.withValues(alpha: .10),
            blurRadius: size * .3,
            offset: Offset(0, size * .10),
          ),
        ],
      ),
      child: Icon(
        Icons.fingerprint_rounded,
        color: p.onPrimary,
        size: size * .62,
      ),
    );
  }
}

/// Paper tile for an entry type or a known brand.
class TypeTile extends StatelessWidget {
  final ItemType type;
  final double size;
  final String? brandName;

  const TypeTile(this.type, {super.key, this.size = 50, this.brandName});

  @override
  Widget build(BuildContext context) {
    final brand = brandName == null || brandName!.trim().isEmpty
        ? null
        : Brands.find(brandName!);
    final tint = brand?.color ?? type.tint;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(size * .30),
        border: Border.all(color: tint.withValues(alpha: .34)),
      ),
      child: brand == null
          ? Icon(type.icon, color: tint, size: size * .48)
          : Text(
              brand.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                fontFamily: Paper.serif,
                color: tint,
                fontSize: size * .48,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

/// Compatibility wrapper around [PaperCard].
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final bool glass;
  final Color? glow;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = 26,
    this.glass = false,
    this.glow,
  });

  @override
  Widget build(BuildContext context) {
    if (gradient != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: context.pal.line),
          boxShadow: [Paper.shadow],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
    }
    return PaperCard(
      padding: padding,
      radius: radius,
      onTap: onTap,
      tone: color,
      child: child,
    );
  }
}

class SoftIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool onColor;
  final double size;

  const SoftIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.onColor = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final foreground = onColor ? p.onPrimary : p.ink;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: onColor ? p.primary : p.surface,
        shape: CircleBorder(
          side: BorderSide(color: onColor ? p.primary : p.line),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: 21, color: foreground),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: Paper.serif,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: context.pal.ink,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class FadeSlide extends StatelessWidget {
  final int index;
  final Widget child;

  const FadeSlide({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + math.min(index, 8) * 40),
      curve: Curves.easeOutCubic,
      builder: (_, value, animatedChild) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: animatedChild,
        ),
      ),
      child: child,
    );
  }
}

Route<T> smoothRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

Color strengthColor(int level) => const [
      Paper.red,
      Paper.clay,
      Paper.gold,
      Paper.green,
      Paper.accent,
    ][level.clamp(0, 4)];

class StrengthBar extends StatelessWidget {
  final int level;
  final bool onDark;

  const StrengthBar(this.level, {super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final filled = math.max(level, 1);
    final off = context.pal.surface2;
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
            decoration: BoxDecoration(
              color: i < filled ? strengthColor(level) : off,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
      }),
    );
  }
}

Timer? _clipTimer;

/// Copies text and clears the clipboard after 30 seconds.
Future<void> copyText(BuildContext context, String text, String label) async {
  await Clipboard.setData(ClipboardData(text: text));
  HapticFeedback.selectionClick();
  _clipTimer?.cancel();
  _clipTimer = Timer(const Duration(seconds: 30), () {
    Clipboard.setData(const ClipboardData(text: ''));
  });
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied · clears in 30s')));
  }
}

class HealthRing extends StatelessWidget {
  final int score;
  final double size;
  final double stroke;
  final bool onDark;

  const HealthRing({
    super.key,
    required this.score,
    this.size = 64,
    this.stroke = 7,
    this.onDark = false,
  });

  static Color colorFor(int score) {
    if (score >= 80) return Paper.green;
    if (score >= 50) return Paper.gold;
    return Paper.red;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: stroke,
              backgroundColor: p.surface2,
              color: colorFor(score),
            ),
            Text(
              '$score',
              style: TextStyle(
                fontFamily: Paper.serif,
                fontSize: size * .30,
                fontWeight: FontWeight.w800,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A paper card visual for saved payment cards.
class CardVisual extends StatelessWidget {
  final Entry entry;
  final bool reveal;

  const CardVisual({super.key, required this.entry, this.reveal = false});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final holder = entry.f('holder');
    final expiry = entry.f('expiry');
    final label = TextStyle(
      color: p.onPrimary.withValues(alpha: .82),
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
    );

    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        decoration: BoxDecoration(
          color: p.primary,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: p.primary),
          boxShadow: [Paper.shadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label,
                      ),
                    ),
                    Text(
                      cardBrand(entry.f('number')),
                      style: TextStyle(
                        color: p.onPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 42,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Paper.gold,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    maskedCard(entry.f('number'), reveal),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 21,
                      letterSpacing: 2,
                      color: p.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        holder.isEmpty ? 'CARDHOLDER' : holder.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: label,
                      ),
                    ),
                    Text(expiry.isEmpty ? 'MM/YY' : expiry, style: label),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility alias for the old glow card.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? glow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.onTap,
    this.color,
    this.glow,
  });

  @override
  Widget build(BuildContext context) => PaperCard(
        padding: padding,
        radius: radius,
        onTap: onTap,
        tone: color ?? glow?.withValues(alpha: .06),
        child: child,
      );
}

class AnimatedNumber extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String Function(int)? format;

  const AnimatedNumber(this.value, {super.key, this.style, this.format});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value > 1 ? value - 1 : 0, end: value),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, value, __) => Text(
        format?.call(value.round()) ?? '${value.round()}',
        style: style,
      ),
    );
  }
}

/// A quiet status light instead of the old pulsing glow.
class PulseBadge extends StatelessWidget {
  final Color color;
  final double size;

  const PulseBadge({super.key, required this.color, this.size = 9});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: .35), width: 3),
        ),
      );
}

/// Compatibility alias for the old gradient action button.
class GlowButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Gradient? gradient;
  final bool expanded;

  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.gradient,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: expanded ? double.infinity : null,
        child: PaperButton(label, icon: icon, onPressed: onPressed),
      );
}

class SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Widget? trailing;

  const SearchBox({
    super.key,
    required this.controller,
    this.hint = 'Search…',
    this.onChanged,
    this.onClear,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => PaperField(
        controller: controller,
        label: hint,
        icon: Icons.search_rounded,
        onSubmitted: onChanged,
        suffix: trailing ??
            (controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 19),
                    onPressed: onClear,
                  )),
      );
}

class TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback? onTap;
  final bool dense;

  const TagChip(
    this.label, {
    super.key,
    this.selected = false,
    this.color,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final tint = color ?? p.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 9 : 12,
          vertical: dense ? 5 : 7,
        ),
        decoration: BoxDecoration(
          color: selected ? tint : tint.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: tint.withValues(alpha: selected ? 1 : .25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: dense ? 11.5 : 12.5,
            fontWeight: FontWeight.w800,
            color: selected
                ? (tint.computeLuminance() > .5 ? p.ink : p.onPrimary)
                : tint,
          ),
        ),
      ),
    );
  }
}

class BrandBadge extends StatelessWidget {
  final String? name;
  final ItemType type;
  final double size;

  const BrandBadge(
    this.name, {
    super.key,
    this.type = ItemType.login,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) =>
      TypeTile(type, size: size, brandName: name);
}

class CountdownBar extends StatelessWidget {
  final double progress;
  final Color? color;

  const CountdownBar({super.key, required this.progress, this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.linear,
      builder: (_, value, __) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 5,
          backgroundColor: p.surface2,
          color: color ?? p.primary,
        ),
      ),
    );
  }
}

/// Live 2FA card. Ticks once a second and copies the current code.
class TotpCard extends StatefulWidget {
  final Entry entry;

  const TotpCard({super.key, required this.entry});

  @override
  State<TotpCard> createState() => _TotpCardState();
}

class _TotpCardState extends State<TotpCard> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _tick = Totp.remaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = Totp.remaining();
      if (left != _tick) setState(() => _tick = left);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final entry = widget.entry;
    final code = Totp.code(entry.totpSecret);
    final left = Totp.remaining();
    final progress = Totp.progress();

    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_rounded, color: p.primary, size: 19),
              const SizedBox(width: 8),
              Text(
                'One-time code',
                style: TextStyle(
                  color: p.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TagChip(
                '${left}s',
                dense: true,
                color: left < 6 ? Paper.red : p.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => copyText(context, code, '2FA code'),
            child: Row(
              children: [
                Text(
                  code.isEmpty
                      ? '------'
                      : '${code.substring(0, 3)} ${code.substring(3)}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    letterSpacing: 2,
                    color: p.ink,
                  ),
                ),
                const Spacer(),
                Icon(Icons.copy_rounded, color: p.muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CountdownBar(progress: progress),
        ],
      ),
    );
  }
}
