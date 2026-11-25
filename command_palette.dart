import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'detail_screen.dart';
import 'generator_screen.dart';
import 'health_screen.dart';
import 'models.dart';
import 'nav.dart';
import 'shell.dart';
import 'store.dart';
import 'widgets.dart';

/// A Spotlight/Command-K style launcher. Search every item, or run an action
/// without leaving the keyboard.
void showCommandPalette(BuildContext context) {
  final rootContext = context;
  final nav = Navigator.of(rootContext);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 14,
        top: 12,
      ),
      child: _CommandPaletteSheet(rootContext: rootContext, nav: nav),
    ),
  );
}

class _CommandPaletteSheet extends StatefulWidget {
  final BuildContext rootContext;
  final NavigatorState nav;

  const _CommandPaletteSheet({required this.rootContext, required this.nav});

  @override
  State<_CommandPaletteSheet> createState() => _CommandPaletteSheetState();
}

class _CommandPaletteSheetState extends State<_CommandPaletteSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final q = _controller.text.trim().toLowerCase();
    final entries = Store.instance.entries.where((e) {
      if (q.isEmpty) return true;
      return e.searchText.contains(q);
    }).toList()
      ..sort((a, b) => b.updated.compareTo(a.updated));

    final commands = <_Command>[
      _Command(
          Icons.add_rounded,
          'Add a new item',
          'Create a login, card or note',
          (_) => showAddSheet(widget.rootContext)),
      _Command(Icons.bolt_rounded, 'Generate a password', 'Strong or memorable',
          (_) => widget.nav.push(smoothRoute(const GeneratorScreen()))),
      _Command(
          Icons.shield_rounded,
          'Vault health report',
          'Find weak & reused passwords',
          (_) => widget.nav.push(smoothRoute(const HealthScreen()))),
      _Command(Icons.password_rounded, 'Autofill settings',
          'Fill passwords automatically', (_) => AppNav.tab.value = 2),
      _Command(Icons.lock_rounded, 'Lock the vault now',
          'Require your PIN again', (_) => Store.instance.lockNow()),
      _Command(Icons.sync_rounded, 'Sync with the cloud',
          'Upload encrypted changes', (_) => Store.instance.syncNow()),
    ].where((c) {
      if (q.isEmpty) return true;
      return '${c.title} ${c.subtitle}'.toLowerCase().contains(q);
    }).toList();

    Widget row(IconData icon, Color color, String title, String sub,
        VoidCallback onTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                PaperIcon(icon, color: color, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: Paper.serif,
                              color: p.ink,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.muted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: p.muted, size: 18),
              ],
            ),
          ),
        ),
      );
    }

    return PaperSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            cursorColor: p.primary,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: p.ink, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search vault or type a command…',
              hintStyle: TextStyle(
                  color: p.muted.withValues(alpha: .65), fontSize: 14),
              prefixIcon: Icon(Icons.bolt_rounded, color: p.primary, size: 20),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (_, v, __) => v.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon:
                            Icon(Icons.close_rounded, size: 19, color: p.muted),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                      ),
              ),
              filled: true,
              fillColor: p.surface2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: p.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: p.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: p.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (MediaQuery.of(context).size.height -
                      MediaQuery.of(context).viewInsets.bottom) *
                  .5,
            ),
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                if (commands.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 0, 4),
                    child: PaperLabel('ACTIONS'),
                  ),
                  for (final c in commands)
                    row(c.icon, p.primary, c.title, c.subtitle,
                        () => c.run(widget.rootContext)),
                ],
                if (entries.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 0, 4),
                    child: PaperLabel('VAULT  ·  ${entries.length}'),
                  ),
                  for (final e in entries.take(30))
                    row(
                      e.type.icon,
                      e.type.tint,
                      e.name,
                      e.subtitle.isEmpty ? e.type.label : e.subtitle,
                      () =>
                          widget.nav.push(smoothRoute(DetailScreen(id: e.id))),
                    ),
                ],
                if (commands.isEmpty && entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 26, 20, 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PaperIcon(Icons.search_off_rounded,
                            color: p.muted, size: 48),
                        const SizedBox(height: 14),
                        Text('No results found for "$q"',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.muted, fontSize: 13)),
                      ],
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

class _Command {
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext context) run;
  const _Command(this.icon, this.title, this.subtitle, this.run);
}

/// Ctrl/⌘ + K from anywhere in the shell.
class CommandShortcut extends StatelessWidget {
  final Widget child;
  const CommandShortcut({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            _OpenCommandIntent(),
      },
      child: Actions(
        actions: {
          _OpenCommandIntent: CallbackAction<_OpenCommandIntent>(
            onInvoke: (_) {
              showCommandPalette(context);
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _OpenCommandIntent extends Intent {
  const _OpenCommandIntent();
}
