import 'package:flutter/material.dart';

import 'widgets.dart';

/// The first-run chapters. Everything on a page comes from here.
class _PageData {
  final String tag;
  final String title;
  final String body;
  final IconData icon;
  final Color accent;

  const _PageData({
    required this.tag,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
  });
}

const _pages = <_PageData>[
  _PageData(
    tag: 'PRIVATE BY DESIGN',
    icon: Icons.fingerprint_rounded,
    accent: Paper.accent,
    title: 'A quiet place\nfor everything',
    body: 'Passwords, cards, bank details, IDs, notes and documents. '
        'All behind one PIN, on your own device.',
  ),
  _PageData(
    tag: 'SEALED TIGHT',
    icon: Icons.lock_rounded,
    accent: Paper.green,
    title: 'Encrypted.\nOnly yours.',
    body: 'Your vault is locked with AES-256 before it ever leaves your phone. '
        'We can\'t read it.',
  ),
  _PageData(
    tag: 'ALWAYS WITH YOU',
    icon: Icons.auto_awesome_rounded,
    accent: Paper.clay,
    title: 'Autofill and\nphoto documents',
    body: 'Fill logins in other apps with one tap, and keep encrypted photos '
        'of your important papers.',
  ),
  _PageData(
    tag: 'A CLEARER PICTURE',
    icon: Icons.health_and_safety_outlined,
    accent: Paper.gold,
    title: 'A checkup for\nyour vault',
    body: 'Spot weak, reused and aging passwords at a glance, then tighten '
        'things up one by one. The check happens on your device.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_i == _pages.length - 1) {
      widget.onDone();
    } else {
      _pc.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_i == 0) return;
    _pc.previousPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _page(_PageData data) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _FeatureArt(data),
                  const SizedBox(height: 30),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: data.accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(30),
                      border:
                          Border.all(color: data.accent.withValues(alpha: .26)),
                    ),
                    child: Text(
                      data.tag,
                      style: TextStyle(
                        color: data.accent,
                        fontSize: 10,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: Paper.serif,
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: context.pal.ink,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Text(
                      data.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: context.pal.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
              child: Row(
                children: [
                  const LogoMark(size: 34),
                  const SizedBox(width: 10),
                  Text(
                    'ELECTRO PASS',
                    style: TextStyle(
                      color: p.muted,
                      fontSize: 10.5,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: p.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _i = i),
                children: [for (final page in _pages) _page(page)],
              ),
            ),
            _indicators(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
              child: Row(
                children: [
                  if (_i > 0) ...[
                    SizedBox(
                      width: 108,
                      child: PaperOutlineButton(
                        'Back',
                        icon: Icons.arrow_back_rounded,
                        compact: true,
                        onPressed: _back,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: PaperButton(
                      _i == _pages.length - 1 ? 'Get started' : 'Next',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicators() {
    final p = context.pal;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final on = i == _i;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: on ? 26 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: on ? p.primary : p.line,
            borderRadius: BorderRadius.circular(8),
          ),
        );
      }),
    );
  }
}

/// A stacked paper sheet illustration, kept flat and ink-stamped.
class _FeatureArt extends StatelessWidget {
  final _PageData page;
  const _FeatureArt(this.page);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return SizedBox(
      width: 260,
      height: 230,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: .94, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => Transform.scale(
          scale: v,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: 34,
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: p.surface2,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: p.line),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: 18,
                child: Container(
                  height: 178,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(26),
                    border:
                        Border.all(color: page.accent.withValues(alpha: .28)),
                    boxShadow: [Paper.shadow],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PaperIcon(page.icon,
                          color: page.accent, size: 78, filled: true),
                      const SizedBox(height: 18),
                      Container(
                        width: 94,
                        height: 6,
                        decoration: BoxDecoration(
                          color: page.accent.withValues(alpha: .28),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: p.line,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
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
