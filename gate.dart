import 'package:flutter/material.dart';

import 'docs.dart';
import 'pin_screen.dart';
import 'shell.dart';
import 'store.dart';

/// Legacy gate retained for compatibility. The app itself uses `AppLock`,
/// which keeps screens alive underneath the lock flow.
class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> with WidgetsBindingObserver {
  bool _locked = true;
  bool _wasAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.instance.lockHandler = _lockNow;
  }

  @override
  void dispose() {
    Store.instance.lockHandler = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _lockNow() {
    if (!Store.instance.hasPin || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    DocStore.clearCache();
    setState(() => _locked = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasAway = true;
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    Store.instance.refreshAutofillSystem();
    if (_wasAway) {
      _wasAway = false;
      _lockNow();
    }
  }

  void _unlock() => setState(() => _locked = false);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final Widget page;
        if (!store.hasPin) {
          page = PinScreen(
            key: const ValueKey('create'),
            mode: PinMode.create,
            onSuccess: _unlock,
          );
        } else if (_locked) {
          page = PinScreen(
            key: const ValueKey('unlock'),
            mode: PinMode.unlock,
            onSuccess: _unlock,
          );
        } else {
          page = const Shell(key: ValueKey('home'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: page,
        );
      },
    );
  }
}
