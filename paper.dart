import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Warm paper-and-ink visual language for Electro Pass.
class Paper {
  Paper._();

  static const Color bg = Color(0xFFF7F3EA);
  static const Color card = Color(0xFFFFFCF6);
  static const Color inset = Color(0xFFF1EBDF);
  static const Color line = Color(0xFFDED6C6);
  static const Color ink = Color(0xFF23262B);
  static const Color muted = Color(0xFF756F65);
  static const Color accent = Color(0xFF2E4A62);
  static const Color clay = Color(0xFFB5654A);
  static const Color gold = Color(0xFFB8862F);
  static const Color green = Color(0xFF3F7A5E);
  static const Color red = Color(0xFFB4433B);

  static const String serif = 'Georgia';

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF40627C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Border get border => Border.all(color: line, width: 1);

  static BoxShadow get shadow => BoxShadow(
        color: ink.withValues(alpha: .055),
        blurRadius: 16,
        offset: const Offset(0, 6),
      );

  static BorderRadius get radius => BorderRadius.circular(22);
}

extension ColorX on Color {
  Color o(double v) => withValues(alpha: v.clamp(0, 1));
}

/// One complete paper palette. All palettes are light by design.
class Palette {
  final String name;
  final bool dark;
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color muted;
  final Color line;
  final Color primary;
  final Color onPrimary;
  final List<Color> hero;

  const Palette(
    this.name, {
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.hero,
  });

  LinearGradient get gradient => LinearGradient(
      colors: hero, begin: Alignment.topLeft, end: Alignment.bottomRight);

  // Shared semantic ink colours, available on every paper palette.
  Color get accent => Paper.accent;
  Color get clay => Paper.clay;
  Color get gold => Paper.gold;
  Color get green => Paper.green;
  Color get red => Paper.red;
  Color get mint => Paper.green;
  Color get cyan => Paper.accent;
  Color get violet => Paper.accent;
  Color get pink => Paper.clay;
  Color get orange => Paper.clay;
}

extension PalCtx on BuildContext {
  Palette get pal =>
      Theme.of(this).extension<PaletteExt>()?.pal ?? appPalettes.first;
}

class PaletteExt extends ThemeExtension<PaletteExt> {
  final Palette pal;
  const PaletteExt(this.pal);

  @override
  PaletteExt copyWith({Palette? pal}) => PaletteExt(pal ?? this.pal);

  @override
  PaletteExt lerp(ThemeExtension<PaletteExt>? other, double t) =>
      other is PaletteExt ? (t < .5 ? this : other) : this;
}

