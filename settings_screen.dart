import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_screen.dart';
import 'pin_screen.dart';
import 'store.dart';
import 'widgets.dart';

/// Settings, laid out as a stack of quiet paper sheets.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final s = Store.instance;
        final p = context.pal;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              children: [
                const _Header(),
                const SizedBox(height: 20),
                _profile(context, s),
                _section('Account & sync'),
                _group(context, [
                  if (!s.cloudConfigured)
                    const _Row(
                      icon: Icons.cloud_off_rounded,
                      title: 'Cloud sync is off',
                      subtitle: 'Add your Supabase keys in lib/config.dart',
                    )
                  else if (s.signedIn) ...[
                    _Row(
                      icon: Icons.account_circle_outlined,
                      title:
                          s.accountEmail.isEmpty ? 'Signed in' : s.accountEmail,
                      subtitle: 'Encrypted cloud backup is on',
                    ),
                    _Row(
                      icon: Icons.sync_rounded,
                      title: 'Sync now',
                      subtitle: s.syncStatus.isEmpty
                          ? 'Tap to sync your vault'
                          : s.syncStatus,
                      trailing: s.syncing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: p.primary),
                            )
                          : null,
                      onTap: s.syncNow,
                    ),
                    _Row(
                      icon: Icons.logout_rounded,
                      title: 'Sign out',
                      subtitle: 'Keeps the vault on this phone, stops syncing',
                      onTap: () => _signOut(context, s),
                    ),
                  ] else
                    _Row(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Sign in to sync',
                      subtitle: 'Back up and use your vault on other phones',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (ctx) => AuthScreen(
                              dismissible: true,
                              onDone: () => Navigator.pop(ctx)),
                        ),
                      ),
                    ),
                ]),
                _section('Security'),
                _group(context, [
                  _Row(
                    icon: Icons.pin_outlined,
                    title: 'Change PIN',
                    subtitle: 'Update your 4-digit PIN',
                    onTap: () => _changePin(context),
                  ),
                  _Row(
                    icon: Icons.lock_clock_outlined,
                    title: 'Auto-lock',
                    subtitle: 'Ask for PIN: ${_lockLabel(s.lockAfterSeconds)}',
                    onTap: () => _pickLock(context, s),
                  ),
                  _Row(
                    icon: Icons.screenshot_monitor_rounded,
                    title: 'Block screenshots',
                    subtitle: 'Hides the app in screenshots and recent apps',
                    trailing: Switch(
                      value: s.secureScreen,
                      activeTrackColor: p.primary,
                      onChanged: s.setSecureScreen,
                    ),
                  ),
                  _Row(
                    icon: Icons.verified_user_outlined,
                    title: 'How your data is protected',
                    subtitle: 'Encryption in plain words',
                    onTap: () => _protection(context),
                  ),
                  _Row(
                    icon: Icons.delete_forever_outlined,
                    title: 'Erase all data',
                    subtitle: 'Remove everything from this phone',
                    danger: true,
                    onTap: () => _erase(context),
                  ),
                ]),
                _section('Theme', color: p.primary),
                _themePicker(s),
                _section('About', color: p.gold),
                _group(context, [
                  _Row(
                    icon: Icons.info_outline_rounded,
                    title: 'Version',
                    trailing: Text(Store.version,
                        style: TextStyle(
                            color: p.muted, fontWeight: FontWeight.w700)),
                  ),
                  _Row(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Send feedback',
                    subtitle: 'Tell us what to improve',
                    onTap: () => _feedback(context),
                  ),
                  _Row(
                    icon: Icons.bolt_outlined,
                    title: 'About Electro Pass',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Electro Pass',
                      applicationVersion: Store.version,
                      applicationIcon: const LogoMark(size: 48),
                      children: const [
                        SizedBox(height: 8),
                        Text(
                            'A minimal password vault. Everything is encrypted '
                            'on your device before optional cloud sync.'),
                      ],
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------ pieces

  Widget _profile(BuildContext context, Store s) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          PaperIcon(Icons.fingerprint_rounded,
              color: p.primary, size: 58, filled: true),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.userName.isEmpty ? 'Your name' : s.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.ink,
                      fontFamily: Paper.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text('${s.entries.length} items protected',
                    style: TextStyle(color: p.muted, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SoftIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'Edit name',
            onTap: () => _editName(context, s),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, {Color? color}) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 26, 0, 10),
        child: PaperLabel(title, color: color),
      );

  Widget _group(BuildContext context, List<Widget> children) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 72,
                endIndent: 18,
                color: p.line.withValues(alpha: .6),
              ),
          ],
        ],
      ),
    );
  }

  Widget _themePicker(Store s) => SizedBox(
        height: 166,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          itemCount: appPalettes.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _themeCard(context, s, i),
        ),
      );

  Widget _themeCard(BuildContext context, Store s, int i) {
    final pal = appPalettes[i];
    final p = context.pal;
    final sel = s.themeIndex == i;
    return GestureDetector(
      onTap: () => s.setThemeIndex(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 132,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [pal.surface, pal.bg],
          ),
          borderRadius: BorderRadius.circular(22),
          border:
              Border.all(color: sel ? pal.primary : p.line, width: sel ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: pal.gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (sel)
                      Icon(Icons.check_rounded, color: pal.onPrimary, size: 26),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: Text(pal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: pal.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                ),
                if (sel)
                  Icon(Icons.check_rounded, color: pal.primary, size: 15),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- actions

  Future<bool?> _confirmDialog(
    BuildContext context,
    String title,
    String message,
    String confirmLabel, {
    Color? color,
  }) {
    final p = context.pal;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.line),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
        contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        actionsPadding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        title: Text(title,
            style: TextStyle(
                color: p.ink,
                fontFamily: Paper.serif,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        content: Text(message,
            style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: color ?? p.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context, Store s) async {
    final ok = await _confirmDialog(
      context,
      'Sign out?',
      'Your vault stays on this phone. It just stops syncing with the cloud until you sign in again.',
      'Sign out',
    );
    if (ok == true) await s.signOut();
  }

  void _protection(BuildContext context) {
    final p = context.pal;
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaperIcon(icon, color: p.primary, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: p.ink, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: TextStyle(
                            fontSize: 12.5, height: 1.4, color: p.muted)),
                  ],
                ),
              ),
            ],
          ),
        );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaperSheet(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PaperLabel('Privacy'),
              const SizedBox(height: 10),
              Text('How your data is protected',
                  style: TextStyle(
                      color: p.ink,
                      fontFamily: Paper.serif,
                      fontSize: 23,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('The short version, without the jargon.',
                  style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 20),
              point(Icons.lock_rounded, 'AES-256 encryption',
                  'Everything is sealed with AES-256-GCM. A wrong key or any tampering makes it unreadable.'),
              point(Icons.key_rounded, 'Your keys stay on your phone',
                  'A random vault key encrypts your data. It is locked by your PIN and, for the cloud, by your account password.'),
              point(Icons.cloud_done_outlined, 'The cloud only sees ciphertext',
                  'Supabase stores scrambled data it cannot read. Only your password or recovery key can open it.'),
              point(Icons.timer_outlined, 'PIN attempt limits',
                  'After 5 wrong PINs the app makes you wait, and the wait grows each time.'),
              point(Icons.info_outline_rounded, 'Be honest about a 4-digit PIN',
                  'A short PIN is only as strong as the lock around your phone. Keep a screen lock on, and use a strong account password.'),
            ],
          ),
        ),
      ),
    );
  }

  static String _lockLabel(int s) => s == 0
      ? 'every time'
      : s < 60
          ? 'after $s seconds away'
          : 'after ${s ~/ 60} minute${s ~/ 60 == 1 ? '' : 's'} away';

  void _pickLock(BuildContext context, Store s) {
    final p = context.pal;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PaperSheet(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PaperLabel('When to lock'),
              const SizedBox(height: 8),
              Text('Auto-lock',
                  style: TextStyle(
                      color: p.ink,
                      fontFamily: Paper.serif,
                      fontSize: 23,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Choose how long the vault stays open.',
                  style: TextStyle(color: p.muted, fontSize: 13)),
              const SizedBox(height: 16),
              for (final v in const [0, 30, 60, 300]) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    s.setLockAfter(v);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
                    child: Row(
                      children: [
                        PaperIcon(
                          Icons.timer_outlined,
                          color: s.lockAfterSeconds == v ? p.primary : p.muted,
                          size: 38,
                          filled: s.lockAfterSeconds == v,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            v == 0
                                ? 'Every time I leave the app'
                                : v < 60
                                    ? 'After $v seconds'
                                    : 'After ${v ~/ 60} minute${v ~/ 60 == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: p.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5),
                          ),
                        ),
                        if (s.lockAfterSeconds == v)
                          Icon(Icons.check_rounded, color: p.primary, size: 20),
                      ],
                    ),
                  ),
                ),
                if (v != 300)
                  Divider(
                      height: 1,
                      indent: 56,
                      color: p.line.withValues(alpha: .6)),
              ],
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _changePin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => PinScreen(
          mode: PinMode.change,
          onSuccess: () {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('PIN updated')));
          },
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, Store s) async {
    final p = context.pal;
    final c = TextEditingController(text: s.userName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.line),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
        contentPadding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        actionsPadding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        title: Text('Your name',
            style: TextStyle(
                color: p.ink,
                fontFamily: Paper.serif,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        content: PaperField(
          controller: c,
          label: 'Shown in your greeting',
          icon: Icons.person_outline_rounded,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save',
                style:
                    TextStyle(color: p.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) await s.setName(c.text);
    c.dispose();
  }

  Future<void> _erase(BuildContext context) async {
    final ok = await _confirmDialog(
      context,
      'Erase everything?',
      'Everything on this phone, including your PIN, will be deleted. Cloud copies are not touched. This cannot be undone.',
      'Erase',
      color: context.pal.red,
    );
    if (ok == true && context.mounted) {
      Navigator.popUntil(context, (r) => r.isFirst);
      await Store.instance.eraseAll();
      Store.instance.lockNow();
    }
  }

  void _feedback(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FeedbackSheet(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PaperLabel('Control center'),
            SizedBox(height: 10),
            PageHeader('Settings', subtitle: 'Small tweaks. A calmer vault.'),
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final accent = danger ? p.red : p.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            PaperIcon(icon, color: accent, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: danger ? p.red : p.ink)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(subtitle!,
                          style: TextStyle(
                              fontSize: 12, height: 1.3, color: p.muted)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                (onTap != null
                    ? Icon(Icons.chevron_right_rounded,
                        color: p.muted, size: 19)
                    : const SizedBox(width: 19)),
          ],
        ),
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  int _stars = 5;
  final _msg = TextEditingController();

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    const subject = 'Electro Pass feedback (v${Store.version})';
    final body = 'Rating: $_stars/5\n\n${_msg.text.trim()}';
    final uri = Uri.parse('mailto:${Store.feedbackEmail}'
        '?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {}
    if (!mounted) return;
    if (!opened) {
      await copyText(context, body, 'Feedback');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return PaperSheet(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PaperLabel('Feedback'),
            const SizedBox(height: 10),
            Text('Send feedback',
                style: TextStyle(
                    color: p.ink,
                    fontFamily: Paper.serif,
                    fontSize: 23,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('How is Electro Pass treating you?',
                style: TextStyle(color: p.muted, fontSize: 13.5)),
            const SizedBox(height: 18),
            PaperCard(
              inset: true,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 44),
                      iconSize: 30,
                      icon: Icon(
                        i <= _stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i <= _stars ? p.gold : p.line,
                      ),
                      onPressed: () => setState(() => _stars = i),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PaperField(
              controller: _msg,
              label: 'Ideas, bugs, anything...',
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            PaperButton('Send feedback',
                icon: Icons.send_rounded, onPressed: _send),
          ],
        ),
      ),
    );
  }
}
