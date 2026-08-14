# Play Console submission sheet

Everything here must stay truthful about the shipped build. If the app changes,
change this file in the same commit.

Package: `com.steelnest.towerbuilder` · Category: **Simulation** · Free, no IAP,
no ads · Target audience: **18+ only**

## Listing copy

**App name (30):** `Tower Builder: Site Manager`

**Short description (80):**
`Hoist prefab modules, stack storeys and sign the build off before it buckles.`

**Full description:**

```
You are the site manager. The crane is loaded, the frame is waiting, and the
weather window is closing.

Tower Builder is a construction simulation about knowing when to stop. Commit a
budget of BRIX, pick a risk plan, then release each module as the crane swings
over the frame. Every storey that seats raises your structural bonus. Every
storey is also a chance the frame does not take the load.

Sign the build off and the bonus is credited to your yard. Push one storey too
far and the frame buckles and the budget goes with it. That call is the game.

- Four risk plans, from Measured to Reckless, with the hold chance and bonus
  range printed on every one before you commit
- A career ladder of site ranks, from Apprentice upward
- Daily contracts and a site check-in that pay out in BRIX
- Unlockable module kits and city districts to redress the site
- A weekly board of rival firms to climb
- Plays completely offline

Important: Tower Builder is a simulation played for entertainment. BRIX are
virtual site credits with no monetary value. They cannot be bought, sold, cashed
out or exchanged for money, goods or prizes, no real-money play of any kind is
possible, and no real-world winnings are available. If your yard runs dry the
game restocks it for free, so you can always keep building. Intended for players
18 and over.
```

Words to keep out of the listing, the screenshots and the app itself: casino,
slots, bet, wager, jackpot, spin, cash out, win real, free coins. The in-game
vocabulary is deliberately budget / risk plan / storey / bonus / sign off.

## Content rating questionnaire (IARC)

| Question | Answer |
| --- | --- |
| Does the app simulate gambling (games of chance with no real-money stake)? | **Yes** — staking virtual BRIX on a per-storey chance |
| Can players gamble with real money, or win real money or prizes? | **No** |
| Are there purchases of any kind (including loot boxes)? | **No** |
| Violence, sexual content, drugs, alcohol, tobacco, crude humour, horror | **No** on all counts |
| User-generated content, chat, social features, location sharing | **No** |
| Does the app share the user's location or personal data? | **No** |

The simulated-gambling answer puts the rating at 18+ in several territories. That
is expected — do not soften it. Set the Play Console target-audience to 18+ and
leave the Families/Designed-for-Families programme opted out; the rating and the
target-audience setting are what keep the title away from minors, so the build
ships no in-app age prompt of its own. The app still states the age band and the
simulated nature of the economy on the boot screen, in Options and in the bundled
privacy, terms and responsible-play texts.

## Data safety declaration

- Data collected: **none**. Data shared: **none**.
- No account, no sign-in, no analytics, no advertising SDK, no crash reporting.
- All progress is written to the app's private storage. Android cloud backup and
  device-to-device transfer are both switched off
  (`allowBackup="false"`, `res/xml/data_extraction_rules.xml`), so no save data
  leaves the handset.
- The app declares **no permissions**, including no `INTERNET`.
- Data deletion: in-app, Options → "Erase progress". Uninstalling also removes
  everything.

## Privacy policy

Play requires a publicly reachable URL. Publish the exact wording of the in-app
privacy text (`lib/ui/screens/legal_screen.dart`, `_privacy`) on the studio site
and paste that URL into the Console. Keeping the two copies identical is the
point: a reviewer comparing them must find no gap.

## Ads and monetisation

Declare "no ads" and no in-app products. There is no ad SDK in the dependency
tree — the only plugins are `shared_preferences` and `audioplayers`.

## Release checklist

1. `flutter analyze` and `flutter test` clean.
2. `flutter build appbundle --release`, signed with the upload key from
   `android/key.properties`.
3. Install the release build and walk a full run, a sign-off, a collapse, a
   contract claim and "Erase progress".
4. Screenshots taken from this build only. Never reuse art, screenshots, icon,
   video or description text from another title in the catalogue: near-duplicate
   store assets are what "repetitive content" enforcement actually looks at.
5. Confirm the listing has no keyword from the excluded list above.
