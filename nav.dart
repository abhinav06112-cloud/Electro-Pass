import 'package:flutter/foundation.dart';

import 'models.dart';

/// Shared navigation state for the tab shell and vault filters.
class AppNav {
  AppNav._();

  static final ValueNotifier<int> tab = ValueNotifier<int>(0);
  static final ValueNotifier<ItemType?> filter = ValueNotifier<ItemType?>(null);
  static final ValueNotifier<String> query = ValueNotifier<String>('');
  static final ValueNotifier<String> tag = ValueNotifier<String>('');
  static final ValueNotifier<VaultSort> sort =
      ValueNotifier<VaultSort>(VaultSort.name);

  /// Open the vault, optionally narrowed to one entry type.
  static void openVault([ItemType? type]) {
    filter.value = type;
    tab.value = 1;
  }

  /// Jump to the vault with a search already filled in.
  static void search(String text, {ItemType? type, String? itemTag}) {
    query.value = text;
    filter.value = type;
    tag.value = itemTag ?? '';
    tab.value = 1;
  }
}

enum VaultSort { name, recent, strength }

extension VaultSortX on VaultSort {
  String get label => const [
        'Name',
        'Recently updated',
        'Weakest first',
      ][index];
}
