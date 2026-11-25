import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store.dart';
import 'widgets.dart';

/// Sign in / create account (Supabase). Shown once on first run, or from Settings.
class AuthScreen extends StatefulWidget {
  /// true when opened from Settings (shows a close button, no "skip").
  final bool dismissible;
  final VoidCallback? onDone;
  const AuthScreen({super.key, this.dismissible = false, this.onDone});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _rec = TextEditingController();
  final _code = TextEditingController();

  bool _signup = true;
  bool _show = false;
  bool _showRec = false;
  bool _busy = false;
  bool _confirming = false;
  bool _done = false;
  String? _msg;
  bool get _warn => _msg != null && !_msg!.contains('confirmed');

  @override
  void initState() {
    super.initState();
    // A valid session without a local vault key means the confirmation link
    // arrived on a fresh device. Ask for the password instead of offering to
    // create a second account.
    if (Store.instance.signedIn) {
      _signup = false;
      _email.text = Store.instance.accountEmail;
    }
    Store.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    Store.instance.removeListener(_onStoreChanged);
    _email.dispose();
    _pass.dispose();
    _rec.dispose();
    _code.dispose();
    super.dispose();
  }

  /// A confirmation email can return to the app while this screen is open.
  void _onStoreChanged() {
    if (!mounted || _done || !_confirming || _busy) return;
    if (!Store.instance.signedIn) return;
    _busy = true;
    unawaited(_applyResult(Store.instance.finishConfirmation()));
  }