const List<Palette> appPalettes = <Palette>[
  Palette('Ivory',
      dark: false,
      bg: Color(0xFFF7F3EA),
      surface: Color(0xFFFFFCF6),
      surface2: Color(0xFFF1EBDF),
      ink: Color(0xFF23262B),
      muted: Color(0xFF756F65),
      line: Color(0xFFDED6C6),
      primary: Color(0xFF2E4A62),
      onPrimary: Color(0xFFFFFCF6),
      hero: [Color(0xFF2E4A62), Color(0xFF516F86), Color(0xFFB5654A)]),
  Palette('Linen',
      dark: false,
      bg: Color(0xFFF6F4EE),
      surface: Color(0xFFFFFEF9),
      surface2: Color(0xFFEDE9DE),
      ink: Color(0xFF242722),
      muted: Color(0xFF747467),
      line: Color(0xFFDDD8CA),
      primary: Color(0xFF3F6659),
      onPrimary: Color(0xFFFFFEF9),
      hero: [Color(0xFF3F6659), Color(0xFF6E9482), Color(0xFFB79254)]),
  Palette('Parchment',
      dark: false,
      bg: Color(0xFFF8EFDD),
      surface: Color(0xFFFFFAEE),
      surface2: Color(0xFFF2E5CC),
      ink: Color(0xFF2D251A),
      muted: Color(0xFF7C6A51),
      line: Color(0xFFE3D2B4),
      primary: Color(0xFF7A4B32),
      onPrimary: Color(0xFFFFFAEE),
      hero: [Color(0xFF7A4B32), Color(0xFFB07650), Color(0xFFC89B5A)]),
  Palette('Notebook',
      dark: false,
      bg: Color(0xFFF3F5F8),
      surface: Color(0xFFFFFFFF),
      surface2: Color(0xFFE8EDF3),
      ink: Color(0xFF1F2933),
      muted: Color(0xFF6B7885),
      line: Color(0xFFD5DEE8),
      primary: Color(0xFF355C7D),
      onPrimary: Color(0xFFFFFFFF),
      hero: [Color(0xFF355C7D), Color(0xFF6C8EBF), Color(0xFFB5654A)]),
  Palette('Blueprint',
      dark: false,
      bg: Color(0xFFEEF3F7),
      surface: Color(0xFFFBFDFF),
      surface2: Color(0xFFDDE8F0),
      ink: Color(0xFF1B3446),
      muted: Color(0xFF61788A),
      line: Color(0xFFC7D9E5),
      primary: Color(0xFF1E5B84),
      onPrimary: Color(0xFFFFFFFF),
      hero: [Color(0xFF1E5B84), Color(0xFF4E8EB6), Color(0xFF8FB8CE)]),
  Palette('Kraft',
      dark: false,
      bg: Color(0xFFF1E9DC),
      surface: Color(0xFFFDF7EC),
      surface2: Color(0xFFE8DCC8),
      ink: Color(0xFF2E261C),
      muted: Color(0xFF7A6C58),
      line: Color(0xFFD9C9AE),
      primary: Color(0xFF6B5537),
      onPrimary: Color(0xFFFFF8EA),
      hero: [Color(0xFF6B5537), Color(0xFF9A7E54), Color(0xFFC1A273)]),
  Palette('Rose Paper',
      dark: false,
      bg: Color(0xFFFBF1F1),
      surface: Color(0xFFFFFCFC),
      surface2: Color(0xFFF5E2E2),
      ink: Color(0xFF332326),
      muted: Color(0xFF84696E),
      line: Color(0xFFEED3D4),
      primary: Color(0xFF8C4A57),
      onPrimary: Color(0xFFFFFCFC),
      hero: [Color(0xFF8C4A57), Color(0xFFB97A83), Color(0xFFD6A7A5)]),
  Palette('Slate Ink',
      dark: false,
      bg: Color(0xFFF0F1F2),
      surface: Color(0xFFFDFDFD),
      surface2: Color(0xFFE3E6E9),
      ink: Color(0xFF20262B),
      muted: Color(0xFF6C757D),
      line: Color(0xFFD3D8DD),
      primary: Color(0xFF3E4C59),
      onPrimary: Color(0xFFFFFFFF),
      hero: [Color(0xFF3E4C59), Color(0xFF6B7A88), Color(0xFFA8B3BC)]),
];

/// Paper backdrop with faint ruling and a left margin rule.
class PaperBackdrop extends StatelessWidget {
  final Widget child;
  const PaperBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _PaperPainter(p), child: const SizedBox.expand()),
        child,
      ],
    );
  }
}

class _PaperPainter extends CustomPainter {
  final Palette p;
  const _PaperPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);

    final rule = Paint()
      ..color = p.line.withValues(alpha: .22)
      ..strokeWidth = .8;
    for (double y = 28; y < size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rule);
    }

    final margin = Paint()
      ..color = p.primary.withValues(alpha: .07)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(34, 0), Offset(34, size.height), margin);

    canvas.drawCircle(
      Offset(size.width * .94, -size.height * .08),
      size.width * .75,
      Paint()
        ..shader = RadialGradient(
          colors: [
            p.primary.withValues(alpha: .035),
            p.primary.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(size.width * .94, -size.height * .08),
          radius: size.width * .75,
        )),
    );
  }

  @override
  bool shouldRepaint(covariant _PaperPainter old) => old.p != p;
}

