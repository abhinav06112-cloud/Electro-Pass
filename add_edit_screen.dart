import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'doc_viewer.dart';
import 'docs.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

/// Editor for a new or existing vault entry.
///
/// The item type is chosen before this screen opens (by the shell's type
/// picker, or carried in from a restored draft). Changing it here would
/// invalidate the field controllers, so the type stays fixed for the session.
class AddEditScreen extends StatefulWidget {
  final Entry? entry;
  final ItemType? type;
  final Draft? draft;

  const AddEditScreen({super.key, this.entry, this.type, this.draft})
      : assert(entry != null || type != null || draft != null);

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _form = GlobalKey<FormState>();

  late final Draft? _d = widget.draft;
  late final Entry? _orig = widget.entry ??
      (_d?.entryId != null ? Store.instance.byId(_d!.entryId!) : null);
  late final ItemType _t = _orig?.type ?? _d?.itemType ?? widget.type!;

  late final TextEditingController _name =
      TextEditingController(text: _d?.name ?? _orig?.name);
  late final TextEditingController _notes =
      TextEditingController(text: _d?.notes ?? _orig?.notes);
  late final Map<String, TextEditingController> _ctl = {
    for (final f in _t.fields)
      f.key: TextEditingController(
          text: _d != null ? (_d.data[f.key] ?? '') : _orig?.f(f.key)),
  };
  final Set<String> _revealed = {};
  late final List<String> _images = [...?(_d?.images ?? _orig?.images)];
  late final List<String> _added = [...?_d?.added];
  late final List<String> _removed = [...?_d?.removed];
  late final List<String> _tags = [
    ...?(_d?.tags ?? _orig?.tags),
  ];
  late final Map<String, String> _custom = Map<String, String>.from(
      _d?.custom ?? _orig?.custom ?? <String, String>{});
  final _tagInput = TextEditingController();
  final _customKey = TextEditingController();
  final _customValue = TextEditingController();

  bool _dirty = false;
  bool _saved = false;
  bool _busy = false;
  Timer? _debounce;

  bool get _editing => _orig != null;

  /// One steady ink colour keeps the form calm; the type tile carries the tint.
  Color get _accent => context.pal.primary;

