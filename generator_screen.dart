import 'package:flutter/material.dart';

import 'models.dart';
import 'widgets.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

enum _Mode { random, passphrase }

class _GeneratorScreenState extends State<GeneratorScreen> {
  _Mode _mode = _Mode.random;
  double _len = 20;
  double _words = 4;
  bool _upper = true, _digits = true, _symbols = true;
  bool _avoid = true, _capitalize = false, _addNumber = true;
  String _sep = '-';
  late String _pw = _make();

  String _make() => _mode == _Mode.random
      ? generatePassword(
          length: _len.round(),
          upper: _upper,
          digits: _digits,
          symbols: _symbols,
          avoidAmbiguous: _avoid,
        )
      : generatePassphrase(
          words: _words.round(),
          separator: _sep,
          capitalize: _capitalize,
          addNumber: _addNumber,
        );

  void _regen() => setState(() => _pw = _make());

  SwitchThemeData _switchTheme(Color accent) {
    final p = context.pal;
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.muted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? accent.withValues(alpha: .55)
              : p.line),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final level = passwordStrength(_pw);
    final entropy = passwordEntropy(_pw);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            const PageHeader(
              'Password studio',
              subtitle: 'Strong secrets, made on this device',
            ),
            const SizedBox(height: 18),
            FadeSlide(child: _preview(level, entropy)),
            const SizedBox(height: 18),
            FadeSlide(index: 1, child: _controls()),
            const SizedBox(height: 20),
            _actions(),
          ],
        ),
      ),
    );
  }

  /// The one bright surface: the generated secret and its strength.
  Widget _preview(int level, double entropy) {
    final p = context.pal;
    final tone = strengthColor(level);

    return PaperCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaperLabel(
                _mode == _Mode.random ? 'New password' : 'New passphrase',
                color: p.primary,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: p.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.primary.withValues(alpha: .25)),
                ),
                child: Text('${_pw.length} chars',
                    style: TextStyle(
                        color: p.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 26),
          SelectableText(
            _pw,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.ink,
              fontSize: 25,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 26),
          StrengthBar(level),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(kStrengthLabels[level],
                  style: TextStyle(
                      color: tone, fontSize: 13, fontWeight: FontWeight.w800)),
              const Spacer(),
              Flexible(
                child: Text(
                  '${entropy.round()} bits · ${crackTimeLabel(_pw)}',
                  textAlign: TextAlign.right,
                  style:
                      TextStyle(color: p.muted, fontSize: 11.5, height: 1.25),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Everything that shapes the secret lives in one quiet card.
  Widget _controls() {
    final p = context.pal;
    final accent = p.primary;
    return PaperCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(
                  value: _Mode.random,
                  label: Text('Random'),
                  icon: Icon(Icons.shuffle_rounded)),
              ButtonSegment(
                  value: _Mode.passphrase,
                  label: Text('Memorable'),
                  icon: Icon(Icons.auto_awesome_rounded)),
            ],
            selected: {_mode},
            onSelectionChanged: (v) {
              _mode = v.first;
              _regen();
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected)
                      ? accent.withValues(alpha: .10)
                      : Colors.transparent),
              foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? accent : p.muted),
              side: WidgetStateProperty.all(BorderSide(color: p.line)),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
              padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 11, horizontal: 6)),
            ),
          ),
          const SizedBox(height: 14),
          const PaperDivider(),
          const SizedBox(height: 14),
          if (_mode == _Mode.random) ...[
            _slider('Length', _len, 8, 64, accent, (v) {
              _len = v;
              _regen();
            }),
            const SizedBox(height: 10),
            _toggle('Uppercase letters', _upper, accent, (v) {
              _upper = v;
              _regen();
            }),
            _toggle('Numbers', _digits, accent, (v) {
              _digits = v;
              _regen();
            }),
            _toggle('Symbols', _symbols, accent, (v) {
              _symbols = v;
              _regen();
            }),
            _toggle('Avoid look-alike characters', _avoid, accent, (v) {
              _avoid = v;
              _regen();
            }),
          ] else ...[
            _slider('Words', _words, 3, 8, accent, (v) {
              _words = v;
              _regen();
            }),
            const SizedBox(height: 8),
            _separators(accent),
            const SizedBox(height: 8),
            _toggle('Capitalize words', _capitalize, accent, (v) {
              _capitalize = v;
              _regen();
            }),
            _toggle('Add a number', _addNumber, accent, (v) {
              _addNumber = v;
              _regen();
            }),
          ],
        ],
      ),
    );
  }

  Widget _slider(String label, double value, double min, double max,
      Color accent, ValueChanged<double> onChanged) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: p.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${value.round()}',
                  style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            inactiveTrackColor: p.line,
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: .14),
            valueIndicatorColor: accent,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _separators(Color accent) {
    final p = context.pal;
    const choices = ['-', '_', '.', ' '];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Separator',
            style: TextStyle(
                color: p.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < choices.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      setState(() => _sep = choices[i]);
                      _regen();
                    },
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _sep == choices[i]
                            ? accent.withValues(alpha: .12)
                            : p.surface2,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _sep == choices[i]
                              ? accent.withValues(alpha: .7)
                              : p.line,
                        ),
                      ),
                      child: Text(choices[i] == ' ' ? 'space' : choices[i],
                          style: TextStyle(
                              color: _sep == choices[i] ? accent : p.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _toggle(
      String label, bool value, Color accent, ValueChanged<bool> on) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: p.ink, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Theme(
            data: Theme.of(context).copyWith(switchTheme: _switchTheme(accent)),
            child: Switch(value: value, onChanged: on),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    final p = context.pal;
    return Row(
      children: [
        Expanded(
          child: PaperButton(
            'Copy',
            icon: Icons.copy_rounded,
            onPressed: () => copyText(context, _pw, 'Password'),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _regen,
            borderRadius: BorderRadius.circular(27),
            child: Tooltip(
              message: 'Generate again',
              child:
                  PaperIcon(Icons.refresh_rounded, color: p.primary, size: 54),
            ),
          ),
        ),
      ],
    );
  }
}