/// A calm sheet of paper.
class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final bool bordered;
  final bool inset;
  final Color? tone;

  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.onTap,
    this.bordered = true,
    this.inset = false,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final sheet = Container(
      decoration: BoxDecoration(
        color: tone ?? (inset ? context.pal.surface2 : context.pal.surface),
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: context.pal.line) : null,
        boxShadow: [Paper.shadow],
      ),
      clipBehavior: Clip.antiAlias,
      // A Material between the card decoration and ListTile descendants keeps
      // their ink effects visible instead of painting behind the surface.
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap == null) return sheet;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: sheet,
      ),
    );
  }
}

/// Primary letterpress-style action.
class PaperButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;
  final bool filled;
  final Color? color;

  const PaperButton(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.compact = false,
    this.filled = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final p = context.pal;
    final bg = filled ? (color ?? p.primary) : p.surface;
    final fg = filled ? p.onPrimary : p.ink;
    final radius = compact ? 14.0 : 18.0;

    return Opacity(
      opacity: enabled ? 1 : .55,
      child: Container(
        height: compact ? 46 : 56,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: filled ? null : Border.all(color: p.line),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: p.ink.withValues(alpha: .12),
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(radius),
            child: Center(
              child: loading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) Icon(icon, size: 18, color: fg),
                        if (icon != null) const SizedBox(width: 9),
                        Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 14 : 15.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class PaperOutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;

  const PaperOutlineButton(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.pal.ink,
          side: BorderSide(color: context.pal.line, width: 1.2),
          minimumSize: Size.fromHeight(compact ? 44 : 54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
}

class PaperField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData? icon;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffix;
  final String? hint;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const PaperField({
    super.key,
    required this.controller,
    required this.label,
    this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.hint,
    this.onSubmitted,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      style: TextStyle(color: p.ink, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: p.muted),
        hintStyle: TextStyle(color: p.muted.withValues(alpha: .6)),
        prefixIcon: icon == null ? null : Icon(icon, size: 19, color: p.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: p.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(p.line),
        enabledBorder: _border(p.line),
        focusedBorder: _border(p.primary, 1.6),
      ),
    );
  }

  OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Rounded square icon tile with a thin paper border.
class PaperIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool filled;

  const PaperIcon(
    this.icon, {
    super.key,
    required this.color,
    this.size = 46,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = color.computeLuminance() > .48
        ? context.pal.ink
        : context.pal.onPrimary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(
          color: filled ? color : color.withValues(alpha: .22),
        ),
      ),
      child: Icon(icon, color: filled ? onColor : color, size: size * .46),
    );
  }
}

/// Small uppercase stamp label.
class PaperLabel extends StatelessWidget {
  final String text;
  final Color? color;
  const PaperLabel(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color ?? context.pal.muted,
          fontSize: 10.5,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
        ),
      );
}

class PaperDivider extends StatelessWidget {
  final double height;
  const PaperDivider({super.key, this.height = 1});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Center(
          child: Container(height: 1, color: context.pal.line),
        ),
      );
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? back;

  const PageHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.back,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Row(
      children: [
        if (back != null) ...[
          SizedBox(
            width: 42,
            height: 42,
            child: OutlinedButton(
              onPressed: back,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: p.ink,
                side: BorderSide(color: p.line),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: Paper.serif,
                  color: p.ink,
                  fontSize: 27,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.muted, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class PaperSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  const PaperSheet({super.key, required this.child, this.title});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: p.line),
        boxShadow: [Paper.shadow],
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 18),
                  PageHeader(title!),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ScoreRing extends StatelessWidget {
  final double value;
  final String label;
  final Color? color;
  final double size;

  const ScoreRing({
    super.key,
    required this.value,
    required this.label,
    this.color,
    this.size = 88,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: value.clamp(0, 1),
              strokeWidth: 7,
              backgroundColor: context.pal.surface2,
              color: color ?? context.pal.primary,
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: Paper.serif,
                color: context.pal.ink,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Column(
        children: [
          PaperIcon(icon, color: p.primary, size: 58),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontFamily: Paper.serif,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.muted, height: 1.4),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}
