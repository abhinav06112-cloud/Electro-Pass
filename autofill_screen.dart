import 'package:flutter/material.dart';

import 'autofill.dart';
import 'detail_screen.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Autofill setup + a list of EVERY login so you can see what autofill can use.
class AutofillScreen extends StatefulWidget {
  const AutofillScreen({super.key});

  @override
  State<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends State<AutofillScreen>
    with WidgetsBindingObserver {
  bool _native = true;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final ok = !AutofillBridge.supported || await AutofillBridge.ping();
    final pending = await AutofillBridge.pendingCount();
    await Store.instance.refreshAutofillSystem();
    if (!mounted) return;
    setState(() {
      _native = ok;
      _pending = pending;
    });
    if (Store.instance.autofillSystem && Store.instance.autofillOn) {
      Store.instance.syncAutofill();
    }
  }

  Future<void> _openSettings() async {
    Store.instance.expectExternal();
    final r = await AutofillBridge.openSettings();
    if (!mounted) return;
    if (r == 'missing') {
      Store.instance.clearExternal();
      setState(() => _native = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Native autofill code is missing in this build. See the setup card below.')));
    }
  }

  Future<void> _toggle(bool v) async {
    await Store.instance.setAutofill(v);
    if (v && AutofillBridge.supported) await _openSettings();
  }

  Future<void> _editSite(Entry e) async {
    final p = context.pal;
    final c = TextEditingController(text: e.url);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: p.line),
        ),
        title: Text('Website for ${e.name}',
            style: TextStyle(
                color: p.ink,
                fontFamily: Paper.serif,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Focus(
              autofocus: true,
              child: PaperField(
                controller: c,
                label: 'Website',
                hint: 'instagram.com',
                icon: Icons.link_rounded,
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(height: 10),
            Text('Autofill uses this to know where the login belongs.',
                style: TextStyle(fontSize: 12.5, color: p.muted)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      TextStyle(color: p.muted, fontWeight: FontWeight.w700))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Save',
                  style: TextStyle(
                      color: p.primary, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok == true) {
      e.data['url'] = c.text.trim();
      await Store.instance.upsert(e);
    }
    c.dispose();
  }

  Future<void> _importPending() async {
    final n = await Store.instance.importPending();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Nothing new to import right now.'
            : 'Imported $n login${n == 1 ? '' : 's'} into your encrypted vault.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final s = Store.instance;
        final p = context.pal;
        final accent = p.primary;
        final supported = AutofillBridge.supported;
        final system = s.autofillSystem;
        final needsStep = s.autofillOn && supported && _native && !system;
        final active = s.autofillOn && (!supported || (system && _native));
        final logins = s.entries.where((e) => e.type == ItemType.login).toList()
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final ready = logins
            .where((e) => e.url.isNotEmpty && e.password.isNotEmpty)
            .length;

        final String title = !s.autofillOn
            ? 'Autofill is off'
            : (!_native && supported)
                ? 'Setup needed'
                : needsStep
                    ? 'One more step'
                    : 'Autofill is on';
        final String sub = !s.autofillOn
            ? 'Turn it on to fill passwords anywhere on your phone.'
            : (!_native && supported)
                ? "The native service is bundled in this build, but Android hasn't enabled it yet."
                : needsStep
                    ? 'Pick Electro Pass in the Android autofill screen to finish.'
                    : supported
                        ? 'Electro Pass will offer to fill and save your logins in apps and sites.'
                        : 'Your setting is saved. System autofill itself works on Android phones.';

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 130),
              children: [
                PageHeader(
                  'Autofill',
                  trailing: PaperIcon(Icons.password_rounded,
                      color: accent, size: 44, filled: true),
                ),
                const SizedBox(height: 18),
                FadeSlide(
                  child: _status(
                      title: title,
                      sub: sub,
                      active: active,
                      autofillOn: s.autofillOn,
                      supported: supported),
                ),
                if (supported && !_native) ...[
                  const SizedBox(height: 14),
                  _setupCard(),
                ],
                const SizedBox(height: 14),
                _toggleCard(s),
                if (supported) ...[
                  const SizedBox(height: 14),
                  _pendingCard(),
                ],
                const SizedBox(height: 18),
                _loginsCard(context, logins, ready),
                const SizedBox(height: 14),
                _infoCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _status({
    required String title,
    required String sub,
    required bool active,
    required bool autofillOn,
    required bool supported,
  }) {
    final p = context.pal;
    final tone = active
        ? p.green
        : autofillOn
            ? p.gold
            : p.muted;
    return PaperCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaperIcon(
                active ? Icons.check_rounded : Icons.password_rounded,
                color: tone,
                size: 54,
                filled: active,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaperLabel('Status', color: tone),
                    const SizedBox(height: 6),
                    Text(title,
                        style: TextStyle(
                            color: p.ink,
                            fontFamily: Paper.serif,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(sub,
              style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.45)),
          if (supported && autofillOn && !active) ...[
            const SizedBox(height: 16),
            PaperOutlineButton(
              'Open Android autofill settings',
              icon: Icons.settings_suggest_rounded,
              onPressed: _openSettings,
            ),
          ],
        ],
      ),
    );
  }

  /// Corrected guidance: the native service ships with the app; Android must
  /// be told to use it. No dart-tool or setup script instructions here.
  Widget _setupCard() {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaperLabel('Setup needed', color: p.red),
          const SizedBox(height: 10),
          Text('Autofill service not active',
              style: TextStyle(
                  color: p.ink,
                  fontFamily: Paper.serif,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            "The native service is bundled in this build, but Android hasn't enabled it yet. Reinstall the app, then choose Electro Pass as your autofill provider:",
            style: TextStyle(color: p.muted, fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 12),
          PaperCard(
            inset: true,
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              '1. Uninstall and reinstall Electro Pass\n'
              '2. Open Android Settings\n'
              '3. Search for "Autofill"\n'
              '4. Select Electro Pass as the provider',
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.55,
                  color: p.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleCard(Store s) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
      child: Theme(
        data: Theme.of(context).copyWith(switchTheme: _switchTheme(p)),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Autofill passwords',
                  style: TextStyle(
                      color: p.ink, fontSize: 15, fontWeight: FontWeight.w800)),
              subtitle: Text('Fill and save logins in other apps and sites',
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
              value: s.autofillOn,
              onChanged: _toggle,
            ),
            Divider(height: 1, color: p.line.withValues(alpha: .6)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Ask before filling',
                  style: TextStyle(
                      color: p.ink, fontSize: 15, fontWeight: FontWeight.w800)),
              subtitle: Text('Shows a Yes / No prompt every time',
                  style: TextStyle(color: p.muted, fontSize: 12.5)),
              value: s.autofillConfirm,
              onChanged: s.setAutofillConfirm,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingCard() {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaperIcon(Icons.download_rounded, color: p.primary, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaperLabel('Saved by Android', color: p.primary),
                    const SizedBox(height: 6),
                    Text(
                      _pending == 0
                          ? 'No passwords waiting'
                          : '$_pending password${_pending == 1 ? '' : 's'} waiting',
                      style: TextStyle(
                          color: p.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _pending == 0
                          ? 'New logins will appear here.'
                          : 'Import them into your encrypted vault.',
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_pending > 0) ...[
            const SizedBox(height: 16),
            PaperButton(
              'Import',
              icon: Icons.download_rounded,
              compact: true,
              onPressed: _importPending,
            ),
          ],
        ],
      ),
    );
  }

  Widget _loginsCard(BuildContext context, List<Entry> logins, int ready) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaperLabel('Your logins', color: p.primary),
              const Spacer(),
              Text('$ready of ${logins.length} ready',
                  style: TextStyle(
                      color: p.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          if (logins.isEmpty)
            const EmptyState(
              icon: Icons.password_rounded,
              title: 'No logins yet.',
              message: 'Add one and it will show up here.',
            )
          else
            for (var i = 0; i < logins.length; i++) ...[
              _loginRow(context, logins[i]),
              if (i < logins.length - 1)
                Divider(height: 1, color: p.line.withValues(alpha: .5)),
            ],
        ],
      ),
    );
  }

  Widget _loginRow(BuildContext context, Entry e) {
    final p = context.pal;
    final hasSite = e.url.isNotEmpty;
    final tone = hasSite ? p.green : p.gold;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            Navigator.push(context, smoothRoute(DetailScreen(id: e.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              BrandBadge(e.name, type: ItemType.login, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      e.username.isNotEmpty
                          ? e.username
                          : (hasSite ? e.url : 'No username'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TagChip(
                hasSite ? 'Ready' : 'Add site',
                dense: true,
                color: tone,
                onTap: () => _editSite(e),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard() {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaperIcon(Icons.public_rounded, color: p.primary, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text('How it works',
                    style: TextStyle(
                        color: p.ink,
                        fontFamily: Paper.serif,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Tap a username or password box in any app or website and choose Electro Pass. '
            'If a login has a website, it is offered first. You can always pick from ALL your logins.\n\n'
            'After you sign in somewhere new, Android asks "Save this login?".\n\n'
            'Chrome ignores other autofill apps until you allow it: Chrome > Settings > Autofill services > Electro Pass.',
            style: TextStyle(color: p.muted, fontSize: 13, height: 1.55),
          ),
        ],
      ),
    );
  }
}

SwitchThemeData _switchTheme(Palette p) => SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onPrimary : p.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.surface2),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
