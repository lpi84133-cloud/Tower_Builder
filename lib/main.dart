import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/brand.dart';
import 'app/palette.dart';
import 'app/routes.dart';
import 'app/type_scale.dart';
import 'data/local_vault.dart';
import 'state/architect.dart';
import 'state/audio_desk.dart';
import 'state/contract_board.dart';
import 'state/rival_firms.dart';
import 'state/site_check_in.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: the crane, the frame and the control deck are all laid out
  // for a tall viewport.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Hue.abyss,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final vault = await LocalVault.open();
  final architect = Architect(vault);
  final desk = AudioDesk(architect);
  await desk.boot();

  runApp(TowerBuilderApp(
    vault: vault,
    architect: architect,
    desk: desk,
  ));
}

/// Wires the long-lived objects into the tree once. Everything below reaches them
/// through `context.watch`/`context.read` instead of globals, so screens can be
/// built in isolation in tests.
class TowerBuilderApp extends StatelessWidget {
  const TowerBuilderApp({
    super.key,
    required this.vault,
    required this.architect,
    required this.desk,
  });

  final LocalVault vault;
  final Architect architect;
  final AudioDesk desk;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalVault>.value(value: vault),
        ChangeNotifierProvider<Architect>.value(value: architect),
        Provider<AudioDesk>.value(value: desk),
        ChangeNotifierProvider<ContractBoard>(
          create: (_) => ContractBoard(vault, architect),
        ),
        ChangeNotifierProvider<SiteCheckIn>(
          create: (_) => SiteCheckIn(vault, architect),
        ),
        ChangeNotifierProvider<RivalFirms>(
          create: (_) => RivalFirms(vault),
        ),
      ],
      child: MaterialApp(
        title: Brand.title,
        debugShowCheckedModeBanner: false,
        theme: _theme(),
        initialRoute: Routes.boot,
        onGenerateRoute: Routes.generate,
      ),
    );
  }

  ThemeData _theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Hue.navy,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Hue.cyan,
        brightness: Brightness.dark,
        surface: Hue.navy,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'SiteText'),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Hue.card,
        contentTextStyle: Type.body(size: 13, color: Hue.chalk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      splashFactory: NoSplash.splashFactory,
    );
  }
}
