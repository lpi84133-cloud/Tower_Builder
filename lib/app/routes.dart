import 'package:flutter/material.dart';

import '../ui/screens/boot_screen.dart';
import '../ui/screens/home_shell.dart';
import '../ui/screens/legal_screen.dart';
import '../ui/screens/options_screen.dart';
import '../ui/screens/run_screen.dart';

/// Named routes, resolved through one generator so every push shares the same
/// transition: a short fade with a slight upward lift.
class Routes {
  const Routes._();

  static const boot = '/';
  static const home = '/yard';
  static const run = '/site';
  static const options = '/options';
  static const legal = '/legal';

  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _lift(const HomeShell(), settings);
      case run:
        return _lift(const RunScreen(), settings);
      case options:
        return _lift(const OptionsScreen(), settings);
      case legal:
        final doc = settings.arguments is LegalDoc
            ? settings.arguments as LegalDoc
            : LegalDoc.privacy;
        return _lift(LegalScreen(doc: doc), settings);
      case boot:
      default:
        return _lift(const BootScreen(), settings);
    }
  }

  static PageRoute<T> _lift<T>(Widget child, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, page) {
        final eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: eased,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.035), end: Offset.zero)
                .animate(eased),
            child: page,
          ),
        );
      },
    );
  }
}
