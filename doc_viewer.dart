import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'docs.dart';
import 'widgets.dart';

/// Small square preview of an encrypted photo.
class DocThumb extends StatefulWidget {
  final String id;
  final double radius;

  const DocThumb(this.id, {super.key, this.radius = 18});

  @override
  State<DocThumb> createState() => _DocThumbState();
}

class _DocThumbState extends State<DocThumb> {
  late final Future<Uint8List?> _f = DocStore.load(widget.id);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FutureBuilder<Uint8List?>(
      future: _f,
      builder: (context, snap) {
        final b = snap.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.radius),
          child: Container(
            color: p.surface2,
            child: b != null
                ? Image.memory(b,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    gaplessPlayback: true)
                : Center(
                    child: snap.connectionState == ConnectionState.done
                        ? Icon(Icons.broken_image_outlined,
                            color: p.muted.withValues(alpha: .55))
                        : SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: p.primary)),
                  ),
          ),
        );
      },
    );
  }
}

/// Full-screen swipeable, zoomable photo viewer.
class DocViewer extends StatefulWidget {
  final List<String> ids;
  final int index;

  const DocViewer({super.key, required this.ids, this.index = 0});

  @override
  State<DocViewer> createState() => _DocViewerState();
}

class _DocViewerState extends State<DocViewer> {
  late final PageController _pc = PageController(initialPage: widget.index);
  late int _i = widget.index;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _close() {
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  Widget _chromeButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final p = context.pal;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.line)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: p.ink),
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.ids.length > 1)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var n = 0; n < widget.ids.length; n++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: n == _i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          n == _i ? p.primary : p.muted.withValues(alpha: .4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          if (widget.ids.length > 1) const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: p.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in_rounded, size: 15, color: p.primary),
                const SizedBox(width: 8),
                Text(
                  'Pinch to zoom · swipe to browse',
                  style: TextStyle(
                      color: p.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.bg,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(color: p.bg),
              ),
            ),
            PageView.builder(
              controller: _pc,
              itemCount: widget.ids.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => _ViewerPage(widget.ids[i]),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 20, 0),
                  child: PageHeader(
                    'Photo ${_i + 1} of ${widget.ids.length}',
                    trailing: _chromeButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: _close,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(child: _footer()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerPage extends StatefulWidget {
  final String id;

  const _ViewerPage(this.id);

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage> {
  late final Future<Uint8List?> _f = DocStore.load(widget.id);

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FutureBuilder<Uint8List?>(
      future: _f,
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return Center(
            child: snap.connectionState == ConnectionState.done
                ? Icon(Icons.broken_image_outlined, color: p.muted, size: 48)
                : CircularProgressIndicator(color: p.primary),
          );
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true),
          ),
        );
      },
    );
  }
}
