import 'package:flutter/material.dart';

import 'detail_screen.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final p = context.pal;
        final h = Store.instance.health();
        final issues = h.weak.length + h.reused.length + h.old.length;
        final label = h.score >= 80
            ? 'Looking strong'
            : h.score >= 50
                ? 'Could be better'
                : 'Needs attention';
        final tone = h.score >= 80
            ? Paper.green
            : h.score >= 50
                ? Paper.gold
                : Paper.red;
        final summary = h.logins == 0
            ? 'Add some logins to see your score.'
            : issues == 0
                ? 'No weak, reused or old passwords. Nice.'
                : '$issues thing${issues == 1 ? '' : 's'} worth fixing across ${h.logins} logins.';

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              children: [
                const PageHeader(
                  'Vault health',
                  subtitle: 'A quiet check-up for your logins',
                ),
                const SizedBox(height: 18),
                FadeSlide(
                  child: _hero(
                      context, h, issues, label, summary, tone, p.primary),
                ),
                const SizedBox(height: 18),
                FadeSlide(
                  index: 1,
                  child: _section(
                    context,
                    'Weak passwords',
                    Icons.warning_amber_rounded,
                    Paper.red,
                    h.weak,
                    'Short or easy to guess. Make them longer.',
                  ),
                ),
                const SizedBox(height: 14),
                FadeSlide(index: 2, child: _reused(context, h)),
                const SizedBox(height: 14),
                FadeSlide(
                  index: 3,
                  child: _section(
                    context,
                    'Old passwords',
                    Icons.history_rounded,
                    Paper.gold,
                    h.old,
                    'Not changed in over 6 months.',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// One calm summary: the score, its meaning, and two quiet numbers.
  Widget _hero(BuildContext context, Health h, int issues, String label,
      String summary, Color tone, Color accent) {
    final p = context.pal;
    return PaperCard(
      radius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaperLabel('Vault health', color: accent),
                    const SizedBox(height: 10),
                    Text(label,
                        style: TextStyle(
                            color: p.ink,
                            fontFamily: Paper.serif,
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.6)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ScoreRing(
                  value: h.score / 100,
                  label: '${h.score}',
                  color: tone,
                  size: 96),
            ],
          ),
          const SizedBox(height: 16),
          Text(summary,
              style: TextStyle(color: p.muted, fontSize: 13.5, height: 1.45)),
          const SizedBox(height: 18),
          const PaperDivider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat(context, '${h.logins}', 'Logins checked')),
              Container(width: 1, height: 30, color: p.line),
              Expanded(child: _stat(context, '$issues', 'To fix')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                color: p.ink,
                fontFamily: Paper.serif,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(color: p.muted, fontSize: 11.5)),
      ],
    );
  }

  Widget _head(BuildContext context, String title, IconData icon, Color tone,
      int n, String hint) {
    final p = context.pal;
    final c = n == 0 ? Paper.green : tone;
    return Row(
      children: [
        PaperIcon(icon, color: c, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: p.ink,
                      fontFamily: Paper.serif,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(hint,
                  maxLines: 2,
                  style: TextStyle(color: p.muted, fontSize: 12, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: .25)),
          ),
          child: Text('$n',
              style: TextStyle(
                  color: c, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _allClear() => const EmptyState(
        icon: Icons.check_circle_rounded,
        title: 'All clear',
        message: 'Nothing to fix here.',
      );

  Widget _section(BuildContext context, String title, IconData icon, Color tone,
      List<Entry> list, String hint) {
    return PaperCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _head(context, title, icon, tone, list.length, hint),
          if (list.isEmpty) ...[
            const SizedBox(height: 6),
            _allClear(),
          ] else ...[
            const SizedBox(height: 14),
            const PaperDivider(),
            for (final e in list) _row(context, e, tone),
          ],
        ],
      ),
    );
  }

  Widget _reused(BuildContext context, Health h) {
    final entries = h.reused.expand((g) => g).toList();
    return _section(
      context,
      'Reused passwords',
      Icons.copy_all_rounded,
      context.pal.primary,
      entries,
      'The same password on several accounts is risky.',
    );
  }

  Widget _row(BuildContext context, Entry e, Color tone) {
    final p = context.pal;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            Navigator.push(context, smoothRoute(DetailScreen(id: e.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 28,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
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
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(e.subtitle.isEmpty ? e.type.label : e.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
            ],
          ),
        ),
      ),
    );
  }
}