  @override
  void initState() {
    super.initState();
    Store.instance.editorOpen = true;
    if (_d != null) _dirty = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLost());
  }

  @override
  void dispose() {
    Store.instance.editorOpen = false;
    _debounce?.cancel();
    _name.dispose();
    _notes.dispose();
    _tagInput.dispose();
    _customKey.dispose();
    _customValue.dispose();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------- draft: never lose unsaved work ----------

  void _touch() {
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _persistDraft);
  }

  void _persistDraft() {
    if (_saved) return;
    Store.instance.saveDraft(Draft(
      type: _t.name,
      entryId: _orig?.id,
      name: _name.text,
      data: {for (final f in _t.fields) f.key: _ctl[f.key]!.text},
      notes: _notes.text,
      images: List<String>.from(_images),
      added: List<String>.from(_added),
      removed: List<String>.from(_removed),
      tags: List<String>.from(_tags),
      custom: Map<String, String>.from(_custom),
    ));
  }

  Future<void> _discard() async {
    _debounce?.cancel();
    for (final id in _added) {
      await DocStore.delete(id);
    }
    await Store.instance.clearDraft();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _debounce?.cancel();
    _saved = true;
    final old = _orig;
    await Store.instance.upsert(Entry(
      id: old?.id ?? newId(),
      type: _t,
      name: _name.text.trim(),
      data: {for (final f in _t.fields) f.key: _ctl[f.key]!.text.trim()},
      notes: _t.hasNotes ? _notes.text.trim() : '',
      favorite: old?.favorite ?? false,
      images: List<String>.from(_images),
      tags: List<String>.from(_tags),
      custom: Map<String, String>.from(_custom),
    ));
    for (final id in _removed) {
      await DocStore.delete(id);
    }
    await Store.instance.clearDraft();
    _dirty = false;
    if (mounted) Navigator.pop(context);
  }

  // ---------- photos ----------

  Future<void> _addFiles(List<dynamic> files) async {
    for (final x in files) {
      final bytes = await (x as XFile).readAsBytes();
      final id = await DocStore.save(bytes);
      _added.add(id);
      _images.add(id);
    }
  }

  Future<void> _recoverLost() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android ||
        !_t.supportsImages) {
      return;
    }
    try {
      final dynamic r = await ImagePicker().retrieveLostData();
      if (r.isEmpty == true) return;
      final files = <dynamic>[];
      try {
        final fs = r.files;
        if (fs != null) files.addAll(fs as List);
      } catch (_) {}
      if (files.isEmpty) {
        try {
          final f = r.file;
          if (f != null) files.add(f);
        } catch (_) {}
      }
      if (files.isEmpty) return;
      await _addFiles(files);
      _touch();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _pickImages() async {
    final p = context.pal;
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaperSheet(
        title: 'Add a photo',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PaperIcon(Icons.photo_camera_outlined,
                  color: p.primary, size: 40),
              title: Text('Take a photo',
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PaperIcon(Icons.photo_library_outlined,
                  color: p.primary, size: 40),
              title: Text('Choose from gallery',
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w700)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    setState(() => _busy = true);
    try {
      // The picker leaves the app. Tell the lock not to kick in meanwhile,
      // and save a draft first in case the phone closes the app.
      _persistDraft();
      await Store.instance.runExternal<void>(() async {
        final picker = ImagePicker();
        List<dynamic> files;
        if (src == ImageSource.camera) {
          final x = await picker.pickImage(
              source: src, imageQuality: 80, maxWidth: 2000);
          files = x == null ? <dynamic>[] : <dynamic>[x];
        } else {
          files = await picker.pickMultiImage(imageQuality: 80, maxWidth: 2000);
        }
        await _addFiles(files);
      });
      _touch();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't add that photo")));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  // ---------- UI helpers ----------

  Entry _preview() => Entry(
        id: 'preview',
        type: _t,
        name: _name.text.trim().isEmpty
            ? _t.nameHint.replaceFirst('e.g. ', '')
            : _name.text.trim(),
        data: {for (final f in _t.fields) f.key: _ctl[f.key]!.text},
      );

  /// A form field that keeps the validator, live preview updates and every
  /// custom formatter this screen needs, dressed in the paper palette.
  Widget _formField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    Widget? suffix,
    required ValueChanged<String> onChanged,
    String? Function(String?)? validator,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    int minLines = 1,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter> inputFormatters = const <TextInputFormatter>[],
  }) {
    final p = context.pal;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: p.line),
    );
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(color: p.ink, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: maxLines > 1,
        labelStyle: TextStyle(color: p.muted),
        hintStyle: TextStyle(color: p.muted.withValues(alpha: .6)),
        prefixIcon: icon == null ? null : Icon(icon, size: 19, color: p.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: p.surface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.red.withValues(alpha: .8)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.red, width: 1.6),
        ),
      ),
    );
  }

  Widget _secretSuffix(FieldDef d) {
    final p = context.pal;
    final c = _ctl[d.key]!;
    final hidden = d.secret && !_revealed.contains(d.key);
    final isLoginPass = _t == ItemType.login && d.key == 'password';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: hidden ? 'Reveal' : 'Hide',
          icon: Icon(
            hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            size: 20,
            color: p.muted,
          ),
          onPressed: () => setState(() {
            if (!_revealed.remove(d.key)) _revealed.add(d.key);
          }),
        ),
        if (isLoginPass)
          IconButton(
            tooltip: 'Generate a strong password',
            icon: Icon(Icons.bolt_rounded, size: 20, color: p.primary),
            onPressed: () {
              setState(() {
                c.text = generatePassword();
                _revealed.add(d.key);
              });
              _touch();
            },
          ),
      ],
    );
  }

  Widget _strengthMeter(int level) {
    final color = strengthColor(level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StrengthBar(level),
        const SizedBox(height: 8),
        Text(
          kStrengthLabels[level.clamp(0, 4)],
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _fieldInput(FieldDef d) {
    final p = context.pal;
    final c = _ctl[d.key]!;
    final hidden = d.secret && !_revealed.contains(d.key);
    final isLoginPass = _t == ItemType.login && d.key == 'password';
    final isCardNumber = _t == ItemType.card && d.key == 'number';
    final isExpiry = _t == ItemType.card && d.key == 'expiry';
    final isShortDigits =
        _t == ItemType.card && (d.key == 'cvv' || d.key == 'pin');
    final level = passwordStrength(c.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _formField(
          controller: c,
          label: d.label,
          icon: d.multiline ? null : d.icon,
          hint: d.hint.isEmpty ? null : d.hint,
          obscure: hidden,
          suffix: d.secret ? _secretSuffix(d) : null,
          keyboardType: d.multiline ? TextInputType.multiline : d.keyboard,
          minLines: d.multiline ? (d.key == 'text' ? 7 : 2) : 1,
          maxLines: d.multiline ? (d.key == 'text' ? 14 : 4) : 1,
          textCapitalization: (d.key == 'holder' || d.key == 'fullname')
              ? TextCapitalization.words
              : (d.multiline
                  ? TextCapitalization.sentences
                  : TextCapitalization.none),
          inputFormatters: [
            if (isCardNumber) CardNumberFormatter(),
            if (isExpiry) ExpiryFormatter(),
            if (isShortDigits) FilteringTextInputFormatter.digitsOnly,
            if (isShortDigits) LengthLimitingTextInputFormatter(4),
          ],
          onChanged: (_) {
            setState(() {});
            _touch();
          },
          validator: d.required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
              : null,
        ),
        if (isLoginPass && c.text.isNotEmpty) ...[
          const SizedBox(height: 14),
          _strengthMeter(level),
        ],
        if (isCardNumber && c.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4),
            child: Text(
              cardBrand(c.text),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: p.muted,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _fields(List<FieldDef> defs) {
    final widgets = <Widget>[];
    for (final d in defs) {
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 16));
      widgets.add(_fieldInput(d));
    }
    return widgets;
  }

  /// A quiet surface that groups one idea.
  Widget _sectionCard({
    required String label,
    required IconData icon,
    required List<Widget> children,
    Color? accent,
  }) {
    final color = accent ?? _accent;
    return PaperCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PaperLabel(label, color: color),
              const Spacer(),
              PaperIcon(icon, color: color, size: 34),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _addButton(VoidCallback onTap, String tooltip) {
    final p = context.pal;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface2,
        shape: CircleBorder(side: BorderSide(color: p.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(Icons.add_rounded, color: _accent),
          ),
        ),
      ),
    );
  }

  void _addTag() {
    final t =
        _tagInput.text.trim().replaceFirst(RegExp(r'^#'), '').toLowerCase();
    if (t.isEmpty || _tags.contains(t)) return;
    setState(() => _tags.add(t));
    _tagInput.clear();
    _touch();
  }

  void _addCustom() {
    final k = _customKey.text.trim();
    final v = _customValue.text.trim();
    if (k.isEmpty || v.isEmpty) return;
    setState(() => _custom[k] = v);
    _customKey.clear();
    _customValue.clear();
    _touch();
  }

  Widget _tagsEditor() {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags',
            style: TextStyle(
                color: p.muted, fontSize: 13, fontWeight: FontWeight.w700)),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _tags)
                TagChip(
                  t,
                  color: _accent,
                  onTap: () {
                    setState(() => _tags.remove(t));
                    _touch();
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        PaperField(
          controller: _tagInput,
          label: 'Add a tag',
          icon: Icons.label_outline_rounded,
          hint: 'work, finance, travel…',
          onSubmitted: (_) => _addTag(),
          suffix: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _addButton(_addTag, 'Add tag'),
          ),
        ),
      ],
    );
  }

  Widget _customEditor() {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Custom fields',
            style: TextStyle(
                color: p.muted, fontSize: 13, fontWeight: FontWeight.w700)),
        if (_custom.isNotEmpty) ...[
          const SizedBox(height: 12),
          PaperCard(
            inset: true,
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Column(
              children: [
                for (final k in _custom.keys.toList())
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k,
                                  style:
                                      TextStyle(fontSize: 12, color: p.muted)),
                              const SizedBox(height: 3),
                              Text(_custom[k] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: p.ink,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove $k',
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: p.muted),
                          onPressed: () {
                            setState(() => _custom.remove(k));
                            _touch();
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final keyField =
                PaperField(controller: _customKey, label: 'Field name');
            final valueField =
                PaperField(controller: _customValue, label: 'Value');
            final add = _addButton(_addCustom, 'Add field');
            if (constraints.maxWidth < 460) {
              return Column(
                children: [
                  keyField,
                  const SizedBox(height: 12),
                  valueField,
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: add),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: keyField),
                const SizedBox(width: 10),
                Expanded(child: valueField),
                const SizedBox(width: 10),
                add,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _photos() {
    final p = context.pal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var i = 0; i < _images.length; i++)
              Stack(
                fit: StackFit.expand,
                children: [
                  PaperCard(
                    radius: 18,
                    padding: EdgeInsets.zero,
                    onTap: () => Navigator.push(context,
                        smoothRoute(DocViewer(ids: _images, index: i))),
                    child: DocThumb(_images[i], radius: 18),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          final id = _images.removeAt(i);
                          if (_added.remove(id)) {
                            unawaited(DocStore.delete(id));
                          } else {
                            _removed.add(id);
                          }
                        });
                        _touch();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: p.ink.withValues(alpha: .78),
                          border:
                              Border.all(color: p.red.withValues(alpha: .45)),
                        ),
                        child: Icon(Icons.close_rounded,
                            size: 14, color: p.onPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            PaperCard(
              radius: 18,
              padding: EdgeInsets.zero,
              tone: p.surface2,
              onTap: _busy ? null : _pickImages,
              child: Center(
                child: _busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: p.primary))
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: p.primary),
                          const SizedBox(height: 5),
                          Text('Add',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: p.primary)),
                        ],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: p.muted),
            const SizedBox(width: 7),
            Text('Photos are encrypted on this device',
                style: TextStyle(fontSize: 12, color: p.muted)),
          ],
        ),
      ],
    );
  }

  Widget _heroCard() {
    final p = context.pal;
    return PaperCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TypeTile(_t, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PaperLabel('${_editing ? 'EDIT' : 'NEW'} ${_t.label}',
                        color: p.primary),
                    const SizedBox(height: 6),
                    Text(
                      _editing
                          ? 'Refine your ${_t.label.toLowerCase()}'
                          : 'Add to your vault',
                      style: TextStyle(
                        fontFamily: Paper.serif,
                        color: p.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_t == ItemType.card) ...[
            const SizedBox(height: 24),
            PaperLabel('Card preview', color: p.primary),
            const SizedBox(height: 12),
            CardVisual(entry: _preview(), reveal: true),
          ],
          const SizedBox(height: 24),
          _formField(
            controller: _name,
            label: 'Title',
            icon: _t.icon,
            hint: _t.nameHint,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              setState(() {});
              _touch();
            },
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
          ),
          const SizedBox(height: 12),
          Text(
            _t.blurb,
            style:
                TextStyle(color: p.muted.withValues(alpha: .85), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(List<FieldDef> details) {
    final children = <Widget>[..._fields(details)];
    if (_t.hasNotes) {
      children.addAll([
        const SizedBox(height: 22),
        const PaperDivider(),
        const SizedBox(height: 22),
        const PaperLabel('Notes'),
        const SizedBox(height: 14),
        _formField(
          controller: _notes,
          label: 'Notes (optional)',
          hint: 'Anything else worth keeping…',
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            setState(() {});
            _touch();
          },
        ),
      ]);
    }
    return _sectionCard(
      label: 'Details',
      icon: Icons.tune_rounded,
      children: children,
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final navigator = Navigator.of(context);
    final p = context.pal;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: p.line),
        ),
        title: Text('Discard changes?',
            style: TextStyle(
                color: p.ink,
                fontFamily: Paper.serif,
                fontWeight: FontWeight.w700)),
        content: Text("You haven't saved this yet.",
            style: TextStyle(color: p.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: p.muted),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: p.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true) {
      await _discard();
      _dirty = false;
      if (mounted) navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final secrets = _t.fields.where((f) => f.secret).toList();
    final details = _t.fields.where((f) => !f.secret).toList();

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmDiscard(context);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [p.bg, p.bg.withValues(alpha: 0)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: PaperButton(
                _editing ? 'Save changes' : 'Save to vault',
                icon: Icons.check_rounded,
                onPressed: _save,
              ),
            ),
          ),
        ),
        body: Form(
          key: _form,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              SafeArea(
                bottom: false,
                child: PageHeader(
                  '${_editing ? 'Edit' : 'New'} ${_t.label.toLowerCase()}',
                  subtitle: _t.blurb,
                  back: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heroCard(),
                      const SizedBox(height: 24),
                      _detailsCard(details),
                      if (secrets.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _sectionCard(
                          label:
                              _t == ItemType.card ? 'Card secrets' : 'Secrets',
                          icon: Icons.lock_outline_rounded,
                          children: _fields(secrets),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _sectionCard(
                        label: 'Organize',
                        icon: Icons.label_outline_rounded,
                        children: [
                          _tagsEditor(),
                          const SizedBox(height: 22),
                          const PaperDivider(),
                          const SizedBox(height: 22),
                          _customEditor(),
                        ],
                      ),
                      if (_t.supportsImages) ...[
                        const SizedBox(height: 24),
                        _sectionCard(
                          label: 'Photos',
                          icon: Icons.photo_library_outlined,
                          children: [_photos()],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
