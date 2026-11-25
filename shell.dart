import 'package:flutter/material.dart';

import 'add_edit_screen.dart';
import 'autofill_screen.dart';
import 'command_palette.dart';
import 'generator_screen.dart';
import 'home_screen.dart';
import 'models.dart';
import 'nav.dart';
import 'settings_screen.dart';
import 'vault_screen.dart';
import 'widgets.dart';

/// Four-tab bottom navigation with a central add button.
class Shell extends StatelessWidget {
  const Shell({super.key});

  static const _pages = <Widget>[
    HomeScreen(),
    VaultScreen(),
    AutofillScreen(),
    SettingsScreen(),
  ];

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.lock_outlined, Icons.lock_rounded, 'Vault'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Autofill'),
    (Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return CommandShortcut(
      child: ValueListenableBuilder<int>(
        valueListenable: AppNav.tab,
        builder: (context, tab, _) {
          final p = context.pal;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Give the pages the full screen. A Scaffold bottom bar can
                // collapse this height to zero, which hides all page content.
                Positioned.fill(
                  child: IndexedStack(index: tab, children: _pages),
                ),
                // The navigation pill floats above the pages instead.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  // Only the pill itself is a hit target; the rest of this
                  // overlay lets taps through to the page underneath.
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 288),
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              color: p.surface.o(.88),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: p.line.o(.85)),
                              boxShadow: [
                                BoxShadow(
                                  color: p.ink.o(.08),
                                  blurRadius: 22,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                for (final i in const [0, 1])
                                  _navItem(context, tab, i),
                                _addButton(context),
                                for (final i in const [2, 3])
                                  _navItem(context, tab, i),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _navItem(BuildContext context, int tab, int index) {
    final (outlined, filled, label) = _tabs[index];
    final p = context.pal;
    final selected = tab == index;

    return Expanded(
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => AppNav.tab.value = index,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? filled : outlined,
                size: 19,
                color: selected ? p.primary : p.muted,
              ),
              const SizedBox(height: 5),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? p.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _addButton(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => showAddSheet(context),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: p.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: p.ink.o(.16),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: p.onPrimary, size: 24),
        ),
      ),
    );
  }
}

/// "What do you want to add?" paper sheet.
void showAddSheet(BuildContext context) {
  final p = context.pal;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
        child: PaperSheet(
          title: 'Add to your vault',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PaperLabel('NEW ENTRY'),
              const SizedBox(height: 6),
              Text(
                'Choose what you want to protect.',
                style: TextStyle(color: p.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 112,
                ),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final type in ItemType.values)
                    PaperCard(
                      radius: 20,
                      padding: const EdgeInsets.all(14),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          smoothRoute(AddEditScreen(type: type)),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PaperIcon(type.icon, color: type.tint, size: 40),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.ink,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                type.blurb,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: p.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              PaperCard(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    smoothRoute(const GeneratorScreen()),
                  );
                },
                child: Row(
                  children: [
                    const PaperIcon(Icons.bolt_rounded,
                        color: Paper.gold, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Generate a strong password',
                        style: TextStyle(
                          color: p.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
