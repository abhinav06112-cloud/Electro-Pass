import 'package:flutter/material.dart';

/// Global navigator key, used for navigation outside the widget tree.
final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

/// Global messenger key, used for snackbars outside the widget tree.
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();