  Future<void> _showRecovery(String key) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final p = ctx.pal;
        return AlertDialog(
          backgroundColor: p.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(color: p.line),
          ),
          title: Row(
            children: [
              PaperIcon(Icons.key_rounded, color: p.gold, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Save your recovery key',
                  style: TextStyle(
                    fontFamily: Paper.serif,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your vault is encrypted with your password. If you ever reset '
                'that password, this key is the only way back in. We cannot '
                'recover it for you.',
                style: TextStyle(height: 1.45, color: p.muted, fontSize: 13.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: p.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.line),
                ),
                child: SelectableText(
                  key,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: p.primary,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => copyText(ctx, key, 'Recovery key'),
              child: Text('Copy', style: TextStyle(color: p.primary)),
            ),
            PaperButton(
              'I saved it',
              compact: true,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  Future<void> _applyResult(Future<AuthResult> work) async {
    final r = await work;
    if (!mounted) return;
    _busy = false;
    if (r.needsConfirmation) {
      setState(() {
        _confirming = true;
        _msg = null;
      });
      return;
    }
    if (r.error != null) {
      setState(() {
        _msg = r.error;
        if (r.error!.contains('recovery key')) _showRec = true;
        if (r.error!.contains('Sign in with your password')) {
          _confirming = false;
          _signup = false;
        }
      });
      return;
    }
    final key = r.recoveryKey ?? Store.instance.lastRecoveryKey;
    if (key != null) await _showRecovery(key);
    if (!mounted) return;
    await Store.instance.completeAuth();
    if (!mounted) return;
    _done = true;
    widget.onDone?.call();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final pass = _pass.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _msg = 'Enter a valid email address.');
      return;
    }
    if (!_signup && pass.isEmpty) {
      setState(() => _msg = 'Enter your password.');
      return;
    }
    if (pass.isNotEmpty && pass.length < 8) {
      setState(() => _msg = 'Use at least 8 characters for your password.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    final s = Store.instance;
    await _applyResult(_signup
        ? s.signUp(email, pass)
        : s.signIn(email, pass, recoveryKey: _rec.text));
  }

  Future<void> _verifyCode() async {
    if (_busy) return;
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _msg = 'Enter the 6-digit code from the email.');
      return;
    }
    setState(() {
      _busy = true;
      _msg = null;
    });
    await _applyResult(
        Store.instance.verifyEmailCode(_email.text.trim(), code));
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    final r = await Store.instance.resendConfirmation(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = r.error ??
          'A fresh link is on its way. It opens Electro Pass directly.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _brandRow(),
              const SizedBox(height: 26),
              FadeSlide(index: 0, child: _hero()),
              const SizedBox(height: 16),
              FadeSlide(
                index: 1,
                child: _confirming ? _confirmationCard() : _formCard(),
              ),
              if (_msg != null) ...[
                const SizedBox(height: 14),
                _message(),
              ],
              const SizedBox(height: 20),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _brandRow() {
    final p = context.pal;
    return Row(
      children: [
        const LogoMark(size: 40),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            'ELECTRO PASS',
            style: TextStyle(
              color: p.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.4,
            ),
          ),
        ),
        if (widget.dismissible)
          SoftIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            size: 42,
            onTap: () => Navigator.pop(context),
          ),
      ],
    );
  }

  Widget _hero() {
    final p = context.pal;
    return PaperCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperLabel('SECURE ACCESS', color: p.primary),
          const SizedBox(height: 14),
          Text(
            'Your passwords,\nbeautifully protected.',
            style: TextStyle(
              fontFamily: Paper.serif,
              color: p.ink,
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in once. After that, just your PIN — '
            'your passwords never leave this device unencrypted.',
            style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    final p = context.pal;
    return PaperCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabs(),
          if (Store.instance.signedIn &&
              !Store.instance.hasPin &&
              Store.instance.pendingVk == null) ...[
            const SizedBox(height: 14),
            _inlineNote(
              'This device is signed in, but its vault key is missing. '
              'Sign in with your password to finish setup.',
            ),
          ],
          const SizedBox(height: 20),
          PaperField(
            controller: _email,
            label: 'Email address',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          PaperField(
            controller: _pass,
            label: _signup ? 'Create a password' : 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: !_show,
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
            suffix: IconButton(
              icon: Icon(
                _show
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: p.muted,
                size: 19,
              ),
              onPressed: () => setState(() => _show = !_show),
            ),
          ),
          if (!_signup && _showRec) ...[
            const SizedBox(height: 12),
            PaperField(
              controller: _rec,
              label: 'Recovery key (optional)',
              icon: Icons.key_rounded,
            ),
          ],
          if (!_signup && !_showRec)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _showRec = true),
                child: Text(
                  'I reset my password',
                  style: TextStyle(color: p.muted, fontSize: 12.5),
                ),
              ),
            ),
          const SizedBox(height: 18),
          PaperButton(
            _signup ? 'Create account' : 'Sign in',
            icon:
                _signup ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
            loading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _confirmationCard() {
    final p = context.pal;
    return PaperCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaperIcon(Icons.mark_email_read_outlined, color: p.green, size: 52),
          const SizedBox(height: 16),
          Text(
            'Confirm your email',
            style: TextStyle(
              fontFamily: Paper.serif,
              color: p.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a link to ${Store.instance.pendingConfirmationEmail ?? _email.text.trim()}. '
            'The link now opens Electro Pass directly, so setup finishes by itself.',
            style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 18),
          PaperField(
            controller: _code,
            label: '6-digit code (optional)',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const SizedBox(height: 14),
          PaperButton(
            'I confirmed — continue',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: () => _applyResult(Store.instance.finishConfirmation()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PaperOutlineButton(
                  'Verify code',
                  icon: Icons.numbers_rounded,
                  compact: true,
                  onPressed: _verifyCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PaperOutlineButton(
                  'Resend',
                  icon: Icons.send_outlined,
                  compact: true,
                  onPressed: _resend,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _confirming = false;
              _signup = false;
              _msg = null;
            }),
            child: Text(
              'Back to sign in',
              style: TextStyle(color: p.muted, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _message() {
    final p = context.pal;
    final color = _warn ? Paper.red : p.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Icon(
            _warn ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _msg!,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                height: 1.35,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    final p = context.pal;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 15, color: p.muted),
            const SizedBox(width: 6),
            Text(
              'End-to-end encrypted (AES-256)',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
          ],
        ),
        if (!widget.dismissible)
          TextButton(
            onPressed: Store.instance.continueOffline,
            child: Text(
              'Continue without an account',
              style: TextStyle(color: p.primary, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }

  Widget _tabs() {
    final p = context.pal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          _tab('Create account', _signup, () => setState(() => _signup = true)),
          _tab('Sign in', !_signup, () => setState(() => _signup = false)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    final p = context.pal;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? p.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            border: selected ? Border.all(color: p.line) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? p.primary : p.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inlineNote(String text) {
    final p = context.pal;
    return PaperCard(
      inset: true,
      radius: 14,
      padding: const EdgeInsets.all(13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: p.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: p.muted, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
