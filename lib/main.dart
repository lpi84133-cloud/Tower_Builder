import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app/brand.dart';
import 'app/palette.dart';
import 'app/routes.dart';
import 'app/type_scale.dart';
import 'data/local_vault.dart';
import 'hoist_veil/hoist_router.dart';
import 'scaffold_link/attrib_link.dart';
import 'scaffold_link/beacon_link.dart';
import 'scaffold_link/net_dial.dart';
import 'scaffold_link/nettap.dart';
import 'scaffold_link/secret_box.dart';
import 'scaffold_link/ua_pack.dart';
import 'state/architect.dart';
import 'state/audio_desk.dart';
import 'state/contract_board.dart';
import 'state/rival_firms.dart';
import 'state/site_check_in.dart';

// Bootstrap. Wires the site-portal stack (dial + attribution + beacon)
// alongside the yard's own long-lived objects, then hands both trees
// to a single MaterialApp — the router at `/` (HoistRouter) is the
// one screen every install sees on frame 1 and is what decides between
// the yard and the site-portal branches.
//
// Wiring order is load-bearing: WidgetsFlutterBinding → Firebase (best
// effort, never blocks) → orientations → UA prime → SecretBox warm →
// vault open → runApp. See `.cursor/rules/android_gray_guide.md` for
// the guarantee each step provides to the router.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Hue.abyss,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  await brixHttp.tighten();

  final SecretBox box = SecretBox();
  await box.warmUp();

  final NetTap tap = NetTap();
  final AttribLink attrib = AttribLink();
  final NetDial dial = NetDial(box);
  final BeaconLink beacon = BeaconLink(box);

  final vault = await LocalVault.open();
  final architect = Architect(vault);
  final desk = AudioDesk(architect);
  await desk.boot();

  runApp(TowerBuilderApp(
    vault: vault,
    architect: architect,
    desk: desk,
    portalBox: box,
    portalTap: tap,
    portalAttrib: attrib,
    portalDial: dial,
    portalBeacon: beacon,
  ));
}

/// Root widget. Owns yard-level providers AND the shell-level bridges.
/// Every screen below reaches yard state via `context.watch`/`context.read`,
/// while the shell bridges travel down through the router's constructor —
/// the two subsystems never talk directly, so a rewrite of either does
/// not touch the other.
class TowerBuilderApp extends StatelessWidget {
  const TowerBuilderApp({
    super.key,
    required this.vault,
    required this.architect,
    required this.desk,
    required this.portalBox,
    required this.portalTap,
    required this.portalAttrib,
    required this.portalDial,
    required this.portalBeacon,
  });

  final LocalVault vault;
  final Architect architect;
  final AudioDesk desk;

  final SecretBox portalBox;
  final NetTap portalTap;
  final AttribLink portalAttrib;
  final NetDial portalDial;
  final BeaconLink portalBeacon;

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
        home: HoistRouter(
          box: portalBox,
          tap: portalTap,
          attrib: portalAttrib,
          dial: portalDial,
          beacon: portalBeacon,
        ),
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
