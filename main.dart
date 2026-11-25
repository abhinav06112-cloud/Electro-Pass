import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_lock.dart';
import 'keys.dart';
import 'paper.dart';
import 'shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // In a release build an uncaught error used to leave a black screen with no
  // clue what happened. Keep every failure on screen and in the device log.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Electro Pass error: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Electro Pass uncaught error: $error\n$stack');
    return true;
  };
  ErrorWidget.builder =
      (details) => ErrorPaper(error: details.exception, stack: details.stack);

  String? initError;
  try {
    await Store.instance.init();
  } catch (error, stack) {
    initError = '$error\n$stack';
    debugPrint('Electro Pass startup failed: $initError');
  }

  runApp(ElectroPassApp(startupError: initError));
}

class ElectroPassApp extends StatelessWidget {
  final String? startupError;

  const ElectroPassApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    if (startupError != null) {
      return MaterialApp(
        title: 'Electro Pass',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(appPalettes.first),
        home: ErrorPaper(error: startupError!, title: 'Could not start'),
      );
    }

    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final palette = Store.instance.palette;
        return MaterialApp(
          title: 'Electro Pass',
          debugShowCheckedModeBanner: false,
          navigatorKey: navKey,
          scaffoldMessengerKey: messengerKey,
          theme: AppTheme.build(palette),
          darkTheme: AppTheme.build(palette),
          themeMode: ThemeMode.light,
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: palette.surface,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
              child: PaperBackdrop(child: AppLock(child: child!)),
            );
          },
          home: const Shell(),
        );
      },
    );
  }
}

/// A readable paper-coloured error page instead of Flutter's blank release
/// screen. Also used by [ErrorWidget.builder] for build-time failures.
class ErrorPaper extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  final String title;

  const ErrorPaper({
    super.key,
    required this.error,
    this.stack,
    this.title = 'Something went wrong',
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Paper.bg,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Paper.red,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: Paper.serif,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Paper.ink,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Electro Pass hit a problem while opening. '
                  'The details below are safe to share.',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.45, color: Paper.muted),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Paper.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Paper.line),
                  ),
                  child: SelectableText(
                    '$error${stack == null ? '' : '\n\n$stack'}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.5,
                      color: Paper.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can also send this from Settings → Send feedback.',
                  style: TextStyle(fontSize: 11.5, color: Paper.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
