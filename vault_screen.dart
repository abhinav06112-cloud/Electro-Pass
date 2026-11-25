import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'item_tile.dart';
import 'models.dart';
import 'nav.dart';
import 'shell.dart';
import 'store.dart';
import 'widgets.dart';

/// Every item, with search, filters, sorting and swipe actions.
class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _search = TextEditingController();
  bool _favOnly = false;

  @override
  void initState() {
    super.initState();
    _search.text = AppNav.query.value;
    _search.addListener(_onSearchChanged);
    AppNav.query.addListener(_syncQuery);
    AppNav.tag.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppNav.tag.removeListener(_rebuild);
    AppNav.query.removeListener(_syncQuery);
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    final v = _search.text;
    if (AppNav.query.value != v) AppNav.query.value = v;
    setState(() {});
  }

  void _syncQuery() {
    if (!mounted || _search.text == AppNav.query.value) return;
    setState(() => _search.text = AppNav.query.value);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _pickSort(BuildContext context) async {
    final p = context.pal;
    final picked = await showMenu<VaultSort>(
      context: context,
      position: RelativeRect.fromLTRB(
          MediaQuery.of(context).size.width - 110, 120, 12, 0),
      color: p.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.line),
      ),
      items: [
        for (final v in VaultSort.values)
          PopupMenuItem(
            value: v,
            child: Text(v.label, style: TextStyle(color: p.ink)),
          ),
      ],
    );
    if (picked != null) AppNav.sort.value = picked;
  }

  List<Entry> _filtered(Store s, ItemType? type, VaultSort sort) {
    final words = _search.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final list = s.entries.where((e) {
      if (type != null && e.type != type) return false;
      if (_favOnly && !e.favorite) return false;
      if (AppNav.tag.value.isNotEmpty && !e.tags.contains(AppNav.tag.value)) {
        return false;
      }
      if (words.isEmpty) return true;
      final hay = '${e.searchText} ${e.type.label.toLowerCase()}';
      return words.every(hay.contains);
    }).toList();
    list.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      switch (sort) {
        case VaultSort.recent:
          return b.updated.compareTo(a.updated);
        case VaultSort.strength:
          return a.strength.compareTo(b.strength);
        case VaultSort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return list;
  }

  List<String> get _allTags {
    final tags = <String>{};
    for (final e in Store.instance.entries) {
      tags.addAll(e.tags);
    }
    final out = tags.toList()..sort();
    return out;
  }

  Future<bool> _confirmDelete(Entry e) async {
    final p = context.pal;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.line),
        ),
        title: Text('Delete ${e.type.label.toLowerCase()}?',
            style: TextStyle(
                fontFamily: Paper.serif,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: p.ink)),
        content: Text('"${e.name}" will be removed from your vault.',
            style: TextStyle(color: p.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: p.muted))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Paper.red))),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final s = Store.instance;
        return ValueListenableBuilder<ItemType?>(
          valueListenable: AppNav.filter,
          builder: (context, type, _) {
            return ValueListenableBuilder<VaultSort>(
              valueListenable: AppNav.sort,
              builder: (context, sort, _) {
                final list = _filtered(s, type, sort);
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: SafeArea(
                    bottom: false,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => FocusScope.of(context).unfocus(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                              child: _filterCard(context, s, type, sort),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: list.isEmpty
                                ? _empty(context, s.entries.isNotEmpty)
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 0, 20, 120),
                                    itemCount: list.length,
                                    itemBuilder: (_, i) => FadeSlide(
                                      index: i,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: _swipeable(context, list[i]),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------ filter card

  Widget _filterCard(
      BuildContext context, Store s, ItemType? type, VaultSort sort) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            'Vault',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: p.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${s.entries.length}',
                      style: TextStyle(
                          color: p.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
                const SizedBox(width: 8),
                _roundButton(
                  context,
                  icon: Icons.sort_rounded,
                  tip: 'Sort: ${sort.label}',
                  color: p.primary,
                  onTap: () => _pickSort(context),
                ),
                const SizedBox(width: 8),
                _roundButton(
                  context,
                  icon: _favOnly
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  tip: 'Favorites only',
                  color: _favOnly ? Paper.gold : p.muted,
                  onTap: () => setState(() => _favOnly = !_favOnly),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _searchField(p),
          const SizedBox(height: 14),
          const PaperLabel('CATEGORIES'),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip('All', type == null, p, () => AppNav.filter.value = null),
                for (final t in ItemType.values)
                  _chip(t.plural, type == t, p, () => AppNav.filter.value = t),
              ],
            ),
          ),
          if (_allTags.isNotEmpty) ...[
            const SizedBox(height: 12),
            const PaperLabel('TAGS'),
            const SizedBox(height: 8),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _tagPill('All tags', AppNav.tag.value.isEmpty, p, () {
                    AppNav.tag.value = '';
                  }),
                  for (final tag in _allTags)
                    _tagPill(tag, AppNav.tag.value == tag, p, () {
                      AppNav.tag.value = AppNav.tag.value == tag ? '' : tag;
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField(Palette p) => PaperField(
        controller: _search,
        label: 'Search names, notes, tags, fields…',
        icon: Icons.search_rounded,
        suffix: _search.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
                onPressed: () {
                  _search.clear();
                  AppNav.query.value = '';
                  setState(() {});
                },
              ),
      );

  Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required String tip,
    required VoidCallback onTap,
    Color? color,
  }) {
    final p = context.pal;
    return Tooltip(
      message: tip,
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 18, color: color ?? p.muted),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool sel, Palette p, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TagChip(
          label,
          selected: sel,
          color: p.primary,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
        ),
      );

  Widget _tagPill(String label, bool sel, Palette p, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TagChip(
          label,
          selected: sel,
          dense: true,
          color: p.primary,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
        ),
      );

  // ----------------------------------------------------------- swipe + list

  Widget _swipeable(BuildContext context, Entry e) {
    Widget bg(Alignment a, IconData icon, Color c) {
      final p = context.pal;
      return Container(
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: p.onPrimary, size: 26),
      );
    }

    return Dismissible(
      key: ValueKey('dismiss_${e.id}'),
      background: bg(
          Alignment.centerLeft,
          e.favorite ? Icons.star_outline_rounded : Icons.star_rounded,
          Paper.gold),
      secondaryBackground:
          bg(Alignment.centerRight, Icons.delete_outline_rounded, Paper.red),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          HapticFeedback.mediumImpact();
          await Store.instance.toggleFav(e.id);
          return false;
        }
        return _confirmDelete(e);
      },
      onDismissed: (_) => Store.instance.remove(e.id),
      child: ItemTile(e),
    );
  }

  Widget _empty(BuildContext context, bool hasAny) => EmptyState(
        icon: hasAny ? Icons.search_off_rounded : Icons.lock_outline_rounded,
        title: hasAny ? 'No matches' : 'Your vault is empty',
        message: hasAny
            ? 'Try another search or filter.'
            : 'Tap Add to save your first item.',
        action: hasAny
            ? null
            : PaperButton(
                'Add item',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: () => showAddSheet(context),
              ),
      );
}
