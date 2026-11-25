import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_edit_screen.dart';
import 'doc_viewer.dart';
import 'models.dart';
import 'nav.dart';
import 'store.dart';
import 'widgets.dart';

class DetailScreen extends StatefulWidget {
  final String id;
  const DetailScreen({super.key, required this.id});
  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _show = false;
  Entry? _last;

  Future<void> _delete(Entry e) async {
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
    if (ok == true && mounted) {
      Navigator.pop(context);
      await Store.instance.remove(e.id);
    }
  }

  int _reuseCount(Entry e) => e.password.isEmpty
      ? 0
      : Store.instance.entries
          .where((x) =>
              x.id != e.id &&
              x.type == ItemType.login &&
              x.password == e.password)
          .length;

  bool _isSite(String u) =>
      u.contains('.') &&
      !RegExp(r'^(com|org|net|in|io|app)\.[a-z0-9_]+\.[a-z0-9_.]+$',
              caseSensitive: false)
          .hasMatch(u);

  Future<void> _openSite(String url) async {
    var u = url.trim();
    if (!u.startsWith('http')) u = 'https://$u';
    Store.instance.expectExternal();
    try {
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final e = Store.instance.byId(widget.id) ?? _last;
        if (e == null) return const Scaffold();
        _last = e;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                _hero(context, e),
                const SizedBox(height: 16),
                _actions(context, e),
                if (e.type == ItemType.card) ...[
                  const SizedBox(height: 20),
                  _cardVisual(context, e),
                ],
                if (e.hasTotp) ...[
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: PaperLabel('ONE-TIME CODE'),
                  ),
                  const SizedBox(height: 10),
                  TotpCard(entry: e),
                ],
                const SizedBox(height: 20),
                _fieldsCard(context, e),
                if (e.custom.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _customCard(context, e),
                ],
                if (e.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _tags(context, e),
                ],
                if (e.notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _textCard(context, 'Notes', e.notes),
                ],
                if (e.type == ItemType.login && e.password.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _strengthCard(context, e),
                ],
                if (e.images.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _photos(context, e),
                ],
                const SizedBox(height: 22),
                Center(
                  child: Text('Updated ${ago(e.updated)}',
                      style: TextStyle(fontSize: 12, color: context.pal.muted)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------- hero

  Widget _hero(BuildContext context, Entry e) {
    final p = context.pal;
    final t = e.type;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _heroButton(context, Icons.arrow_back_rounded, 'Back',
                  () => Navigator.pop(context)),
              const Spacer(),
              _heroButton(
                context,
                e.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                'Favorite',
                () => Store.instance.toggleFav(e.id),
                color: e.favorite ? Paper.gold : p.ink,
              ),
              const SizedBox(width: 8),
              _heroButton(
                context,
                Icons.edit_outlined,
                'Edit',
                () => Navigator.push(
                    context, smoothRoute(AddEditScreen(entry: e))),
              ),
              const SizedBox(width: 8),
              _heroButton(context, Icons.delete_outline_rounded, 'Delete',
                  () => _delete(e),
                  color: Paper.red),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                BrandBadge(e.name, type: t, size: 72),
                const SizedBox(height: 14),
                Text(e.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Paper.serif,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                      letterSpacing: -.6,
                    )),
                const SizedBox(height: 4),
                Text(
                  e.subtitle.isEmpty || t == ItemType.note
                      ? t.label
                      : '${t.label}  ·  ${e.subtitle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: p.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroButton(
          BuildContext context, IconData icon, String tip, VoidCallback onTap,
          {Color? color}) =>
      Tooltip(
        message: tip,
        child: Material(
          color: context.pal.surface,
          shape: CircleBorder(side: BorderSide(color: context.pal.line)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, size: 19, color: color ?? context.pal.ink),
            ),
          ),
        ),
      );

  // ---------------------------------------------------------------- actions

  Widget _actions(BuildContext context, Entry e) {
    final children = <Widget>[];
    if (e.type == ItemType.document) {
      if (e.images.isNotEmpty) {
        children.add(Expanded(
          child: PaperButton(
            e.type.copyLabel,
            icon: Icons.photo_library_rounded,
            onPressed: () => Navigator.push(
                context, smoothRoute(DocViewer(ids: e.images, index: 0))),
          ),
        ));
      }
    } else if (e.primaryValue.isNotEmpty) {
      children.add(Expanded(
        child: PaperButton(e.type.copyLabel,
            icon: Icons.copy_rounded,
            onPressed: () => copyText(context, e.primaryValue, e.type.label)),
      ));
    }
    if (e.type == ItemType.login && e.url.isNotEmpty && _isSite(e.url)) {
      if (children.isNotEmpty) children.add(const SizedBox(width: 10));
      children.add(Expanded(
        child: PaperOutlineButton('Open site',
            icon: Icons.open_in_new_rounded, onPressed: () => _openSite(e.url)),
      ));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(children: children);
  }

  // ------------------------------------------------------------ section cards

  Widget _cardVisual(BuildContext context, Entry e) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: PaperLabel('CARD', color: Paper.clay),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _show = !_show),
            child: CardVisual(entry: e, reveal: _show),
          ),
          const SizedBox(height: 8),
          Text('Tap the card to ${_show ? 'hide' : 'reveal'} the number',
              style: TextStyle(fontSize: 12, color: context.pal.muted)),
        ],
      );

  Widget _fieldsCard(BuildContext context, Entry e) {
    final defs = e.type.fields.where((d) => e.f(d.key).isNotEmpty).toList();
    if (defs.isEmpty) return const SizedBox.shrink();
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaperLabel('DETAILS', color: p.primary),
          const SizedBox(height: 10),
          for (var i = 0; i < defs.length; i++) ...[
            _fieldRow(context, e, defs[i]),
            if (i != defs.length - 1)
              Divider(height: 1, indent: 44, color: p.line),
          ],
        ],
      ),
    );
  }

  Widget _fieldRow(BuildContext context, Entry e, FieldDef d) {
    final p = context.pal;
    final raw = e.f(d.key);
    final isCardNum = e.type == ItemType.card && d.key == 'number';
    String shown;
    if (d.secret && !_show) {
      shown =
          isCardNum ? maskedCard(raw, false) : '•' * math.min(raw.length, 16);
    } else {
      shown = raw;
    }
    final copyVal = isCardNum ? raw.replaceAll(' ', '') : raw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 4, 10),
      child: Row(
        children: [
          PaperIcon(d.icon, color: p.primary, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label, style: TextStyle(fontSize: 11.5, color: p.muted)),
                const SizedBox(height: 3),
                Text(shown,
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                        fontFamily: d.secret ? 'monospace' : null,
                        letterSpacing: d.secret ? 1 : 0)),
              ],
            ),
          ),
          if (d.secret)
            IconButton(
              icon: Icon(
                  _show
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: p.muted),
              onPressed: () => setState(() => _show = !_show),
            ),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 19, color: p.muted),
            onPressed: () => copyText(context, copyVal, d.label),
          ),
        ],
      ),
    );
  }

  Widget _customCard(BuildContext context, Entry e) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaperLabel('EXTRA FIELDS', color: p.primary),
          const SizedBox(height: 14),
          for (final entry in e.custom.entries) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key,
                          style: TextStyle(fontSize: 11.5, color: p.muted)),
                      const SizedBox(height: 3),
                      Text(entry.value,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: p.ink)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy_rounded, size: 19, color: p.muted),
                  onPressed: () => copyText(context, entry.value, entry.key),
                ),
              ],
            ),
            if (entry.key != e.custom.keys.last)
              Divider(height: 1, color: p.line),
          ],
        ],
      ),
    );
  }

  Widget _tags(BuildContext context, Entry e) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PaperLabel('TAGS', color: p.primary),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in e.tags)
                TagChip(t, color: p.primary, onTap: () {
                  AppNav.tag.value = t;
                  Navigator.pop(context);
                  AppNav.tab.value = 1;
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textCard(BuildContext context, String label, String value) {
    final p = context.pal;
    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PaperLabel(label.toUpperCase(), color: p.primary),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(fontSize: 15, height: 1.45, color: p.ink)),
          ],
        ),
      ),
    );
  }

  Color _strengthColor(int level) {
    if (level >= 4) return Paper.green;
    if (level >= 3) return Paper.accent;
    if (level >= 2) return Paper.gold;
    return Paper.red;
  }

  Widget _strengthCard(BuildContext context, Entry e) {
    final p = context.pal;
    final reuse = _reuseCount(e);
    final c = _strengthColor(e.strength);
    final filled = math.max(e.strength, 1);
    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Password strength',
                  style: TextStyle(fontSize: 12.5, color: p.muted)),
              Text(kStrengthLabels[e.strength],
                  style: TextStyle(fontWeight: FontWeight.w800, color: c)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(4, (i) {
              return Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: i < filled ? c : p.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text('Estimated crack time: ${crackTimeLabel(e.password)}',
              style: TextStyle(fontSize: 12.5, color: p.muted)),
          if (e.hasTotp)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.qr_code_rounded, size: 15, color: p.primary),
                  const SizedBox(width: 6),
                  Text('Two-factor authentication is enabled',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: p.primary,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          if (reuse > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('Reused in $reuse other item${reuse == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Paper.gold)),
            ),
        ],
      ),
    );
  }

  Widget _photos(BuildContext context, Entry e) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: PaperLabel('PHOTOS (${e.images.length})'),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (var i = 0; i < e.images.length; i++)
                GestureDetector(
                  onTap: () => Navigator.push(
                      context, smoothRoute(DocViewer(ids: e.images, index: i))),
                  child: DocThumb(e.images[i]),
                ),
            ],
          ),
        ],
      );
}
