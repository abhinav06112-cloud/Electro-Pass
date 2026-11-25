import 'package:flutter/material.dart';

import 'autofill.dart';
import 'command_palette.dart';
import 'detail_screen.dart';
import 'generator_screen.dart';
import 'health_screen.dart';
import 'models.dart';
import 'nav.dart';
import 'shell.dart';
import 'store.dart';
import 'widgets.dart';

/// A quiet, centred home: brand, greeting, one overview, then recent items.
/// Everything else lives one tap away in the vault, autofill or settings tabs.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    if (h < 22) return 'Good evening,';
    return 'Good night,';
  }

  String _today() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Stack(
      children: [
        // Soft light from the top of the page.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [p.surface.o(.62), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
              ),
            ),
          ),
        ),
        // Oversized letterpress monogram, barely there.
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: const Alignment(0, -.52),
              child: Opacity(
                opacity: .045,
                child: Text(
                  'EP',
                  style: TextStyle(
                    fontFamily: Paper.serif,
                    fontSize: 232,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -18,
                    color: p.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                if (Store.instance.signedIn) await Store.instance.syncNow();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 132),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: ListenableBuilder(
                        listenable: Store.instance,
                        builder: (context, _) {
                          final s = Store.instance;
                          final recent = [...s.entries]
                            ..sort((a, b) => b.updated.compareTo(a.updated));
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _brand(context),
                              const SizedBox(height: 42),
                              _greetingBlock(context, s),
                              const SizedBox(height: 32),
                              FadeSlide(child: _overview(context, s)),
                              const SizedBox(height: 30),
                              _recentHeader(context, s),
                              const SizedBox(height: 6),
                              FadeSlide(
                                index: 1,
                                child: _recent(context, recent),
                              ),
                              const SizedBox(height: 26),
                              FadeSlide(
                                index: 2,
                                child: _quickActions(context, s),
                              ),
                              if (AutofillBridge.supported &&
                                  !s.autofillSystem) ...[
                                const SizedBox(height: 12),
                                _autofillHint(context),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ brand

  Widget _brand(BuildContext context) {
    final p = context.pal;
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: p.primary,
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: p.ink.o(.12),
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(Icons.fingerprint_rounded, size: 19, color: p.onPrimary),
        ),
        const SizedBox(height: 11),
        Text(
          'ELECTRO PASS',
          style: TextStyle(
            fontSize: 9.5,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w900,
            color: p.muted,
          ),
        ),
        const SizedBox(height: 14),
        Container(width: 34, height: 1, color: p.primary.o(.45)),
      ],
    );
  }

  // --------------------------------------------------------------- greeting

  Widget _greetingBlock(BuildContext context, Store s) {
    final p = context.pal;
    final name = s.userName.trim().isEmpty ? 'there' : s.userName.trim();
    return Column(
      children: [
        Text(
          _today(),
          style: TextStyle(
            fontSize: 9.5,
            letterSpacing: 2,
            fontWeight: FontWeight.w800,
            color: p.muted,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _greeting(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Paper.serif,
            fontSize: 39,
            height: 1.08,
            letterSpacing: -1.5,
            color: p.ink,
          ),
        ),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: Paper.serif,
            fontStyle: FontStyle.italic,
            fontSize: 39,
            height: 1.08,
            letterSpacing: -1.5,
            color: p.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          s.entries.isEmpty
              ? 'A quiet place for everything that matters.'
              : 'Everything is in its place.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: p.muted),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- overview

  Widget _overview(BuildContext context, Store s) {
    final p = context.pal;
    final h = s.health();
    final hasLogins = h.logins > 0;
    final label = !hasLogins
        ? 'A fresh start'
        : h.score >= 80
            ? 'Looking strong'
            : h.score >= 50
                ? 'Could be better'
                : 'Needs care';
    final sync = s.syncStatus.isEmpty
        ? (s.signedIn ? 'Cloud sync on' : 'Private on this phone')
        : s.syncStatus;

    return PaperCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(21, 20, 21, 18),
      onTap: () => Navigator.push(context, smoothRoute(const HealthScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              PaperLabel('OVERVIEW', color: p.primary),
              const Spacer(),
              Text(
                hasLogins ? '${h.score}' : '--',
                style: TextStyle(
                  fontFamily: Paper.serif,
                  fontSize: 30,
                  letterSpacing: -.8,
                  color: p.primary,
                ),
              ),
              Text(' / 100', style: TextStyle(fontSize: 11, color: p.muted)),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: TextStyle(
              fontFamily: Paper.serif,
              fontSize: 20,
              color: p.ink,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 3,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: hasLogins ? h.score / 100 : 0,
                  child: Container(color: p.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            '${s.entries.length} items protected · $sync',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: p.muted),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- recent

  Widget _recentHeader(BuildContext context, Store s) {
    final p = context.pal;
    return Row(
      children: [
        const PaperLabel('RECENT'),
        const Spacer(),
        if (s.entries.isNotEmpty)
          GestureDetector(
            onTap: () => AppNav.openVault(),
            child: Text(
              'View all',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: p.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _recent(BuildContext context, List<Entry> recent) {
    if (recent.isEmpty) {
      return EmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'Nothing here yet',
        message: 'Passwords, cards, IDs and more live here.',
        action: PaperButton(
          'Add your first item',
          icon: Icons.add_rounded,
          compact: true,
          onPressed: () => showAddSheet(context),
        ),
      );
    }
    return Column(
      children: [
        Container(height: 1, color: context.pal.line.o(.7)),
        for (var i = 0; i < recent.length && i < 3; i++) ...[
          _recentRow(context, recent[i]),
          if (i < 2 && i < recent.length - 1)
            Container(height: 1, color: context.pal.line.o(.55)),
        ],
      ],
    );
  }

  Widget _recentRow(BuildContext context, Entry e) {
    final p = context.pal;
    final time = ago(e.updated).replaceFirst(' ago', '');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            Navigator.push(context, smoothRoute(DetailScreen(id: e.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          child: Row(
            children: [
              BrandBadge(e.name, type: e.type, size: 38),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Paper.serif,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.subtitle.isEmpty ? e.type.label : e.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: p.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(time, style: TextStyle(fontSize: 10, color: p.muted)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ quick tools

  Widget _quickActions(BuildContext context, Store s) {
    return PaperCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Row(
            children: [
              _quick(context, Icons.search_rounded, 'Search',
                  () => showCommandPalette(context)),
              _quick(
                  context,
                  Icons.bolt_rounded,
                  'Generate',
                  () => Navigator.push(
                        context,
                        smoothRoute(const GeneratorScreen()),
                      )),
              _quick(context, Icons.password_rounded, 'Autofill',
                  () => AppNav.tab.value = 2),
              _quick(context, Icons.add_rounded, 'Add',
                  () => showAddSheet(context)),
            ],
          ),
          const SizedBox(height: 10),
          const PaperDivider(),
          Row(
            children: [
              if (s.signedIn)
                Expanded(
                  child: _miniLink(
                    context,
                    s.syncing ? 'Syncing…' : 'Sync now',
                    s.syncNow,
                  ),
                ),
              Expanded(
                child: _miniLink(
                  context,
                  'Lock now',
                  () => Store.instance.lockNow(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quick(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    final p = context.pal;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Icon(icon, size: 19, color: p.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniLink(BuildContext context, String label, VoidCallback onTap) =>
      TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: context.pal.primary,
          ),
        ),
      );

  Widget _autofillHint(BuildContext context) {
    final p = context.pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => AppNav.tab.value = 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: p.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              Icon(Icons.password_rounded, size: 17, color: p.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finish autofill setup',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                    Text(
                      'Pick Electro Pass as your autofill app',
                      style: TextStyle(fontSize: 10.5, color: p.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
