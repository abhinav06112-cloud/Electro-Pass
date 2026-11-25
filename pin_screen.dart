import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'widgets.dart';

enum PinMode { create, unlock, change }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final VoidCallback onSuccess;
  const PinScreen({super.key, required this.mode, required this.onSuccess});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  String _pin = '';
  String? _first;
  String? _error;
  int _step = 0;
  bool _busy = false;
  bool _checking = false;
  String? _old;

  List<String> get _titles => switch (widget.mode) {
        PinMode.create => ['Create your PIN', 'Confirm your PIN'],
        PinMode.unlock => ['Welcome back'],
        PinMode.change => ['Current PIN', 'New PIN', 'Confirm new PIN'],
      };

  List<String> get _subs => switch (widget.mode) {
        PinMode.create => [
            'Pick 4 digits. You\'ll use it every time you open the app.',
            'Enter it once more to confirm'
          ],
        PinMode.unlock => ['Enter your PIN to unlock your vault'],
        PinMode.change => [
            'Enter your current PIN',
            'Choose a new 4-digit PIN',
            'Enter the new PIN again'
          ],
      };

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _press(String d) {
    if (_busy || _pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) _submit();
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _next() => setState(() {
        _step++;
        _pin = '';
      });

  void _fail(String msg) {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
    setState(() {
      _error = msg;
      _pin = '';
    });
  }

  Future<void> _submit() async {
    _busy = true;
    if (mounted) setState(() => _checking = true);
    final s = Store.instance;
    final pin = _pin;
    try {
      switch (widget.mode) {
        case PinMode.unlock:
          final r = await s.unlock(pin);
          if (!mounted) return;
          if (r == UnlockResult.ok) {
            widget.onSuccess();
          } else if (r == UnlockResult.locked) {
            _fail('Too many tries. Wait ${s.lockRemaining}s');
          } else {
            _fail('Wrong PIN, try again');
          }
        case PinMode.create:
          if (_step == 0) {
            _first = pin;
            _next();
          } else if (pin == _first) {
            await s.createPin(pin);
            if (mounted) widget.onSuccess();
          } else {
            _first = null;
            setState(() => _step = 0);
            _fail("PINs didn't match. Start again");
          }
        case PinMode.change:
          if (_step == 0) {
            if (await s.checkPin(pin)) {
              _old = pin;
              _next();
            } else {
              _fail('Wrong PIN, try again');
            }
          } else if (_step == 1) {
            _first = pin;
            _next();
          } else if (pin == _first) {
            final ok = await s.changePin(_old ?? '', pin);
            if (!mounted) return;
            if (ok) {
              widget.onSuccess();
            } else {
              _fail('Could not change the PIN');
            }
          } else {
            _first = null;
            setState(() => _step = 1);
            _fail("PINs didn't match");
          }
      }
    } finally {
      _busy = false;
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.mode == PinMode.change)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 0, 0),
                        child: SoftIconButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Close',
                          size: 44,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                  Center(child: _lockHeader(p.primary)),
                  _keypad(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Your PIN never leaves this device',
                      style: TextStyle(color: p.muted, fontSize: 11.5),
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

  Widget _lockHeader(Color accent) {
    final p = context.pal;
    final label = switch (widget.mode) {
      PinMode.create => 'SET UP YOUR PIN',
      PinMode.unlock => 'SECURE ACCESS',
      PinMode.change => 'UPDATE SECURITY',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: accent.withValues(alpha: .26)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const PaperCard(
          radius: 24,
          padding: EdgeInsets.all(16),
          child: LogoMark(size: 58),
        ),
        const SizedBox(height: 16),
        Text(
          _titles[_step],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Paper.serif,
            color: p.ink,
            fontSize: 29,
            fontWeight: FontWeight.w700,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            _subs[_step],
            textAlign: TextAlign.center,
            style: TextStyle(color: p.muted, fontSize: 14, height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        _pinDots(accent),
        SizedBox(
          height: 30,
          child: Center(
            child: Text(
              _checking ? 'Checking…' : (_error ?? ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _checking ? p.muted : p.red,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Four simple dots, centered like a banking app.
  Widget _pinDots(Color accent) {
    final p = context.pal;
    return AnimatedBuilder(
      animation: _shake,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          math.sin(_shake.value * math.pi * 5) * 12 * (1 - _shake.value),
          0,
        ),
        child: child,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _pin.length ? accent : p.surface2,
                border: Border.all(
                  color: i < _pin.length ? accent : p.line,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _keypad() {
    final p = context.pal;
    Widget digit(String x) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _key(
            Text(
              x,
              style: TextStyle(
                  fontSize: 29, fontWeight: FontWeight.w600, color: p.ink),
            ),
            () => _press(x),
          ),
        );

    Widget row(List<String> d) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final x in d) digit(x)],
          ),
        );

    return Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(width: 74, height: 74),
              ),
              digit('0'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _key(
                  Icon(Icons.backspace_outlined, size: 25, color: p.muted),
                  _back,
                  onLong: () => setState(() => _pin = ''),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _key(Widget child, VoidCallback onTap, {VoidCallback? onLong}) {
    final p = context.pal;
    return SizedBox(
      width: 74,
      height: 74,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.surface,
          border: Border.all(color: p.line),
          boxShadow: [Paper.shadow],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            onLongPress: onLong,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
