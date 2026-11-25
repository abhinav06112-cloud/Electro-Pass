import 'package:flutter/material.dart';

import 'add_edit_screen.dart';
import 'auth_screen.dart';
import 'docs.dart';
import 'keys.dart';
import 'models.dart';
import 'onboarding_screen.dart';
import 'pin_screen.dart';
import 'store.dart';
import 'widgets.dart';

/// Keeps the current page tree alive and places the lock flow above it.
class AppLock extends StatefulWidget {
  final Widget child;
  const AppLock({super.key, required this.child});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  Route<void>? _lockRoute;
  DateTime? _awaySince;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Store.instance.lockHandler = _showLock;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showLock());
  }

  @override
  void dispose() {
    Store.instance.lockHandler = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _showLock() {
    final navigator = navKey.currentState;
    if (navigator == null || _lockRoute != null) return;

    FocusManager.instance.primaryFocus?.unfocus();
    DocStore.clearCache();
    Store.instance.lock();

    final route = PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) =>
          PopScope(canPop: false, child: _LockFlow(onDone: _unlock)),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

    _lockRoute = route;
    navigator.push(route);
  }

  void _unlock() {
    final route = _lockRoute;
    final navigator = navKey.currentState;
    _lockRoute = null;
    if (route != null && navigator != null) {
      if (route.isCurrent) {
        navigator.pop();
      } else {
        navigator.removeRoute(route);
      }
    }
    _afterUnlock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _awaySince ??= DateTime.now();
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    Store.instance.refreshAutofillSystem();
    final awayFrom = _awaySince;
    _awaySince = null;
    if (awayFrom == null || _lockRoute != null) return;

    if (Store.instance.consumeExternal()) {
      _afterUnlock();
      return;
    }

    final awayFor = DateTime.now().difference(awayFrom);
    if (Store.instance.hasPin &&
        awayFor >= Duration(seconds: Store.instance.lockAfterSeconds)) {
      _showLock();
    } else {
      _afterUnlock();
    }
  }

  Future<void> _afterUnlock() async {
    final store = Store.instance;
    store.syncNow();

    final saved = await store.importPending();
    if (saved > 0 && messengerKey.currentState != null) {
      messengerKey.currentState!.showSnackBar(SnackBar(
        content: Text(saved == 1
            ? 'Saved a login from autofill'
            : 'Saved $saved logins from autofill'),
      ));
    }

    final draft = store.draft;
    if (draft == null || store.editorOpen || _lockRoute != null || _asking) {
      return;
    }

    final context = navKey.currentState?.overlay?.context;
    if (context == null || !context.mounted) return;

    final fresh = DateTime.now().millisecondsSinceEpoch - draft.ts <
        const Duration(days: 2).inMilliseconds;
    if (!fresh) {
      await store.discardDraft();
      return;
    }

    _asking = true;
    final resume = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Continue where you left off?'),
        content: Text(
          'You have an unsaved ${draft.itemType.label.toLowerCase()}'
          '${draft.name.trim().isEmpty ? '' : ' "${draft.name.trim()}"'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    _asking = false;

    if (resume == true) {
      navKey.currentState?.push(smoothRoute(AddEditScreen(draft: draft)));
    } else {
      await store.discardDraft();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Chooses the first page the user sees after launching the app.
class _LockFlow extends StatelessWidget {
  final VoidCallback onDone;
  const _LockFlow({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final store = Store.instance;
        final Widget page;
        if (!store.onboarded) {
          page = OnboardingScreen(
            key: const ValueKey('onboarding'),
            onDone: store.finishOnboarding,
          );
        } else if (store.needsAuth) {
          page = const AuthScreen(key: ValueKey('auth'));
        } else if (!store.hasPin) {
          page = PinScreen(
            key: const ValueKey('create-pin'),
            mode: PinMode.create,
            onSuccess: onDone,
          );
        } else {
          page = PinScreen(
            key: const ValueKey('unlock'),
            mode: PinMode.unlock,
            onSuccess: onDone,
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: page,
        );
      },
    );
  }
}
