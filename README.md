# Tower Builder

A single-player construction simulation. A tower crane swings a prefabricated
module over a rising frame; you release it, a published per-storey chance decides
whether the storey holds, and every storey that holds compounds a structural
bonus you can bank by signing the build off.

The in-game economy runs on **BRIX**, virtual site credits. They cannot be bought,
sold or cashed out, and the build contains no purchases, no ads and no network
access at all.

## Layout

```
lib/
  app/          brand strings, palette, type scale, asset registry, routes
  build_site/   the simulation: metrics, risk tiers, crane rig, director, painter
  data/         local_vault.dart - the whole save as one versioned JSON document
  state/        architect (profile), contracts, check-in, rivals, audio desk
  ui/           screens, tabs and widgets
tool/           asset pipeline (see below) and build-time branding sources
```

State is exposed with `provider`; `Architect` is the single source of truth for
balance, rank, cosmetics and preferences, and it persists through `LocalVault`.

## Asset pipeline

Everything under `tool/` is build-time only and never bundled.

| Script | What it does |
| --- | --- |
| `python tool/gen_audio.py` | Synthesises every cue and both music beds from scratch (FM voices, Karplus–Strong, filtered noise) into `assets/audio/`. |
| `python tool/regrade_art.py` | Regrades the delivered sprites into this game's palette. Originals are stashed in `tool/_raw/` on first run, so the pass is reversible and idempotent. |
| `python tool/gen_branding.py` | Derives launcher and splash artwork into `tool/branding/`. |
| `tool/layout_assets.ps1` | One-shot: flattens a fresh art drop into the folder layout `pubspec.yaml` declares. |

The Python scripts need Pillow (`pip install pillow`).

After changing branding sources, regenerate the native assets:

```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Building

```
flutter pub get
flutter analyze
flutter test
flutter build appbundle --release
```

Release builds are signed with the upload key described in
`android/key.properties`, which is git-ignored along with the keystore itself.
To recreate the pair on a new machine:

```
keytool -genkeypair -v -keystore android/steelnest-upload.p12 -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 12000 -alias towerbuilder-upload
```

then write `storePassword`, `keyPassword`, `keyAlias` and
`storeFile=steelnest-upload.p12` into `android/key.properties`. If that file is
missing the release build falls back to the debug key, so `flutter build` still
works for local checks — never ship such an artefact.

Keep the keystore backed up somewhere safe: Play will not accept an upload signed
with a different key.

## Store submission

`docs/store_listing.md` holds the listing copy, the content-rating answers and the
data-safety declaration, all of which must stay consistent with what the app
actually does.
