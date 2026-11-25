import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'detail_screen.dart';
import 'models.dart';
import 'widgets.dart';

/// One row in a list of vault items (Home, Vault, Health...).
class ItemTile extends StatelessWidget {
  final Entry e;
  final bool showCopy;
  final VoidCallback? onTap;
  final Widget? trailing;
  const ItemTile(this.e,
      {super.key, this.showCopy = true, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final canCopy = showCopy && e.primaryValue.isNotEmpty;
    return PaperCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: onTap ??
          () => Navigator.push(context, smoothRoute(DetailScreen(id: e.id))),
      child: Row(
        children: [
          BrandBadge(e.name, type: e.type, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: Paper.serif,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: p.ink)),
                    ),
                    if (e.favorite)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.star_rounded,
                            size: 15, color: Paper.gold),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                          e.subtitle.isEmpty ? e.type.label : e.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: p.muted)),
                    ),
                    if (e.type == ItemType.login && e.password.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _strengthColor(e.strength)),
                      ),
                    ],
                    if (e.hasTotp) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.qr_code_rounded, size: 14, color: p.primary),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (canCopy)
            IconButton(
              tooltip: 'Copy',
              icon: Icon(Icons.copy_rounded, size: 19, color: p.muted),
              onPressed: () => copyText(context, e.primaryValue, e.type.label),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child:
                  Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
            ),
        ],
      ),
    );
  }

  Color _strengthColor(int strength) {
    if (strength >= 4) return Paper.green;
    if (strength >= 2) return Paper.gold;
    return Paper.red;
  }
}

/// Helper for a masked password string (used in a few places).
String dots(int n) => '•' * math.min(n, 12);
